Rails.application.routes.draw do
  # AllSpark monitoring routes
  if defined?(AllSpark) && AllSpark.configuration&.enabled?
    get '/allspark/assets/allspark-monitor.js', to: 'allspark#monitor_js'
    get '/allspark/api/ping', to: 'allspark#ping'
    post '/allspark/api/ping', to: 'allspark#ping'
    post '/allspark/api/devtools', to: 'allspark#devtools'
  end
  
  # Test route for DevTools error capture
  get '/test_errors', to: proc { |env| raise NameError, "Test error for DevTools" }
  
  # Test error route - AllSpark middleware will automatically report this
  get '/test_error', to: proc { |env| 
    raise StandardError, "Test error from target app - AllSpark middleware will report this automatically!"
  }
  
  # Additional test error route (both URLs supported)
  get '/error_test', to: proc { |env| 
    raise StandardError, "Test error from target app - AllSpark middleware will report this automatically!"
  }
  
  resources :mcp_configurations do
    member do
      patch :toggle
      post :test
    end
    collection do
      post :from_template
    end
  end
  # Admin routes - require admin authentication
  authenticate :user, ->(user) { user.system_admin? } do
    namespace :admin do
      resources :impersonation, only: [:index] do
        collection do
          post :start
          delete :stop
        end
      end
      
      # DEPRECATED: Old MCP Servers interface - use mcp_configurations instead
      resources :mcp_servers do
        member do
          post :test_connection
          post :discover_tools
          get :monitoring
          post :convert_to_configuration
        end
        
        collection do
          post :bulk_action
          get :analytics
        end
      end
      
      # New MCP Configurations interface
      resources :mcp_configurations do
        member do
          post :test_connection
          post :discover_tools
          get :discover_tools # Handle erroneous GET requests gracefully
          get :monitoring
        end
        
        collection do
          post :bulk_action
          get :analytics
        end
      end
      
      resources :mcp_templates do
        collection do
          post :import
          get :export
          post :refresh_from_constants
          post :preview
        end
      end
      
      
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  
  # Mount Action Cable
  mount ActionCable.server => '/cable'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#root"

  # Terminal functionality (for production terminal)
  get "terminal/simple", to: "terminal#simple"

  devise_for :users
  resources :users, only: [ :show, :edit, :update ] do
    collection do
      get :index
    end
    
    member do
      get :mcp_servers
      post :create_mcp_server
      patch 'update_mcp_server/:server_id', action: :update_mcp_server, as: :update_mcp_server
      delete 'destroy_mcp_server/:server_id', action: :destroy_mcp_server, as: :destroy_mcp_server
      post 'test_mcp_server_connection/:server_id', action: :test_mcp_server_connection, as: :test_mcp_server_connection
    end
  end

  # App Builder - AI-Powered Application Blueprint Generator
  authenticate :user do
    resources :app_projects do
      member do
        post :generate_prd
        post :generate_all
        post :generate_tasks
        post :generate_prompts
        post :generate_logo
        post :generate_marketing_page
        post :generate_claude_md
        post :replace_claude_md
        get :status
        post :regenerate
        get :context
        get "export/:format", to: "app_projects#export", as: :export
        post :serialize_output
        get :documentation_status
        get :view_documentation
        get "download_file/:file_type", to: "app_projects#download_file", as: :download_file
      end

      collection do
        get :wizard
        post :wizard, to: "app_projects#create_from_wizard"
        get "wizard/easy_mode", to: "app_projects#easy_mode", as: :wizard_easy_mode
        post "wizard/process_easy_mode", to: "app_projects#process_easy_mode", as: :wizard_process_easy_mode
        get :import, to: "app_projects#import_index", as: :import
        get "import/:project_folder_id/preview", to: "app_projects#import_preview", as: :import_preview
        post "import/:project_folder_id", to: "app_projects#import_execute", as: :import_execute
      end
    end

    resources :ai_generations, only: [ :show, :index ]
    
  end

  # Sidekiq web interface (require authentication)
  require "sidekiq/web"
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end

  resources :pages

  # Live features demo
  resources :live_demo, only: [ :index ] do
    collection do
      post :send_notification
      post :send_system_announcement
      post :broadcast_update
      post :start_progress_demo
    end
  end
  
  # Chat functionality
  authenticate :user do
    namespace :chat do
      resources :threads do
        member do
          post :add_participant
          delete :remove_participant
          post :mark_as_read
        end
        resources :messages, only: [:create, :update, :destroy]
        
        # Agent integration
        resource :agent, only: [] do
          post :enable
          post :disable
        end
      end
    end
    
    # Convenience route for chat
    get 'chat', to: 'chat/threads#index'
  end
  
  # AI Agents
  authenticate :user do
    namespace :agents do
      resources :assistants do
        member do
          post :test
        end
      end
      
      resources :teams do
        member do
          post :execute
        end
        
        resources :workflows do
          member do
            post :execute
            get :export
            post :duplicate
          end
          resources :executions, only: [:index, :show, :create], controller: 'workflow_executions' do
            member do
              post :cancel
            end
          end
        end
      end
      
      resources :team_executions, only: [:show]
      resources :runs, only: [:index, :show]
      
      resources :monitoring, only: [:index] do
        collection do
          get :errors
          get :health
          delete :clear_errors
        end
      end
      
      resources :knowledge_documents
      resources :knowledge_search, only: [:index]
    end
  end
  
    
    namespace :api do
      namespace :v1 do
        resources :mcp_configurations do
          member do
            post :test
          end
        end
      end
      
      
    end
  
  # External Integrations
  authenticate :user do
    resources :integrations
    
    namespace :integrations do
      resource :oauth, only: [] do
        get :authorize
        get :callback
        delete :disconnect
      end
    end
  end
  
  # MCP OAuth Integration
  authenticate :user do
    resources :mcp_oauth, only: [] do
      member do
        get :authorize
        get :callback
        delete :disconnect
      end
    end
  end

  # Development tools
  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook" if defined?(Lookbook)
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if defined?(LetterOpenerWeb)
  end
end
