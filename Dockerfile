# Dockerfile for Rails application
# Simple setup for development with Rails app and Sidekiq

# Use Ruby 3.2 as base image
FROM ruby:3.2-slim

# Add a label to track version
LABEL allspark.version="v1"

# Install system dependencies including development tools
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    libyaml-dev \
    git \
    curl \
    vim \
    tmux \
    procps \
    htop \
    tree \
    wget \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    # Chrome dependencies
    libgconf-2-4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libgdk-pixbuf2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    libnss3 \
    libxss1 \
    libasound2 \
    fonts-liberation \
    xdg-utils && \
    # Install Docker CLI
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update -qq && \
    apt-get install -y docker-ce-cli && \
    # Install Chromium
    apt-get install -y chromium chromium-driver && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 18 with Corepack for Yarn 4+ support
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    corepack enable

# Set working directory
WORKDIR /app

# Set Chrome/Chromium environment variables
ENV CHROME_BIN=/usr/bin/chromium
ENV CHROMIUM_BIN=/usr/bin/chromium
ENV DOCKER_CONTAINER=true

# Install Ruby dependencies
COPY Gemfile Gemfile.lock ./

# Pre-install gems during build to speed up container startup
# First, ensure we have the correct bundler version to match Gemfile.lock
RUN gem install bundler:2.6.3 && \
    bundle config set --local deployment 'true' && \
    bundle config set --local path '/usr/local/bundle' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3 && \
    bundle clean --force

# Create a marker file to indicate gems are pre-installed
RUN touch /usr/local/bundle/.preinstalled

# Install JavaScript dependencies  
COPY package.json yarn.lock* ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Precompile assets for production
RUN RAILS_ENV=production SECRET_KEY_BASE=precompile_dummy_key bundle exec rails assets:precompile

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port
EXPOSE 3000

# Use entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
CMD ["rails", "server"]