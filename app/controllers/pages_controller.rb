class PagesController < ApplicationController
  before_action :set_page, only: %i[edit update destroy]
  skip_before_action :authenticate_user!, only: [ :root, :show ]

  def root
    if user_signed_in?
      # Logged in users - redirect based on role
      if current_user.admin?
        redirect_to app_projects_path
      else
        redirect_to user_path(current_user)
      end
    else
      # Logged out users - show first app project's marketing page
      app_project = AppProject.first
      if app_project&.generated_marketing_page.present?
        redirect_to page_path(app_project.generated_marketing_page)
      else
        # Fallback to sign in if no marketing page exists
        redirect_to new_user_session_path
      end
    end
  end

  def index
    @pages = Page.all
    respond_with(@pages)
  end

  def show
    @page = Page.find(params[:id])
    respond_with(@page)
  rescue ActiveRecord::RecordNotFound
    # Check if this is an admin-only static page
    admin_only_pages = %w[welcome themes icons]
    if admin_only_pages.include?(params[:id]) && !current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
      return
    end

    render static_page
  end

  def new
    @page = Page.new
    respond_with(@page)
  end

  def edit; end

  def create
    @page = Page.new(page_params)
    @page.save
    respond_with(@page)
  end

  def update
    @page.update(page_params)
    respond_with(@page)
  end

  def destroy
    @page.destroy!
    respond_with(@page)
  end

  private

  def set_page
    @page = Page.find(params[:id])
  end

  def page_params
    params.require(:page).permit(:title, :content)
  end

  def static_page
    # only allow certain pages to be rendered
    %w[about themes welcome icons].include?(params[:id]) ? params[:id] : "welcome"
  end
end
