require 'io/console' # For password input

namespace :deploy do
  desc "Deploy AllSpark for single app development"
  
  # Helper methods
  def check_dependencies
    required_commands = ['docker', 'docker-compose']
    missing = required_commands.reject { |cmd| system("which #{cmd} > /dev/null 2>&1") }
    
    if missing.any?
      puts "❌ Missing required commands: #{missing.join(', ')}"
      puts "Please install these before proceeding."
      exit 1
    end
    
    puts "✅ All dependencies are installed"
  end
  
  def setup_env_file
    unless File.exist?('.env')
      if File.exist?('.env.example')
        FileUtils.cp('.env.example', '.env')
        puts "✅ Created .env file from .env.example"
        puts "⚠️  Please edit .env with your configuration"
      else
        puts "❌ No .env.example file found"
        exit 1
      end
    else
      puts "✅ .env file already exists"
    end
  end
  
  def generate_secret_key
    require 'securerandom'
    SecureRandom.hex(64)
  end
  
  # Local Development
  namespace :local do
    desc "Setup AllSpark for local development"
    task :setup do
      puts "\n🚀 Setting up AllSpark for Local Development\n"
      
      check_dependencies
      setup_env_file
      
      # Configure environment
      puts "\n📝 Configuring environment..."
      env_content = File.read('.env')
      env_content.gsub!(/SECRET_KEY_BASE=.*/, "SECRET_KEY_BASE=#{generate_secret_key}")
      File.write('.env', env_content)
      
      puts "\n🐳 Starting Docker services..."
      system("docker compose up -d")
      
      puts "\n⏳ Waiting for database to be ready..."
      sleep 10
      
      puts "\n🗄️  Setting up database..."
      system("docker compose exec web rails db:setup")
      system("docker compose exec web rails db:migrate")
      
      puts "\n✅ AllSpark is ready!"
      puts "🌐 Access at: http://localhost:3000"
      puts "\n📋 Useful commands:"
      puts "  - View logs: docker compose logs -f web"
      puts "  - Rails console: docker compose exec web rails console"
      puts "  - Stop services: docker compose down"
    end
    
    desc "Start local AllSpark services"
    task :start do
      puts "🚀 Starting AllSpark services..."
      system("docker compose up -d")
      puts "✅ Services started"
      puts "🌐 Access at: http://localhost:3000"
    end
    
    desc "Stop local AllSpark services"
    task :stop do
      puts "🛑 Stopping AllSpark services..."
      system("docker compose down")
      puts "✅ Services stopped"
    end
    
    desc "View logs for local deployment"
    task :logs do
      puts "📋 Showing logs (Ctrl+C to exit)..."
      system("docker compose logs -f")
    end
    
    desc "Reset local database"
    task :reset_db do
      puts "🗑️  Resetting database..."
      system("docker compose exec web rails db:drop db:create db:migrate db:seed")
      puts "✅ Database reset complete"
    end
  end
  
  # DigitalOcean Cloud Deployment
  namespace :cloud do
    desc "Deploy AllSpark to DigitalOcean"
    task :setup, [:domain] do |t, args|
      domain = args[:domain] || ENV['domain'] || ENV['DOMAIN']
      
      unless domain
        puts "❌ Please provide domain:"
        puts "   rake deploy:cloud:setup domain=example.com"
        puts "   OR: rake 'deploy:cloud:setup[example.com]'"
        exit 1
      end
      
      droplet_name = "allspark-#{domain.gsub('.', '-')}"
      
      # Check for DigitalOcean token
      unless ENV['DIGITALOCEAN_TOKEN']
        puts "❌ DIGITALOCEAN_TOKEN environment variable not set"
        puts "   Please run: export DIGITALOCEAN_TOKEN=your-token-here"
        exit 1
      end
      
      # Check for doctl
      unless system("which doctl > /dev/null 2>&1")
        puts "❌ doctl (DigitalOcean CLI) not found"
        puts "   Install with: brew install doctl (macOS) or snap install doctl (Linux)"
        puts "   Then authenticate: doctl auth init"
        exit 1
      end
      
      puts "\n☁️  Creating AllSpark on DigitalOcean\n"
      puts "🌐 Domain: #{domain}"
      puts "🖥️  Droplet: #{droplet_name}\n"
      
      # Create SSH key if needed
      ssh_key_name = "allspark-deploy-key"
      ssh_key_path = File.expand_path("~/.ssh/#{ssh_key_name}")
      
      unless File.exist?(ssh_key_path)
        puts "🔑 Generating SSH key..."
        system("ssh-keygen -t ed25519 -f #{ssh_key_path} -N '' -C 'allspark-deploy@#{domain}'")
      end
      
      # Add SSH key to DigitalOcean
      puts "🔑 Adding SSH key to DigitalOcean..."
      ssh_key_id = nil
      
      # Check if key already exists
      existing_keys = `doctl compute ssh-key list --format ID,Name --no-header`.lines
      existing_keys.each do |line|
        id, name = line.strip.split(/\s+/, 2)
        if name == ssh_key_name
          ssh_key_id = id
          puts "   Using existing SSH key: #{ssh_key_id}"
          break
        end
      end
      
      # Add key if not exists
      if ssh_key_id.nil?
        public_key = File.read("#{ssh_key_path}.pub").strip
        result = `doctl compute ssh-key create #{ssh_key_name} --public-key "#{public_key}" --format ID --no-header`.strip
        ssh_key_id = result
        puts "   Created new SSH key: #{ssh_key_id}"
      end
      
      # Create droplet
      puts "\n🚀 Creating DigitalOcean droplet..."
      create_cmd = <<~CMD
        doctl compute droplet create #{droplet_name} \
          --image ubuntu-22-04-x64 \
          --size s-2vcpu-4gb \
          --region nyc3 \
          --ssh-keys #{ssh_key_id} \
          --tag-names allspark,production \
          --wait \
          --format ID,PublicIPv4,Status \
          --no-header
      CMD
      
      result = `#{create_cmd}`.strip
      if $?.success? && result.match(/(\d+)\s+([\d\.]+)\s+(\w+)/)
        droplet_id = $1
        server_ip = $2
        status = $3
        
        puts "✅ Droplet created!"
        puts "   ID: #{droplet_id}"
        puts "   IP: #{server_ip}"
        puts "   Status: #{status}"
      else
        puts "❌ Failed to create droplet"
        puts "   Error: #{result}"
        exit 1
      end
      
      # Wait for SSH to be ready
      puts "\n⏳ Waiting for SSH to be ready..."
      max_attempts = 30
      attempt = 0
      while attempt < max_attempts
        if system("ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i #{ssh_key_path} root@#{server_ip} 'echo SSH ready' > /dev/null 2>&1")
          puts "✅ SSH connection established"
          break
        end
        attempt += 1
        print "."
        sleep 5
      end
      
      if attempt >= max_attempts
        puts "\n❌ Timeout waiting for SSH"
        exit 1
      end
      
      # Deploy application
      puts "\n🚀 Deploying AllSpark to server..."
      
      # Create deployment package
      temp_dir = "/tmp/allspark-deploy-#{Time.now.to_i}"
      FileUtils.mkdir_p(temp_dir)
      
      # Copy essential files
      essential_files = [
        'Gemfile', 'Gemfile.lock', 'Rakefile', 'config.ru',
        'package.json', 'yarn.lock', '.ruby-version',
        'app', 'bin', 'config', 'db', 'lib', 'public', 
        'vendor', 'storage', '.env.example'
      ]
      
      puts "📦 Preparing deployment package..."
      essential_files.each do |file|
        if File.exist?(file)
          if File.directory?(file)
            system("cp -r #{file} #{temp_dir}/")
          else
            system("cp #{file} #{temp_dir}/")
          end
        end
      end
      
      # Create production Dockerfile
      dockerfile_content = <<~DOCKERFILE
        FROM ruby:3.2-slim
        
        RUN apt-get update -qq && apt-get install -y \\
          build-essential \\
          libpq-dev \\
          nodejs \\
          npm \\
          git \\
          curl \\
          && npm install -g yarn
        
        WORKDIR /app
        
        COPY Gemfile Gemfile.lock ./
        RUN bundle install
        
        COPY package.json yarn.lock ./
        RUN yarn install
        
        COPY . .
        
        RUN bundle exec rails assets:precompile
        
        EXPOSE 3000
        
        CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
      DOCKERFILE
      
      File.write("#{temp_dir}/Dockerfile", dockerfile_content)
      
      # Create simple production docker-compose.yml
      compose_content = <<~YAML
        services:
          web:
            build: .
            environment:
              - RAILS_ENV=production
              - RAILS_SERVE_STATIC_FILES=true
              - RAILS_LOG_TO_STDOUT=true
            env_file:
              - .env
            ports:
              - "3000:3000"
            depends_on:
              - db
              - redis
            volumes:
              - ./storage:/app/storage
              - ./log:/app/log
          
          sidekiq:
            build: .
            command: bundle exec sidekiq
            environment:
              - RAILS_ENV=production
            env_file:
              - .env
            depends_on:
              - db
              - redis
          
          db:
            image: pgvector/pgvector:pg15
            environment:
              - POSTGRES_PASSWORD=postgres
              - POSTGRES_DB=allspark_production
            volumes:
              - postgres_data:/var/lib/postgresql/data
          
          redis:
            image: redis:7
            volumes:
              - redis_data:/data
        
        volumes:
          postgres_data:
          redis_data:
      YAML
      
      File.write("#{temp_dir}/docker-compose.yml", compose_content)
      
      # Create tar archive
      tar_file = "/tmp/allspark-deploy-#{Time.now.to_i}.tar.gz"
      system("cd #{temp_dir} && tar czf #{tar_file} .")
      
      # Install Docker and deploy
      ssh_cmd = "ssh -o StrictHostKeyChecking=no -i #{ssh_key_path} root@#{server_ip}"
      
      setup_script = <<~SCRIPT
        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        apt-get install -y docker-compose-plugin
        
        # Setup firewall
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw --force enable
        
        # Create app directory
        mkdir -p /opt/allspark
      SCRIPT
      
      puts "🔧 Installing Docker and setting up server..."
      system("#{ssh_cmd} 'bash -s' <<< '#{setup_script}'")
      
      # Transfer and deploy application
      puts "📤 Transferring application..."
      if system("scp -o StrictHostKeyChecking=no -i #{ssh_key_path} #{tar_file} root@#{server_ip}:/tmp/")
        deploy_script = <<~SCRIPT
          cd /opt/allspark
          tar xzf /tmp/$(basename #{tar_file})
          rm /tmp/$(basename #{tar_file})
          
          # Setup environment
          if [ ! -f .env ]; then
            cp .env.example .env
            
            # Generate secrets
            SECRET_KEY_BASE=$(openssl rand -hex 64)
            DB_PASSWORD=$(openssl rand -hex 32)
            
            # Update .env file
            sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$SECRET_KEY_BASE/" .env
            sed -i "s/RAILS_ENV=.*/RAILS_ENV=production/" .env
            sed -i "s/RAILS_HOSTS=.*/RAILS_HOSTS=#{domain}/" .env
            sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:$DB_PASSWORD@db:5432/allspark_production|" .env
            sed -i "s|REDIS_URL=.*|REDIS_URL=redis://redis:6379/0|" .env
            
            # Update docker-compose with password
            sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASSWORD/" docker-compose.yml
          fi
          
          # Build and start
          docker compose build
          docker compose up -d
          
          # Wait for database
          sleep 15
          
          # Setup database
          docker compose exec -T web rails db:create
          docker compose exec -T web rails db:migrate
          docker compose exec -T web rails db:seed
          
          docker compose ps
        SCRIPT
        
        puts "🚀 Deploying application..."
        system("#{ssh_cmd} 'bash -s' <<< '#{deploy_script}'")
        
        # Save connection info
        connection_info = {
          domain: domain,
          droplet_name: droplet_name,
          droplet_id: droplet_id,
          server_ip: server_ip,
          ssh_key_path: ssh_key_path,
          created_at: Time.now
        }
        
        FileUtils.mkdir_p('deployments')
        File.write("deployments/#{domain}.json", JSON.pretty_generate(connection_info))
        
        puts "\n✅ AllSpark deployed successfully!"
        puts "\n📋 Deployment Summary:"
        puts "   🌐 Domain: #{domain}"
        puts "   🖥️  Server IP: #{server_ip}"
        puts "   🔑 SSH Key: #{ssh_key_path}"
        puts "   📁 Config saved: deployments/#{domain}.json"
        puts "\n⚠️  Next steps:"
        puts "   1. Point #{domain} DNS A record to #{server_ip}"
        puts "   2. Access your app at http://#{server_ip}:3000"
        puts "   3. Once DNS propagates, access at http://#{domain}:3000"
        puts "\n📝 Useful commands:"
        puts "   SSH to server: ssh -i #{ssh_key_path} root@#{server_ip}"
        puts "   View logs: ssh -i #{ssh_key_path} root@#{server_ip} 'cd /opt/allspark && docker compose logs -f'"
        
        # Cleanup
        FileUtils.rm_rf(temp_dir)
        File.delete(tar_file) if File.exist?(tar_file)
      else
        puts "❌ Failed to transfer files"
        FileUtils.rm_rf(temp_dir)
        File.delete(tar_file) if File.exist?(tar_file)
        exit 1
      end
    end
    
    desc "SSH into cloud instance"
    task :ssh, [:domain] do |t, args|
      domain = args[:domain] || ENV['domain'] || ENV['DOMAIN']
      
      unless domain
        puts "❌ Please provide domain:"
        puts "   rake deploy:cloud:ssh domain=example.com"
        exit 1
      end
      
      config_file = "deployments/#{domain}.json"
      unless File.exist?(config_file)
        puts "❌ No deployment found for #{domain}"
        exit 1
      end
      
      config = JSON.parse(File.read(config_file))
      puts "🔐 Connecting to #{domain} (#{config['server_ip']})..."
      
      exec "ssh -i #{config['ssh_key_path']} root@#{config['server_ip']}"
    end
    
    desc "Show logs from cloud instance"
    task :logs, [:domain] do |t, args|
      domain = args[:domain] || ENV['domain'] || ENV['DOMAIN']
      
      unless domain
        puts "❌ Please provide domain:"
        puts "   rake deploy:cloud:logs domain=example.com"
        exit 1
      end
      
      config_file = "deployments/#{domain}.json"
      unless File.exist?(config_file)
        puts "❌ No deployment found for #{domain}"
        exit 1
      end
      
      config = JSON.parse(File.read(config_file))
      
      puts "📋 Showing logs from #{domain} (Ctrl+C to exit)..."
      
      exec "ssh -i #{config['ssh_key_path']} root@#{config['server_ip']} 'cd /opt/allspark && docker compose logs -f'"
    end
  end
  
  # Kamal-powered deployment
  namespace :kamal do
    desc "Deploy to DigitalOcean using Kamal (recommended)"
    task :setup, [:domain] do |t, args|
      domain = args[:domain] || ENV['domain'] || ENV['DOMAIN']
      
      unless domain
        puts "❌ Please provide domain:"
        puts "   rake deploy:kamal:setup domain=example.com"
        puts "   OR: rake 'deploy:kamal:setup[example.com]'"
        exit 1
      end
      
      puts "\n🚀 AllSpark Kamal Deployment to DigitalOcean\n"
      puts "=" * 50
      puts "Domain: #{domain}"
      puts "This will:"
      puts "  1. Create a DigitalOcean droplet"
      puts "  2. Configure Kamal for zero-downtime deployments"
      puts "  3. Deploy your application with PostgreSQL and Redis"
      puts "  4. Set up SSL-ready configuration"
      puts "=" * 50
      puts ""
      
      # Check prerequisites
      check_kamal_prerequisites
      
      # Get Docker Hub username
      docker_username = ENV['DOCKER_USERNAME'] || ENV['DOCKERHUB_USERNAME']
      unless docker_username
        print "Enter your Docker Hub username: "
        docker_username = STDIN.gets.chomp
      end
      
      # Verify Docker Hub access
      unless ENV['KAMAL_REGISTRY_PASSWORD']
        puts "\n📝 Docker Hub Setup Required:"
        puts "1. Go to https://hub.docker.com/settings/security"
        puts "2. Create an access token"
        puts "3. Set it as KAMAL_REGISTRY_PASSWORD environment variable"
        puts ""
        print "Enter your Docker Hub access token: "
        docker_token = STDIN.noecho(&:gets).chomp
        puts ""
        ENV['KAMAL_REGISTRY_PASSWORD'] = docker_token
      end
      
      droplet_name = "allspark-#{domain.gsub('.', '-')}"
      
      # Check for DigitalOcean token
      unless ENV['DIGITALOCEAN_TOKEN']
        puts "❌ DIGITALOCEAN_TOKEN environment variable not set"
        puts "   Please run: export DIGITALOCEAN_TOKEN=your-token-here"
        puts "   Get token at: https://cloud.digitalocean.com/account/api/tokens"
        exit 1
      end
      
      # Create droplet using existing logic
      puts "\n🌊 Creating DigitalOcean droplet..."
      server_ip = create_digitalocean_droplet(droplet_name, domain)
      
      # Wait for SSH
      puts "\n⏳ Waiting for server to be ready..."
      wait_for_ssh(server_ip)
      
      # Generate secrets
      puts "\n🔐 Generating secrets..."
      secrets = generate_production_secrets
      
      # Configure Kamal
      puts "\n⚙️  Configuring Kamal..."
      configure_kamal_deployment(server_ip, domain, docker_username, secrets)
      
      # Create .kamal directory and secrets file
      setup_kamal_secrets(secrets, docker_username)
      
      # Run initial server setup if needed
      puts "\n🔧 Preparing server..."
      prepare_server_for_kamal(server_ip)
      
      # Deploy with Kamal
      puts "\n🚢 Deploying with Kamal..."
      puts "This may take 5-10 minutes on first deploy..."
      
      # Setup database and initial deployment
      unless system("kamal setup")
        puts "❌ Kamal setup failed"
        puts "   Check the output above for errors"
        exit 1
      end
      
      # Save deployment info
      save_kamal_deployment_info(domain, droplet_name, server_ip, docker_username)
      
      puts "\n✅ Deployment Complete!"
      puts "\n📋 Deployment Summary:"
      puts "   🌐 Domain: #{domain}"
      puts "   🖥️  Server: #{server_ip}"
      puts "   🐳 Docker Image: #{docker_username}/allspark"
      puts "   🔒 SSL: Ready (add certificate with Kamal proxy)"
      puts "\n⚡ Quick Commands:"
      puts "   Deploy updates: kamal deploy"
      puts "   View logs: kamal app logs"
      puts "   Rails console: kamal app exec -i 'bin/rails console'"
      puts "   Rollback: kamal rollback"
      puts "\n📝 Next Steps:"
      puts "   1. Point #{domain} DNS A record to #{server_ip}"
      puts "   2. Enable SSL: kamal proxy reboot --ssl"
      puts "   3. Access your app at http://#{server_ip}"
      puts "   4. Once DNS propagates: https://#{domain}"
    end
    
    desc "Deploy updates to existing Kamal setup"
    task :deploy do
      puts "🚀 Deploying updates with Kamal..."
      system("kamal deploy")
    end
    
    desc "Show Kamal deployment status"
    task :status do
      system("kamal app details")
    end
    
    desc "Access Rails console on Kamal deployment"
    task :console do
      system("kamal app exec -i --reuse 'bin/rails console'")
    end
    
    desc "Show logs from Kamal deployment"
    task :logs do
      system("kamal app logs -f")
    end
    
    desc "Rollback Kamal deployment"
    task :rollback do
      puts "🔄 Rolling back to previous version..."
      system("kamal rollback")
    end
    
    private
    
    def check_kamal_prerequisites
      missing = []
      
      # Check for kamal gem
      unless system("which kamal > /dev/null 2>&1")
        missing << "kamal (run: gem install kamal)"
      end
      
      # Check for doctl
      unless system("which doctl > /dev/null 2>&1")
        missing << "doctl (DigitalOcean CLI)"
      end
      
      # Check for Docker
      unless system("which docker > /dev/null 2>&1")
        missing << "docker"
      end
      
      if missing.any?
        puts "❌ Missing required tools:"
        missing.each { |tool| puts "   - #{tool}" }
        puts "\nInstallation:"
        puts "  macOS: brew install doctl"
        puts "  Linux: snap install doctl"
        puts "  Then: doctl auth init"
        exit 1
      end
      
      puts "✅ All prerequisites installed"
    end
    
    def create_digitalocean_droplet(droplet_name, domain)
      # Use existing SSH key logic from original task
      ssh_key_name = "allspark-deploy-key"
      ssh_key_path = File.expand_path("~/.ssh/#{ssh_key_name}")
      
      unless File.exist?(ssh_key_path)
        puts "🔑 Generating SSH key..."
        system("ssh-keygen -t ed25519 -f #{ssh_key_path} -N '' -C 'allspark-deploy@#{domain}'")
      end
      
      # Add SSH key to DigitalOcean
      puts "🔑 Adding SSH key to DigitalOcean..."
      ssh_key_id = add_ssh_key_to_digitalocean(ssh_key_name, ssh_key_path)
      
      # Create droplet with better specs for production
      puts "🖥️  Creating production-ready droplet..."
      create_cmd = <<~CMD
        doctl compute droplet create #{droplet_name} \
          --image ubuntu-22-04-x64 \
          --size s-2vcpu-4gb \
          --region nyc3 \
          --ssh-keys #{ssh_key_id} \
          --tag-names allspark,production,kamal \
          --wait \
          --format ID,PublicIPv4,Status \
          --no-header
      CMD
      
      result = `#{create_cmd}`.strip
      if $?.success? && result.match(/(\d+)\s+([\d\.]+)\s+(\w+)/)
        droplet_id = $1
        server_ip = $2
        status = $3
        
        puts "✅ Droplet created!"
        puts "   ID: #{droplet_id}"
        puts "   IP: #{server_ip}"
        puts "   Status: #{status}"
        
        return server_ip
      else
        puts "❌ Failed to create droplet"
        puts "   Error: #{result}"
        exit 1
      end
    end
    
    def add_ssh_key_to_digitalocean(key_name, key_path)
      # Check if key already exists
      existing_keys = `doctl compute ssh-key list --format ID,Name --no-header`.lines
      existing_keys.each do |line|
        id, name = line.strip.split(/\s+/, 2)
        if name == key_name
          return id
        end
      end
      
      # Add new key
      public_key = File.read("#{key_path}.pub").strip
      result = `doctl compute ssh-key create #{key_name} --public-key "#{public_key}" --format ID --no-header`.strip
      result
    end
    
    def wait_for_ssh(server_ip, key_path = nil)
      key_path ||= File.expand_path("~/.ssh/allspark-deploy-key")
      max_attempts = 30
      attempt = 0
      
      while attempt < max_attempts
        if system("ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i #{key_path} root@#{server_ip} 'echo SSH ready' > /dev/null 2>&1")
          puts "✅ SSH connection established"
          return true
        end
        attempt += 1
        print "."
        sleep 5
      end
      
      puts "\n❌ Timeout waiting for SSH"
      exit 1
    end
    
    def generate_production_secrets
      require 'securerandom'
      
      {
        rails_master_key: SecureRandom.hex(32),
        postgres_password: SecureRandom.alphanumeric(32),
        secret_key_base: SecureRandom.hex(64)
      }
    end
    
    def configure_kamal_deployment(server_ip, domain, docker_username, secrets)
      config = {
        'service' => 'allspark',
        'image' => "#{docker_username}/allspark",
        
        'servers' => {
          'web' => [server_ip]
        },
        
        'proxy' => {
          'ssl' => false,  # Start without SSL, enable after DNS
          'host' => domain,
          'app_port' => 3000
        },
        
        'registry' => {
          'username' => docker_username,
          'password' => ['KAMAL_REGISTRY_PASSWORD']
        },
        
        'builder' => {
          'arch' => 'amd64'  # Set architecture for consistent builds
        },
        
        'env' => {
          'secret' => [
            'RAILS_MASTER_KEY',
            'SECRET_KEY_BASE',
            'DATABASE_URL'
          ],
          'clear' => {
            'RAILS_ENV' => 'production',
            'RAILS_SERVE_STATIC_FILES' => 'true',
            'RAILS_LOG_TO_STDOUT' => 'true',
            'APP_HOST' => domain,
            'REDIS_URL' => "redis://#{server_ip}:6379/0"
          }
        },
        
        'volumes' => [
          "#{domain.gsub('.', '_')}_storage:/rails/storage",
          "#{domain.gsub('.', '_')}_uploads:/rails/public/uploads"
        ],
        
        'accessories' => {
          'db' => {
            'image' => 'pgvector/pgvector:pg16',
            'host' => server_ip,
            'port' => 5432,
            'env' => {
              'clear' => {
                'POSTGRES_USER' => 'allspark',
                'POSTGRES_DB' => 'allspark_production'
              },
              'secret' => ['POSTGRES_PASSWORD']
            },
            'volumes' => ["#{domain.gsub('.', '_')}_postgres:/var/lib/postgresql/data"]
          },
          'redis' => {
            'image' => 'redis:7-alpine',
            'host' => server_ip,
            'port' => 6379,
            'cmd' => 'redis-server --save 60 1 --loglevel warning',
            'volumes' => ["#{domain.gsub('.', '_')}_redis:/data"]
          }
        },
        
        'aliases' => {
          'console' => 'app exec -i --reuse "bin/rails console"',
          'shell' => 'app exec -i --reuse "bash"',
          'logs' => 'app logs -f',
          'dbc' => 'app exec -i --reuse "bin/rails dbconsole"',
          'migrate' => 'app exec "bin/rails db:migrate"',
          'seed' => 'app exec "bin/rails db:seed"'
        },
        
        # Healthcheck is configured via proxy in Kamal 2.0+
        # Remove deprecated healthcheck section
        
        'ssh' => {
          'user' => 'root'
        }
      }
      
      # Write config file
      require 'yaml'
      File.write('config/deploy.yml', config.to_yaml)
      puts "✅ Created config/deploy.yml"
    end
    
    def setup_kamal_secrets(secrets, docker_username)
      FileUtils.mkdir_p('.kamal')
      
      # Create secrets file
      secrets_content = <<~SECRETS
        KAMAL_REGISTRY_PASSWORD=#{ENV['KAMAL_REGISTRY_PASSWORD']}
        RAILS_MASTER_KEY=#{secrets[:rails_master_key]}
        SECRET_KEY_BASE=#{secrets[:secret_key_base]}
        DATABASE_URL=postgresql://allspark:#{secrets[:postgres_password]}@db:5432/allspark_production
        POSTGRES_PASSWORD=#{secrets[:postgres_password]}
      SECRETS
      
      File.write('.kamal/secrets', secrets_content)
      puts "✅ Created .kamal/secrets"
      
      # Ensure it's in gitignore
      gitignore = File.read('.gitignore') rescue ''
      unless gitignore.include?('.kamal/secrets')
        File.open('.gitignore', 'a') do |f|
          f.puts "\n# Kamal secrets"
          f.puts ".kamal/secrets"
        end
      end
      
      # Also save Rails master key
      File.write('config/master.key', secrets[:rails_master_key])
      puts "✅ Created config/master.key"
    end
    
    def prepare_server_for_kamal(server_ip)
      # Kamal will handle Docker installation, but we can do some prep
      ssh_key = File.expand_path("~/.ssh/allspark-deploy-key")
      
      prep_script = <<~'SCRIPT'
        #!/bin/bash
        set -e
        
        # Function to wait for apt locks
        wait_for_apt() {
          while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
            echo "Waiting for apt lock to be released..."
            sleep 2
          done
        }
        
        # Update system with retry logic
        wait_for_apt
        apt-get update -qq || { sleep 5; wait_for_apt; apt-get update -qq; }
        
        # Install basic tools with retry
        wait_for_apt
        DEBIAN_FRONTEND=noninteractive apt-get install -y curl git vim htop || {
          sleep 5
          wait_for_apt
          DEBIAN_FRONTEND=noninteractive apt-get install -y curl git vim htop
        }
        
        # Setup firewall
        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 3000/tcp
        yes | ufw enable
        
        # Set up swap (useful for smaller droplets)
        if [ ! -f /swapfile ]; then
          fallocate -l 2G /swapfile
          chmod 600 /swapfile
          mkswap /swapfile
          swapon /swapfile
          echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
        fi
        
        echo "Server preparation completed"
      SCRIPT
      
      # Write script to temp file to avoid shell escaping issues
      require 'tempfile'
      script_file = Tempfile.new(['server-prep', '.sh'])
      script_file.write(prep_script)
      script_file.close
      
      system("scp -o StrictHostKeyChecking=no -i #{ssh_key} #{script_file.path} root@#{server_ip}:/tmp/server-prep.sh")
      system("ssh -o StrictHostKeyChecking=no -i #{ssh_key} root@#{server_ip} 'bash /tmp/server-prep.sh'")
      
      script_file.unlink
    end
    
    def save_kamal_deployment_info(domain, droplet_name, server_ip, docker_username)
      deployment_info = {
        domain: domain,
        droplet_name: droplet_name,
        server_ip: server_ip,
        docker_image: "#{docker_username}/allspark",
        deployed_at: Time.now,
        deployment_type: 'kamal',
        ssh_key_path: File.expand_path("~/.ssh/allspark-deploy-key")
      }
      
      FileUtils.mkdir_p('deployments')
      File.write("deployments/#{domain}.json", JSON.pretty_generate(deployment_info))
      puts "✅ Saved deployment info to deployments/#{domain}.json"
    end
  end
  
  # Utility tasks
  desc "Check deployment health"
  task :health do
    puts "\n🏥 AllSpark Health Check\n"
    
    if system("docker compose ps > /dev/null 2>&1")
      puts "🐳 Local Docker deployment detected"
      system("docker compose ps")
    else
      puts "❌ No local AllSpark deployment found"
    end
    
    puts "\n📊 Resource usage:"
    system("docker system df")
  end
  
  desc "Show deployment information"
  task :info do
    puts "\n📋 AllSpark Information\n"
    
    if File.exist?('.env')
      env_vars = File.read('.env').lines.grep(/^[A-Z]/).map(&:strip)
      
      puts "🔧 Environment Configuration:"
      env_vars.each do |var|
        key, value = var.split('=', 2)
        if key&.include?('SECRET') || key&.include?('TOKEN') || key&.include?('PASSWORD')
          puts "  #{key}=***"
        else
          puts "  #{key}=#{value}"
        end
      end
    end
    
    puts "\n🐳 Docker Information:"
    system("docker version --format 'Docker {{.Server.Version}}'") if system("which docker > /dev/null")
    system("docker compose version") if system("which docker > /dev/null")
    
    puts "\n💾 Volume Information:"
    system("docker volume ls") if system("which docker > /dev/null")
  end
end

# Top-level convenience task
desc "Deploy AllSpark locally"
task :deploy do
  Rake::Task['deploy:local:setup'].invoke
end