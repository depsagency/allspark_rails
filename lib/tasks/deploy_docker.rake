namespace :deploy do
  namespace :docker do
    desc "Build and push Docker image to registry"
    task :build, [:version, :registry] do |t, args|
      version = args[:version] || "latest"
      registry = args[:registry] || "docker.io"
      image_name = "allspark/allspark"
      
      puts "\n🔨 Building Docker image...\n"
      puts "   Version: #{version}"
      puts "   Registry: #{registry}"
      
      # Build the image
      puts "\n📦 Building image..."
      build_cmd = <<~CMD
        docker build \
          --platform linux/amd64 \
          --build-arg RAILS_ENV=production \
          --tag #{image_name}:#{version} \
          --tag #{image_name}:latest \
          .
      CMD
      
      unless system(build_cmd)
        puts "❌ Build failed"
        exit 1
      end
      
      # Tag for registry if not Docker Hub
      if registry != "docker.io"
        system("docker tag #{image_name}:#{version} #{registry}/#{image_name}:#{version}")
        system("docker tag #{image_name}:latest #{registry}/#{image_name}:latest")
        full_image = "#{registry}/#{image_name}"
      else
        full_image = image_name
      end
      
      puts "\n📤 Pushing to registry..."
      if system("docker push #{full_image}:#{version}") && system("docker push #{full_image}:latest")
        puts "✅ Image pushed successfully!"
        puts "   Image: #{full_image}:#{version}"
      else
        puts "❌ Push failed. Make sure you're logged in:"
        puts "   docker login #{registry}"
        exit 1
      end
    end
    
    desc "Deploy using pre-built Docker image"
    task :deploy, [:domain, :image] do |t, args|
      unless args[:domain]
        puts "❌ Please provide domain: rake deploy:docker:deploy[example.com]"
        puts "   Optional: rake deploy:docker:deploy[example.com,myregistry.io/allspark:v1.0]"
        exit 1
      end
      
      domain = args[:domain]
      image = args[:image] || "allspark/allspark:latest"
      
      # Find deployment config
      config_file = "deployments/#{domain}.json"
      unless File.exist?(config_file)
        puts "❌ No deployment found for #{domain}"
        puts "   First run: rake deploy:cloud:setup[#{domain}]"
        exit 1
      end
      
      config = JSON.parse(File.read(config_file))
      server_ip = config['server_ip']
      ssh_key_path = config['ssh_key_path']
      
      puts "\n🚀 Deploying Docker image to #{domain}\n"
      puts "   Server: #{server_ip}"
      puts "   Image: #{image}"
      
      # Create optimized deployment script
      deploy_script = <<~SCRIPT
        #!/bin/bash
        set -e
        
        cd /opt/allspark
        
        echo "📥 Pulling latest image..."
        docker pull #{image}
        
        echo "🔧 Updating docker-compose.yml..."
        # Update the web service to use the pre-built image
        cat > docker-compose.override.yml << 'EOF'
        version: '3.8'
        services:
          web:
            image: #{image}
            build: .  # Ignored when image is specified
        EOF
        
        echo "📦 Updating services..."
        docker compose -f docker-compose.yml -f docker-compose.production.yml -f docker-compose.override.yml up -d
        
        echo "🗄️ Running migrations..."
        docker compose exec web rails db:migrate
        
        echo "✅ Deployment complete!"
      SCRIPT
      
      # Deploy
      ssh_cmd = "ssh -o StrictHostKeyChecking=no -i #{ssh_key_path} root@#{server_ip}"
      
      puts "\n🔄 Deploying..."
      if system("#{ssh_cmd} 'cat > /tmp/deploy.sh && chmod +x /tmp/deploy.sh && /tmp/deploy.sh' <<< '#{deploy_script}'")
        puts "\n✅ Deployed successfully!"
        puts "   Site: https://#{domain}"
      else
        puts "\n❌ Deployment failed"
        exit 1
      end
    end
    
    desc "Setup GitHub Actions for automated Docker builds"
    task :setup_ci do
      puts "\n🔧 Setting up GitHub Actions for Docker builds...\n"
      
      workflow = <<~YAML
        name: Build and Push Docker Image
        
        on:
          push:
            branches: [ main ]
            tags: [ 'v*' ]
          pull_request:
            branches: [ main ]
        
        env:
          REGISTRY: ghcr.io
          IMAGE_NAME: ${{ github.repository }}
        
        jobs:
          build:
            runs-on: ubuntu-latest
            permissions:
              contents: read
              packages: write
            
            steps:
            - name: Checkout repository
              uses: actions/checkout@v4
            
            - name: Set up Docker Buildx
              uses: docker/setup-buildx-action@v3
            
            - name: Log in to Container Registry
              if: github.event_name != 'pull_request'
              uses: docker/login-action@v3
              with:
                registry: ${{ env.REGISTRY }}
                username: ${{ github.actor }}
                password: ${{ secrets.GITHUB_TOKEN }}
            
            - name: Extract metadata
              id: meta
              uses: docker/metadata-action@v5
              with:
                images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
                tags: |
                  type=ref,event=branch
                  type=ref,event=pr
                  type=semver,pattern={{version}}
                  type=semver,pattern={{major}}.{{minor}}
                  type=raw,value=latest,enable={{is_default_branch}}
            
            - name: Build and push Docker image
              uses: docker/build-push-action@v5
              with:
                context: .
                platforms: linux/amd64,linux/arm64
                push: ${{ github.event_name != 'pull_request' }}
                tags: ${{ steps.meta.outputs.tags }}
                labels: ${{ steps.meta.outputs.labels }}
                cache-from: type=gha
                cache-to: type=gha,mode=max
                build-args: |
                  RAILS_ENV=production
      YAML
      
      FileUtils.mkdir_p('.github/workflows')
      File.write('.github/workflows/docker-build.yml', workflow)
      
      puts "✅ Created .github/workflows/docker-build.yml"
      puts "\n📝 Next steps:"
      puts "   1. Commit and push the workflow file"
      puts "   2. Images will be built automatically on push to main"
      
      # Get GitHub repo path
      origin_url = `git config --get remote.origin.url`.strip
      if origin_url.include?('github.com')
        # Extract repo path from URL
        repo_path = origin_url.split('github.com').last
        repo_path = repo_path.sub(':', '/').sub(/^\//, '').sub('.git', '')
        puts "   3. Access images at: ghcr.io/#{repo_path}"
      else
        puts "   3. Configure GitHub repository for image access"
      end
    end
    
    desc "Create optimized production Dockerfile"
    task :optimize_dockerfile do
      puts "\n🔧 Creating optimized production Dockerfile...\n"
      
      dockerfile = <<~DOCKERFILE
        # syntax=docker/dockerfile:1
        
        # Build stage
        FROM ruby:3.3.0-slim as builder
        
        # Install build dependencies
        RUN apt-get update -qq && apt-get install -y \
          build-essential \
          git \
          libpq-dev \
          nodejs \
          npm \
          curl \
          && rm -rf /var/lib/apt/lists/*
        
        # Install Yarn
        RUN npm install -g yarn
        
        WORKDIR /app
        
        # Copy dependency files
        COPY Gemfile Gemfile.lock ./
        COPY package.json yarn.lock ./
        
        # Install dependencies
        RUN bundle config set deployment 'true' && \
            bundle config set without 'development test' && \
            bundle install --jobs 4 --retry 3
        
        RUN yarn install --frozen-lockfile
        
        # Copy application code
        COPY . .
        
        # Precompile assets
        RUN SECRET_KEY_BASE=dummy RAILS_ENV=production bundle exec rails assets:precompile
        
        # Remove unnecessary files
        RUN rm -rf node_modules tmp/cache vendor/bundle/ruby/*/cache
        
        # Production stage
        FROM ruby:3.3.0-slim
        
        # Install runtime dependencies
        RUN apt-get update -qq && apt-get install -y \
          libpq-dev \
          curl \
          && rm -rf /var/lib/apt/lists/*
        
        # Create app user
        RUN groupadd -r app && useradd -r -g app app
        
        WORKDIR /app
        
        # Copy built application
        COPY --from=builder --chown=app:app /app /app
        COPY --from=builder --chown=app:app /usr/local/bundle /usr/local/bundle
        
        # Set production environment
        ENV RAILS_ENV=production
        ENV RAILS_SERVE_STATIC_FILES=true
        ENV RAILS_LOG_TO_STDOUT=true
        
        # Switch to app user
        USER app
        
        # Expose port
        EXPOSE 3000
        
        # Health check
        HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
          CMD curl -f http://localhost:3000/health || exit 1
        
        # Start server
        CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
      DOCKERFILE
      
      File.write('Dockerfile.production', dockerfile)
      puts "✅ Created Dockerfile.production"
      
      # Create .dockerignore
      dockerignore = <<~IGNORE
        .git
        .gitignore
        .github
        .env*
        .rspec
        .rubocop.yml
        
        # Ignore development files
        /log/*
        /tmp/*
        !/log/.keep
        !/tmp/.keep
        /storage/*
        !/storage/.keep
        
        # Ignore test files
        /test
        /spec
        /features
        
        # Ignore documentation
        *.md
        /docs
        
        # Ignore development dependencies
        /node_modules
        /vendor/bundle
        
        # Ignore IDE files
        .idea
        .vscode
        *.swp
        *.swo
        
        # Ignore OS files
        .DS_Store
        Thumbs.db
      IGNORE
      
      File.write('.dockerignore', dockerignore)
      puts "✅ Created .dockerignore"
      
      puts "\n📝 To build optimized image:"
      puts "   docker build -f Dockerfile.production -t allspark:production ."
    end
  end
  
  # Override the cloud setup to use Docker images
  namespace :cloud do
    desc "Deploy to cloud using pre-built Docker image"
    task :deploy_image, [:domain, :image] do |t, args|
      unless args[:domain]
        puts "❌ Please provide domain: rake deploy:cloud:deploy_image[example.com]"
        exit 1
      end
      
      # Check if deployment exists
      config_file = "deployments/#{args[:domain]}.json"
      
      if File.exist?(config_file)
        # Use existing deployment
        Rake::Task['deploy:docker:deploy'].invoke(args[:domain], args[:image])
      else
        # Create new deployment with Docker image
        puts "\n⚠️  No existing deployment found. Creating new cloud instance..."
        puts "   This will create a new DigitalOcean droplet."
        print "   Continue? (y/N): "
        
        if STDIN.gets.chomp.downcase == 'y'
          # First create the instance
          Rake::Task['deploy:cloud:setup'].invoke(args[:domain])
          
          # Then deploy the image
          puts "\n🔄 Now deploying Docker image..."
          Rake::Task['deploy:docker:deploy'].invoke(args[:domain], args[:image])
        else
          puts "❌ Deployment cancelled"
        end
      end
    end
  end
end

desc "Show Docker deployment options"
task 'deploy:docker' do
  puts <<~HELP
    
    🐳 Docker Deployment Options
    
    ## Building Images
    rake deploy:docker:build              # Build and push to Docker Hub
    rake deploy:docker:build[v1.0]        # Build with version tag
    rake deploy:docker:build[v1.0,ghcr.io] # Push to GitHub Container Registry
    
    ## Deploying Images
    rake deploy:docker:deploy[domain]     # Deploy latest image
    rake deploy:docker:deploy[domain,myimage:v1.0]  # Deploy specific image
    
    ## Setup
    rake deploy:docker:setup_ci           # Setup GitHub Actions
    rake deploy:docker:optimize_dockerfile # Create optimized Dockerfile
    
    ## Cloud Deployment with Images
    rake deploy:cloud:deploy_image[domain] # Deploy image to cloud
    rake deploy:cloud:deploy_image[domain,ghcr.io/user/allspark:latest]
    
  HELP
end