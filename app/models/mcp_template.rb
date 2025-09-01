class McpTemplate < ApplicationRecord
  # Pre-built templates for common MCP servers
  TEMPLATES = {
    linear: {
      name: "Linear",
      description: "Linear issue tracking and project management",
      config_template: {
        command: "npx",
        args: ["-y", "@lucitra/linear-mcp"],
        env: {
          LINEAR_API_KEY: "{{linear_api_key}}"
        }
      },
      required_fields: [:linear_api_key],
      category: "productivity",
      documentation_url: "https://github.com/ibraheem4/linear-mcp"
    },
    github: {
      name: "GitHub", 
      description: "GitHub repositories, issues, and pull requests",
      config_template: {
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-github"],
        env: {
          GITHUB_PERSONAL_ACCESS_TOKEN: "{{github_token}}"
        }
      },
      required_fields: [:github_token],
      category: "development",
      documentation_url: "https://github.com/modelcontextprotocol/servers/tree/main/src/github"
    },
    filesystem: {
      name: "File System",
      description: "Read and write files with allowed directory restrictions",
      config_template: {
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "{{allowed_directories}}"]
      },
      required_fields: [:allowed_directories],
      category: "development",
      documentation_url: "https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem"
    },
    google_drive: {
      name: "Google Drive",
      description: "Access and manage Google Drive files",
      config_template: {
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-gdrive"],
        env: {
          GOOGLE_DRIVE_CLIENT_ID: "{{client_id}}",
          GOOGLE_DRIVE_CLIENT_SECRET: "{{client_secret}}",
          GOOGLE_DRIVE_REDIRECT_URI: "{{redirect_uri}}"
        }
      },
      required_fields: [:client_id, :client_secret, :redirect_uri],
      category: "productivity",
      documentation_url: "https://github.com/modelcontextprotocol/servers/tree/main/src/gdrive"
    },
    postgres: {
      name: "PostgreSQL",
      description: "Connect to PostgreSQL databases",
      config_template: {
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-postgres", "{{connection_string}}"]
      },
      required_fields: [:connection_string],
      category: "development",
      documentation_url: "https://github.com/modelcontextprotocol/servers/tree/main/src/postgres"
    },
    http_server: {
      name: "HTTP Server (Custom)",
      description: "Connect to a custom HTTP-based MCP server",
      config_template: {
        endpoint: "{{server_url}}",
        headers: {
          "Authorization": "Bearer {{api_token}}"
        }
      },
      required_fields: [:server_url, :api_token],
      category: "custom",
      server_type: "http"
    },
    websocket_server: {
      name: "WebSocket Server (Custom)",
      description: "Connect to a custom WebSocket MCP server",
      config_template: {
        endpoint: "{{websocket_url}}",
        headers: {
          "Authorization": "Bearer {{api_token}}"
        }
      },
      required_fields: [:websocket_url, :api_token],
      category: "custom",
      server_type: "websocket"
    }
  }.freeze
  
  # Categories
  CATEGORIES = %w[productivity development communication custom].freeze
  
  # Validations
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :config_template, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  
  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :featured, -> { where(featured: true) }
  
  # Class methods
  def self.seed_templates!
    TEMPLATES.each do |key, template_data|
      find_or_create_by!(key: key.to_s) do |template|
        template.name = template_data[:name]
        template.description = template_data[:description]
        template.config_template = template_data[:config_template]
        template.required_fields = template_data[:required_fields]
        template.category = template_data[:category]
        template.documentation_url = template_data[:documentation_url]
        template.icon_url = template_data[:icon_url]
      end
    end
  end
  
  def self.find_template(key)
    find_by(key: key.to_s) || new_from_template(key)
  end
  
  def self.new_from_template(key)
    template_data = TEMPLATES[key.to_sym]
    return nil unless template_data
    
    new(
      key: key.to_s,
      name: template_data[:name],
      description: template_data[:description],
      config_template: template_data[:config_template],
      required_fields: template_data[:required_fields],
      category: template_data[:category],
      documentation_url: template_data[:documentation_url]
    )
  end
  
  # Instance methods
  def instantiate_configuration(params = {})
    config = config_template.deep_dup
    
    # Replace template variables with actual values
    replace_template_variables!(config, params)
    
    # Determine server type
    server_type = determine_server_type(config)
    
    McpConfiguration.new(
      name: params[:name] || name,
      server_config: config,
      server_type: server_type,
      metadata: {
        template_key: key,
        template_version: updated_at.to_i
      }
    )
  end
  
  def missing_fields(params = {})
    required_fields.select do |field|
      params[field].blank?
    end
  end
  
  def valid_params?(params = {})
    missing_fields(params).empty?
  end
  
  private
  
  def replace_template_variables!(config, params)
    # Recursively replace {{variable}} placeholders
    case config
    when Hash
      config.each do |key, value|
        config[key] = replace_template_variables!(value, params)
      end
    when Array
      config.map! { |item| replace_template_variables!(item, params) }
    when String
      config.gsub(/\{\{(\w+)\}\}/) do |match|
        param_key = $1.to_sym
        params[param_key] || match
      end
    else
      config
    end
  end
  
  def determine_server_type(config)
    # Check if template specifies server type
    return config_template[:server_type] if config_template[:server_type]
    
    # Determine based on config structure
    if config['command'].present?
      'stdio'
    elsif config['endpoint'].present?
      if config['endpoint'].include?('ws://') || config['endpoint'].include?('wss://')
        'websocket'
      else
        'http'
      end
    elsif config['url'].present?
      'sse'
    else
      'stdio' # Default
    end
  end
end