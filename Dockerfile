# syntax=docker/dockerfile:1.7
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t rails800 .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name rails800 rails800

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Set environment for the entire image
ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV} \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="true" \
    SECRET_KEY_BASE_DUMMY="1"

# Install base runtime packages with enhanced security
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        postgresql-client \
        dumb-init \
        libjemalloc2 \
        libvips \
        tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create rails user early for better caching
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Set work directory and correct ownership
WORKDIR /rails
RUN chown rails:rails /rails

# ===========================================
# Dependencies stage - for better layer caching
# ===========================================
FROM base AS dependencies

# Install build dependencies with cache mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        build-essential \
        libpq-dev \
        git \
        libyaml-dev \
        pkg-config && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install gems with enhanced caching
COPY --chown=rails:rails Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache,sharing=locked \
    bundle install --jobs=$(nproc) --retry=3 && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Precompile bootsnap for gems
RUN bundle exec bootsnap precompile --gemfile

# ===========================================
# Build stage - compile app assets and code
# ===========================================
FROM dependencies AS build

# Copy application code
COPY --chown=rails:rails . .

# Precompile application code with bootsnap
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets in parallel with optimizations
RUN SECRET_KEY_BASE_DUMMY=1 \
    RAILS_ENV=production \
    NODE_ENV=production \
    ./bin/rails assets:precompile

# Remove unnecessary files to reduce final image size
RUN rm -rf \
    node_modules \
    tmp/cache \
    .git \
    .github \
    test \
    spec \
    features \
    doc \
    docs \
    README* \
    CHANGELOG* \
    LICENSE* \
    .dockerignore \
    .gitignore \
    .rubocop.yml \
    .rspec \
    Dockerfile* \
    vendor/cache

# ===========================================
# Final runtime stage
# ===========================================
FROM base AS runtime

# Copy built artifacts from build stage
COPY --from=build --chown=rails:rails "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=rails:rails /rails /rails

# Set proper permissions for runtime directories
RUN mkdir -p tmp/cache tmp/pids log storage && \
    chown -R rails:rails db log storage tmp && \
    chmod -R 755 db log storage tmp

# Configure healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-80}/up || exit 1

# Switch to non-root user for security
USER rails:rails

# Configure signal handling with dumb-init
ENTRYPOINT ["dumb-init", "--"]

# Set default command with proper signal handling
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]

# Add metadata labels following OCI standards
LABEL org.opencontainers.image.title="Rails 8.0 PostgreSQL Application" \
      org.opencontainers.image.description="Modern Rails 8.0 application with PostgreSQL adapter" \
      org.opencontainers.image.vendor="Rails Community" \
      org.opencontainers.image.version="8.0.0" \
      org.opencontainers.image.source="https://github.com/rails/rails" \
      org.opencontainers.image.licenses="MIT"
