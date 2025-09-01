# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!, only: [ :index ]
  before_action :set_user, only: [ :show, :edit, :update, :mcp_servers, :create_mcp_server, :update_mcp_server, :destroy_mcp_server, :test_mcp_server_connection ]
  before_action :ensure_correct_user, only: [ :edit, :update, :mcp_servers, :create_mcp_server, :update_mcp_server, :destroy_mcp_server, :test_mcp_server_connection ]

  # GET /users
  def index
    @users = User.all

    # Apply filters
    @users = @users.where(role: params[:role]) if params[:role].present?
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?",
                           search_term, search_term, search_term)
    end

    # Sort
    case params[:sort]
    when "name"
      @users = @users.order(:first_name, :last_name)
    when "email"
      @users = @users.order(:email)
    when "created"
      @users = @users.order(created_at: :desc)
    else
      @users = @users.order(created_at: :desc)
    end

    # Paginate
    @users = @users.page(params[:page]).per(20)
  end

  # GET /users/:id
  def show
  end

  # GET /users/:id/edit
  def edit
  end

  # PATCH/PUT /users/:id
  def update
    if @user.update(user_params)
      redirect_to @user, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # GET /users/:id/mcp_servers
  def mcp_servers
    @mcp_servers = @user.mcp_servers.includes(:instance)
    @system_servers = McpServer.system_wide.active
    @health_stats = calculate_user_mcp_health_stats
  end
  
  # POST /users/:id/mcp_servers
  def create_mcp_server
    @mcp_server = @user.mcp_servers.build(user_mcp_server_params)
    @mcp_server.instance_id = nil # Personal servers are not instance-specific
    
    if @mcp_server.save
      # Test connection immediately after creation
      test_result = test_server_connection(@mcp_server)
      
      if test_result[:success]
        # Schedule tool discovery
        McpToolDiscoveryJob.perform_later(@mcp_server.id)
        redirect_to mcp_servers_user_path(@user), 
                   notice: 'Personal MCP server was successfully created and connection test passed.'
      else
        flash[:warning] = "MCP server was created but connection test failed: #{test_result[:error]}"
        redirect_to mcp_servers_user_path(@user)
      end
    else
      @mcp_servers = @user.mcp_servers.includes(:instance)
      @system_servers = McpServer.system_wide.active
      @health_stats = calculate_user_mcp_health_stats
      render :mcp_servers, status: :unprocessable_entity
    end
  end
  
  # PATCH /users/:id/mcp_servers/:server_id
  def update_mcp_server
    @mcp_server = @user.mcp_servers.find(params[:server_id])
    
    if @mcp_server.update(user_mcp_server_params)
      # Test connection after update
      test_result = test_server_connection(@mcp_server)
      
      if test_result[:success]
        # Re-discover tools if endpoint or auth changed
        if endpoint_or_auth_changed?(@mcp_server)
          McpToolDiscoveryJob.perform_later(@mcp_server.id, force: true)
        end
        redirect_to mcp_servers_user_path(@user), 
                   notice: 'Personal MCP server was successfully updated.'
      else
        flash[:warning] = "MCP server was updated but connection test failed: #{test_result[:error]}"
        redirect_to mcp_servers_user_path(@user)
      end
    else
      @mcp_servers = @user.mcp_servers.includes(:instance)
      @system_servers = McpServer.system_wide.active
      @health_stats = calculate_user_mcp_health_stats
      render :mcp_servers, status: :unprocessable_entity
    end
  end
  
  # DELETE /users/:id/mcp_servers/:server_id
  def destroy_mcp_server
    @mcp_server = @user.mcp_servers.find(params[:server_id])
    server_name = @mcp_server.name
    
    # Clean up connections
    McpConnectionManager.instance.release_connection(@mcp_server)
    
    # Clean up cached tools
    McpToolRegistry.instance.unregister_server_tools(@mcp_server.id)
    
    if @mcp_server.destroy
      redirect_to mcp_servers_user_path(@user), 
                 notice: "Personal MCP server '#{server_name}' was successfully deleted."
    else
      redirect_to mcp_servers_user_path(@user), 
                 alert: 'Failed to delete personal MCP server.'
    end
  end
  
  # POST /users/:id/mcp_servers/:server_id/test_connection
  def test_mcp_server_connection
    @mcp_server = @user.mcp_servers.find(params[:server_id])
    result = test_server_connection(@mcp_server)
    
    respond_to do |format|
      format.json { render json: result }
      format.html do
        if result[:success]
          redirect_to mcp_servers_user_path(@user), 
                     notice: 'Connection test successful!'
        else
          redirect_to mcp_servers_user_path(@user), 
                     alert: "Connection test failed: #{result[:error]}"
        end
      end
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "User not found. Please log in again."
  end

  def ensure_correct_user
    unless @user == current_user || current_user.admin?
      redirect_to root_path, alert: "You can only edit your own profile."
    end
  end

  def require_admin!
    unless current_user.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end

  def user_params
    permitted_params = [ :first_name, :last_name, :bio, :website, :avatar ]

    # Add all social platform handles
    User::SOCIAL_PLATFORMS.keys.each do |platform|
      permitted_params << "#{platform}_handle".to_sym
    end

    # Allow role editing only for admins
    permitted_params << :role if current_user.admin?

    params.require(:user).permit(permitted_params)
  end
  
  def user_mcp_server_params
    params.require(:mcp_server).permit(
      :name, :endpoint, :protocol_version, :auth_type, :status,
      config: {}, credentials: {}
    )
  end
  
  def test_server_connection(server)
    begin
      client = McpClient.new(server)
      client.test_connection
      { success: true }
    rescue => e
      Rails.logger.error "[User Settings] Connection test failed for server #{server.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  def endpoint_or_auth_changed?(server)
    server.previous_changes.keys.any? { |key| %w[endpoint auth_type credentials].include?(key) }
  end
  
  def calculate_user_mcp_health_stats
    user_servers = @user.mcp_servers
    total = user_servers.count
    active = user_servers.active.count
    inactive = user_servers.inactive.count
    error = user_servers.error.count
    
    {
      total: total,
      active: active,
      inactive: inactive,
      error: error,
      health_percentage: total > 0 ? (active.to_f / total * 100).round(1) : 100
    }
  end
end
