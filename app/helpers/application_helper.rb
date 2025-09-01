require "redcarpet"

# Custom Redcarpet renderer with better highlight styling
class CustomMarkdownRenderer < Redcarpet::Render::HTML
  def highlight(text)
    %(<mark class="bg-yellow-200 text-gray-900 dark:bg-yellow-800 dark:text-gray-100 px-1 rounded">#{text}</mark>)
  end
end

module ApplicationHelper
  def flash_class(type)
    case type.to_s
    when 'notice', 'success'
      'success'
    when 'alert', 'error'
      'error'
    when 'warning'
      'warning'
    else
      'info'
    end
  end

  def container_class
    if controller_name == "pages" && action_name == "welcome"
      "container-full"
    else
      "container"
    end
  end

  def avatar_url
    "https://i.pravatar.cc/500?img=#{(1..70).to_a.sample}"
  end

  def markdown_to_html(text)
    return "" if text.blank?

    renderer = CustomMarkdownRenderer.new(
      filter_html: false,
      no_links: false,
      no_images: false,
      with_toc_data: false,
      hard_wrap: true
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      underline: true,
      highlight: true,
      fenced_code_blocks: true,
      no_intra_emphasis: true,
      strikethrough: true,
      superscript: true
    )

    markdown.render(text).html_safe
  end

  # Alias for backwards compatibility
  alias_method :markdown, :markdown_to_html
  
  def process_marketing_page_content(page)
    return "" if page.nil? || page.content.blank?

    content = page.content
    app_project = page.app_project

    # First convert markdown to HTML
    html_content = markdown_to_html(content)

    if app_project
      # Replace logo placeholder in the HTML (handle various formats)
      if app_project.has_logo?
        logo_wrapper_start = %(<div class="flex justify-center mb-4">)
        logo_wrapper_end = %(</div>)

        if app_project.logo_data.present?
          logo_img = %(#{logo_wrapper_start}<img src="data:image/png;base64,#{app_project.logo_data}" alt="#{app_project.name} Logo" class="h-24 w-auto" />#{logo_wrapper_end})
        elsif app_project.generated_logo_url.present?
          logo_img = %(#{logo_wrapper_start}<img src="#{app_project.generated_logo_url}" alt="#{app_project.name} Logo" class="h-24 w-auto" />#{logo_wrapper_end})
        elsif app_project.logo_generation_metadata&.dig("original_url").present?
          # Logo data stored in metadata
          logo_data = app_project.logo_generation_metadata["original_url"]
          logo_img = %(#{logo_wrapper_start}<img src="data:image/png;base64,#{logo_data}" alt="#{app_project.name} Logo" class="h-24 w-auto" />#{logo_wrapper_end})
        else
          logo_img = %(#{logo_wrapper_start}<div class="font-bold text-2xl">#{app_project.name}</div>#{logo_wrapper_end})
        end
      else
        logo_img = %(<div class="flex justify-center mb-4"><div class="font-bold text-2xl">#{app_project.name}</div></div>)
      end

      # Replace various logo placeholder formats in HTML
      html_content = html_content.gsub(/<strong>LOGO_PLACEHOLDER_HERE<\/strong>/, logo_img)
      html_content = html_content.gsub(/LOGO_PLACEHOLDER_HERE/, logo_img)

      # Replace "Get Started" buttons with our styled buttons
      # For marketing pages, direct to sign in
      app_url = "/users/sign_in"
      button_html = %(<a href="#{app_url}" class="btn btn-primary btn-lg">Get Started</a>)

      # Replace any <a> tags containing "Get Started" with our button
      # This handles both inline styled links and plain links
      html_content = html_content.gsub(/<a[^>]*>Get Started<\/a>/, button_html)

      # Remove paragraph tags around buttons for better layout
      html_content = html_content.gsub(/<p>(<a[^>]*class="btn[^>]*>.*?<\/a>)<\/p>/, '<div class="my-4">\1</div>')
    end

    html_content
  end
  
  # Instance log helpers
  def log_alert_class(log)
    case log.log_type
    when 'error'
      'alert-error'
    when 'warning'
      'alert-warning'
    when 'creation', 'deployment'
      'alert-info'
    else
      ''
    end
  end
  
  def log_icon(log)
    case log.log_type
    when 'creation'
      '<i class="fas fa-plus"></i>'.html_safe
    when 'deployment'
      '<i class="fas fa-rocket"></i>'.html_safe
    when 'error'
      '<i class="fas fa-exclamation-triangle"></i>'.html_safe
    when 'health_check'
      '<i class="fas fa-heartbeat"></i>'.html_safe
    when 'restart'
      '<i class="fas fa-sync-alt"></i>'.html_safe
    when 'backup'
      '<i class="fas fa-save"></i>'.html_safe
    else
      '<i class="fas fa-info-circle"></i>'.html_safe
    end
  end
  
  # Deployment status helpers
  def deployment_status_alert_class(status)
    case status
    when 'deployed'
      'alert-success'
    when 'deploying'
      'alert-info'
    when 'failed'
      'alert-error'
    else
      'alert'
    end
  end
  
  def deployment_status_icon(status)
    case status
    when 'deployed'
      'fa-check-circle'
    when 'deploying'
      'fa-spinner fa-spin'
    when 'failed'
      'fa-times-circle'
    else
      'fa-info-circle'
    end
  end
  
  def deployment_status_badge_class(status)
    case status
    when 'success'
      'badge-success'
    when 'deploying'
      'badge-info'
    when 'failed'
      'badge-error'
    when 'pending'
      'badge-warning'
    else
      'badge-ghost'
    end
  end
  
  # Project status helpers
  def project_status_color(status)
    case status.to_s
    when 'completed'
      'success'
    when 'in_progress'
      'warning'
    when 'pending'
      'info'
    when 'cancelled'
      'error'
    else
      'ghost'
    end
  end
  
  def task_status_color(status)
    case status.to_s
    when 'completed'
      'success'
    when 'in_progress'
      'warning'
    when 'pending'
      'ghost'
    when 'blocked'
      'error'
    else
      'ghost'
    end
  end
  
  # Knowledge document helpers
  def visibility_badge_class(visibility)
    case visibility.to_s
    when 'public'
      'success'
    when 'team'
      'info'
    when 'private'
      'warning'
    when 'restricted'
      'error'
    else
      'ghost'
    end
  end
  
  def priority_badge_class(priority)
    case priority.to_s
    when 'critical'
      'error'
    when 'high'
      'warning'
    when 'normal'
      'info'
    when 'low'
      'ghost'
    else
      'ghost'
    end
  end
  
  # Generate Claude Code implementation prompt
  def claude_code_prompt(app_project)
    return nil unless app_project.generated_prd.present? && app_project.generated_tasks.present?
    
    project_dir = "docs/app-projects/generated/#{app_project.slug}"
    
    <<~PROMPT
      Implement the #{app_project.name} application by following the provided documentation:

      1. Product Requirements Document (PRD): #{project_dir}/prd.md
      2. Development Tasks: #{project_dir}/tasks.md

      Start with the first task and work through each task sequentially until the entire project is complete. Follow the technical specifications in the PRD and ensure each task is fully implemented before moving to the next.

      If you need any clarification on requirements or run into technical decisions not covered in the documentation, please ask. The goal is to deliver a fully functional application that meets all the requirements specified in the PRD.
    PROMPT
  end
end
