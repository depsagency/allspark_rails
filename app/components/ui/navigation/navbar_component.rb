# frozen_string_literal: true

# Navbar component with DaisyUI styling
#
# Provides responsive navigation with:
# - Brand/logo area
# - Navigation links
# - User menu dropdown
# - Mobile menu toggle
# - Theme switcher
# - Search functionality
#
# Example usage:
#   <%= render Ui::Navigation::NavbarComponent.new(
#         brand: "MyApp",
#         fixed: true,
#         theme_switcher: true
#       ) do |navbar| %>
#     <% navbar.with_nav_link("Dashboard", dashboard_path, active: current_page?(dashboard_path)) %>
#     <% navbar.with_nav_link("Users", users_path) %>
#     <% navbar.with_user_menu(current_user) do %>
#       <%= link_to "Profile", profile_path, class: "menu-item" %>
#       <%= link_to "Logout", logout_path, method: :delete, class: "menu-item" %>
#     <% end %>
#   <% end %>
#
class Ui::Navigation::NavbarComponent < BaseComponent
  option :brand, optional: true
  option :brand_url, default: -> { "/" }
  option :fixed, default: -> { false }
  option :shadow, default: -> { true }
  option :theme_switcher, default: -> { false }
  option :search, default: -> { false }
  option :search_url, optional: true
  option :search_placeholder, default: -> { "Search..." }
  option :css_class, optional: true

  renders_many :nav_links, lambda { |text, url, **options|
    NavLink.new(text: text, url: url, **options)
  }

  renders_one :user_menu, lambda { |user, **options, &block|
    UserMenu.new(user: user, **options, &block)
  }

  renders_one :brand_content, lambda { |&block|
    BrandContent.new(&block)
  }

  private

  def navbar_classes
    classes = [ "navbar" ]

    classes << "bg-base-100"
    classes << "shadow-lg" if shadow
    classes << "fixed top-0 z-50" if fixed
    classes << css_class if css_class.present?

    classes.join(" ")
  end

  def container_classes
    classes = [ "flex-1" ]
    classes << "max-w-7xl mx-auto px-4"
    classes.join(" ")
  end

  def has_brand?
    brand.present? || brand_content?
  end

  def has_nav_links?
    nav_links.any?
  end

  def has_search?
    search
  end

  def mobile_menu_id
    @mobile_menu_id ||= "mobile-menu-#{SecureRandom.hex(4)}"
  end

  # Inner component classes
  class NavLink < ViewComponent::Base
    def initialize(text:, url:, active: false, icon: nil, badge: nil, **options)
      @text = text
      @url = url
      @active = active
      @icon = icon
      @badge = badge
      @options = options
    end

    private

    attr_reader :text, :url, :active, :icon, :badge, :options

    def link_classes
      classes = [ "btn", "btn-ghost", "normal-case" ]
      classes << "btn-active" if active
      classes.join(" ")
    end

    def has_icon?
      icon.present?
    end

    def has_badge?
      badge.present?
    end

    def badge_classes
      "badge badge-sm badge-primary"
    end
  end

  class UserMenu < ViewComponent::Base
    def initialize(user:, avatar_url: nil, show_name: true, &block)
      @user = user
      @avatar_url = avatar_url
      @show_name = show_name
      @content_block = block
    end

    private

    attr_reader :user, :avatar_url, :show_name, :content_block

    def dropdown_id
      @dropdown_id ||= "user-menu-#{SecureRandom.hex(4)}"
    end

    def user_avatar
      if avatar_url.present?
        avatar_url
      elsif user.respond_to?(:avatar) && user.avatar.present?
        user.avatar
      else
        user_initials
      end
    end

    def user_initials
      if user.respond_to?(:first_name) && user.respond_to?(:last_name)
        "#{user.first_name&.first}#{user.last_name&.first}".upcase
      elsif user.respond_to?(:name)
        user.name.split.map(&:first).join.upcase
      elsif user.respond_to?(:email)
        user.email.first(2).upcase
      else
        "U"
      end
    end

    def user_display_name
      if user.respond_to?(:full_name)
        user.full_name
      elsif user.respond_to?(:first_name) && user.respond_to?(:last_name)
        "#{user.first_name} #{user.last_name}".strip
      elsif user.respond_to?(:name)
        user.name
      elsif user.respond_to?(:email)
        user.email
      else
        "User"
      end
    end

    def has_avatar_image?
      avatar_url.present? || (user.respond_to?(:avatar) && user.avatar.present?)
    end
  end

  class BrandContent < ViewComponent::Base
    def initialize(&block)
      @content_block = block
    end

    def call
      @content_block.call if @content_block
    end
  end
end
