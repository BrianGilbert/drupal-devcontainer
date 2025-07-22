# .devcontainer/Dockerfile - Fixed version with proper extension handling
FROM mcr.microsoft.com/devcontainers/php:1-8.3-apache-bookworm

# Install system dependencies for PHP extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Dependencies for GD extension
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    # Dependencies for other extensions
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    # Development tools
    git \
    mariadb-client \
    sqlite3 \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Check what extensions are already available
RUN echo "🔍 Base image extensions:" && php -m | sort

# Configure GD extension with all features before installing
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-xpm

# Install only the extensions that aren't already present
# Check each extension and install if missing
RUN EXTENSIONS_TO_INSTALL=""; \
    for ext in gd intl pdo_mysql zip; do \
        if ! php -m | grep -i "^$ext$" > /dev/null; then \
            echo "Adding $ext to installation list"; \
            EXTENSIONS_TO_INSTALL="$EXTENSIONS_TO_INSTALL $ext"; \
        else \
            echo "$ext is already installed"; \
        fi; \
    done; \
    if [ -n "$EXTENSIONS_TO_INSTALL" ]; then \
        echo "Installing extensions:$EXTENSIONS_TO_INSTALL"; \
        docker-php-ext-install -j$(nproc) $EXTENSIONS_TO_INSTALL; \
    else \
        echo "All required extensions are already installed"; \
    fi

# Handle Xdebug separately since it might already be installed
RUN if ! php -m | grep -i xdebug > /dev/null; then \
        echo "Installing Xdebug via PECL"; \
        pecl install xdebug && docker-php-ext-enable xdebug; \
    else \
        echo "Xdebug already installed, skipping installation"; \
    fi

# Verify all extensions are now available
RUN echo "🔍 Final extension verification:" \
    && php -m | sort \
    && echo -e "\n📦 Checking required extensions:" \
    && for ext in gd intl mbstring opcache pdo_mysql zip xdebug; do \
        if php -m | grep -i "^$ext$" > /dev/null; then \
            echo "✅ $ext - Available"; \
        else \
            echo "❌ $ext - MISSING"; \
        fi; \
    done

# Test GD extension specifically
RUN echo -e "\n🎨 Testing GD extension:" \
    && php -r "if (!extension_loaded('gd')) { echo 'GD not loaded!'; exit(1); } echo 'GD loaded successfully\n'; print_r(gd_info());"

# Configure Xdebug for development
RUN { \
    echo "xdebug.mode=develop,debug"; \
    echo "xdebug.client_host=host.docker.internal"; \
    echo "xdebug.client_port=9003"; \
    echo "xdebug.start_with_request=yes"; \
    echo "xdebug.discover_client_host=true"; \
    } > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Configure PHP for development
RUN { \
    echo "memory_limit=512M"; \
    echo "max_execution_time=300"; \
    echo "display_errors=On"; \
    echo "display_startup_errors=On"; \
    echo "log_errors=On"; \
    echo "upload_max_filesize=64M"; \
    echo "post_max_size=64M"; \
    } > /usr/local/etc/php/conf.d/drupal-dev.ini

# Set the Chrome path for JavaScript testing
ENV CHROME_BIN=/usr/bin/chromium

# Create a simple script to verify extensions are working
RUN echo '#!/bin/bash' > /usr/local/bin/check-php-extensions \
    && echo 'echo "PHP Version: $(php --version | head -n 1)"' >> /usr/local/bin/check-php-extensions \
    && echo 'echo "Required extensions status:"' >> /usr/local/bin/check-php-extensions \
    && echo 'for ext in gd intl mbstring opcache pdo_mysql zip xdebug; do' >> /usr/local/bin/check-php-extensions \
    && echo '  if php -m | grep -i "^$ext$" > /dev/null; then' >> /usr/local/bin/check-php-extensions \
    && echo '    echo "✅ $ext"' >> /usr/local/bin/check-php-extensions \
    && echo '  else' >> /usr/local/bin/check-php-extensions \
    && echo '    echo "❌ $ext"' >> /usr/local/bin/check-php-extensions \
    && echo '  fi' >> /usr/local/bin/check-php-extensions \
    && echo 'done' >> /usr/local/bin/check-php-extensions \
    && chmod +x /usr/local/bin/check-php-extensions

# Run final verification
RUN check-php-extensions