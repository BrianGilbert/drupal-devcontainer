#!/usr/bin/env bash
set -e

# Temporarily disable Xdebug during setup to avoid connection warnings
export XDEBUG_MODE=off

echo "🛠️  Setting up Drupal core development environment in web directory…"

# CRITICAL: Verify PHP extensions before running Composer
echo "🔍 Verifying PHP extensions before Composer operations..."
echo "PHP Version: $(php --version | head -n 1)"
echo "Available Extensions:"
php -m

# Verify GD extension specifically
if php -m | grep -i gd > /dev/null; then
    echo "✅ GD extension is available"
    php -r "print_r(gd_info());"
else
    echo "❌ GD extension is NOT available"
    echo "Available extensions:"
    php -m
    echo "PHP INI files:"
    php --ini
    exit 1
fi

# Verify other required extensions
REQUIRED_EXTENSIONS="intl mbstring opcache pdo_mysql zip"
for ext in $REQUIRED_EXTENSIONS; do
    if php -m | grep -i "$ext" > /dev/null; then
        echo "✅ $ext extension is available"
    else
        echo "❌ $ext extension is NOT available"
        exit 1
    fi
done

# Install Drush
echo "📦 Installing Drush launcher globally…"
sudo curl -L https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar -o /usr/local/bin/drush
sudo chmod +x /usr/local/bin/drush

# Install global Composer packages for development
echo "📦 Configuring Composer to allow plugins globally…"
composer global config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true --no-interaction

echo "📦 Installing global Composer packages for development…"
export XDEBUG_MODE=off
composer global require drupal/coder dealerdirect/phpcodesniffer-composer-installer squizlabs/php_codesniffer --no-interaction --verbose

# Determine the Composer global bin directory
COMPOSER_BIN_DIR=$(composer global config bin-dir --absolute)
if [ -z "$COMPOSER_BIN_DIR" ]; then
    echo "❌ Failed to determine Composer global bin directory"
    exit 1
fi

# Add Composer bin directory to PATH
export PATH="$COMPOSER_BIN_DIR:$PATH"

# Verify phpcs installation
if [ -f "$COMPOSER_BIN_DIR/phpcs" ]; then
    echo "✅ PHP CodeSniffer installed at $COMPOSER_BIN_DIR/phpcs"
    # Configure PHP CodeSniffer for Drupal coding standards
    COMPOSER_HOME=$(composer global config home)
    if [ -d "$COMPOSER_HOME/vendor/drupal/coder/coder_sniffer" ]; then
        "$COMPOSER_BIN_DIR/phpcs" --config-set installed_paths "$COMPOSER_HOME/vendor/drupal/coder/coder_sniffer"
        echo "✅ PHP CodeSniffer configured for Drupal coding standards"
    else
        echo "❌ Drupal coder_sniffer directory not found at $COMPOSER_HOME/vendor/drupal/coder/coder_sniffer"
        exit 1
    fi
else
    echo "❌ PHP CodeSniffer not found in $COMPOSER_BIN_DIR"
    exit 1
fi

# Install Git if not present
if ! command -v git &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y git
fi

# Create a proper Drupal project structure
if [ ! -f "/workspace/composer.json" ]; then
    echo "📦 Creating Drupal project with composer…"
    cd /workspace
    
    # Create a composer.json for the project root with proper scaffolding
    cat > composer.json << 'EOF'
{
    "name": "drupal/core-dev-project",
    "description": "Drupal core development project",
    "type": "project",
    "license": "GPL-2.0-or-later",
    "require": {
        "composer/installers": "^2.0",
        "drupal/core-composer-scaffold": "^10.0",
        "drupal/core-project-message": "^10.0",
        "drupal/core-recommended": "^10.0"
    },
    "require-dev": {
        "drupal/core-dev": "^10.0",
        "drush/drush": "^13.0"
    },
    "repositories": [
        {
            "type": "composer",
            "url": "https://packages.drupal.org/8"
        }
    ],
    "extra": {
        "drupal-scaffold": {
            "locations": {
                "web-root": "web/"
            },
            "file-mapping": {
                "[web-root]/.gitattributes": false,
                "[web-root]/.csslintrc": false,
                "[web-root]/.eslintignore": false,
                "[web-root]/.eslintrc.json": false,
                "[web-root]/.ht.router.php": false,
                "[web-root]/.htaccess": false,
                "[web-root]/example.gitignore": false,
                "[web-root]/index.php": false,
                "[web-root]/INSTALL.txt": false,
                "[web-root]/README.md": false,
                "[web-root]/robots.txt": false,
                "[web-root]/update.php": false,
                "[web-root]/web.config": false
            }
        },
        "installer-paths": {
            "web/core": ["type:drupal-core"],
            "web/libraries/{$name}": ["type:drupal-library"],
            "web/modules/contrib/{$name}": ["type:drupal-module"],
            "web/profiles/contrib/{$name}": ["type:drupal-profile"],
            "web/themes/contrib/{$name}": ["type:drupal-theme"],
            "drush/Commands/contrib/{$name}": ["type:drupal-drush"]
        },
        "drupal-core-project-message": {
            "include-keys": ["homepage", "support"],
            "post-create-project-cmd-message": [
                "<bg=blue;fg=white>                                                         </>",
                "<bg=blue;fg=white>  Congratulations, you've installed the Drupal codebase  </>",
                "<bg=blue;fg=white>  from the drupal/recommended-project template!          </>",
                "<bg=blue;fg=white>                                                         </>",
                "",
                "<bg=yellow;fg=black>Next steps</>:",
                "  * Install the site: https://www.drupal.org/docs/8/install",
                "  * Read the user guide: https://www.drupal.org/docs/user_guide/en/index.html",
                "  * Get support: https://www.drupal.org/support",
                "  * Get involved with the Drupal community:",
                "      https://www.drupal.org/getting-involved",
                "  * Remove the plugin that prints this message:",
                "      composer remove drupal/core-project-message"
            ]
        }
    },
    "config": {
        "allow-plugins": {
            "composer/installers": true,
            "drupal/core-composer-scaffold": true,
            "drupal/core-project-message": true,
            "dealerdirect/phpcodesniffer-composer-installer": true,
            "phpstan/extension-installer": true,
            "cweagans/composer-patches": true
        },
        "sort-packages": true
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
EOF

    echo "📦 Installing Composer dependencies and scaffolding Drupal…"
    # Increase memory limit and timeout for large installations
    export COMPOSER_MEMORY_LIMIT=-1
    export COMPOSER_PROCESS_TIMEOUT=600
    composer install --no-interaction --verbose --prefer-dist
    
    # Install Drush locally if not already present
    if ! composer show drush/drush > /dev/null 2>&1; then
        echo "📦 Installing Drush locally…"
        export COMPOSER_MEMORY_LIMIT=-1
        export COMPOSER_PROCESS_TIMEOUT=300
        composer require drush/drush --dev --no-interaction --verbose --prefer-dist
    fi
    
    # Now that we have a proper Drupal installation, set up the development core
    if [ ! -d "/workspace/drupal-dev" ]; then
        echo "📦 Cloning Drupal core repository for development…"
        git clone https://git.drupalcode.org/project/drupal.git drupal-dev
        cd drupal-dev
        # Checkout the appropriate branch for development
        git checkout 11.x
        cd /workspace
    fi
    
    # Replace the installed core with a symlink to the development version
    echo "🔗 Setting up development core symlink…"
    if [ -d "/workspace/web/core" ]; then
        rm -rf /workspace/web/core
    fi
    ln -sf /workspace/drupal-dev /workspace/web/core
    
    # Create essential directories that might be missing
    mkdir -p /workspace/web/modules/custom
    mkdir -p /workspace/web/modules/contrib
    mkdir -p /workspace/web/themes/custom
    mkdir -p /workspace/web/themes/contrib
    mkdir -p /workspace/web/profiles/custom
    mkdir -p /workspace/web/profiles/contrib
    mkdir -p /workspace/web/sites/default/files
    
    # Ensure proper permissions for sites/default/files
    chmod 755 /workspace/web/sites/default/files
    
else
    echo "📦 Updating existing Drupal project…"
    cd /workspace
    
    # Ensure Drush is installed locally
    if ! composer show drush/drush > /dev/null 2>&1; then
        echo "📦 Installing Drush locally…"
        export COMPOSER_MEMORY_LIMIT=-1
        export COMPOSER_PROCESS_TIMEOUT=300
        composer require drush/drush --dev --no-interaction --verbose --prefer-dist
    fi
    
    export COMPOSER_MEMORY_LIMIT=-1
    export COMPOSER_PROCESS_TIMEOUT=600
    composer update --no-interaction --verbose --prefer-dist
    
    # Update the development repository
    if [ -d "/workspace/drupal-dev" ]; then
        cd /workspace/drupal-dev
        git pull origin
        cd /workspace
    fi
    
    # Ensure the symlink is still correct
    if [ ! -L "/workspace/web/core" ] || [ ! -d "/workspace/web/core" ]; then
        echo "🔗 Re-establishing development core symlink…"
        rm -rf /workspace/web/core
        ln -sf /workspace/drupal-dev /workspace/web/core
    fi
fi

# Wait for database to be ready with better error handling and timeout
echo "⏳ Waiting for database to be ready…"
TIMEOUT=120  # 2 minutes timeout
COUNTER=0
while ! mysqladmin ping -h db -u drupal -pdrupal --silent 2>/dev/null; do
    if [ $COUNTER -ge $TIMEOUT ]; then
        echo "❌ Database failed to start within $TIMEOUT seconds"
        echo "🔍 Checking database container status..."
        docker ps | grep db || echo "Database container not running"
        echo "📋 Database container logs:"
        docker logs $(docker ps -q -f name=db) 2>/dev/null | tail -20 || echo "Could not retrieve logs"
        exit 1
    fi
    echo "Still waiting for database... ($COUNTER/$TIMEOUT seconds)"
    sleep 3
    COUNTER=$((COUNTER + 3))
done
echo "✅ Database is ready!"

# Set up the site for development
echo "🚀 Setting up Drupal for core development…"

# Create sites/default/settings.php if it doesn't exist
if [ ! -f "/workspace/web/sites/default/settings.php" ]; then
    mkdir -p /workspace/web/sites/default
    if [ -f "/workspace/web/core/sites/default/default.settings.php" ]; then
        cp /workspace/web/core/sites/default/default.settings.php /workspace/web/sites/default/settings.php
    else
        # Create a minimal settings.php if default doesn't exist
        cat > /workspace/web/sites/default/settings.php << 'EOF'
<?php
$databases = [];
$settings['hash_salt'] = '';
$settings['update_free_access'] = FALSE;
$settings['container_yamls'][] = $app_root . '/sites/default/services.yml';
$settings['file_scan_ignore_directories'] = [
  'node_modules',
  'bower_components',
];
$settings['entity_update_batch_size'] = 50;
$settings['entity_update_backup'] = TRUE;
$settings['migrate_node_migrate_type_classic'] = FALSE;
EOF
    fi
    chmod 666 /workspace/web/sites/default/settings.php
fi

# Install Drupal
drush site:install standard \
    --root=/workspace/web \
    --db-url=mysql://drupal:drupal@db/drupal \
    --site-name="Drupal Core Development" \
    --account-name=admin \
    --account-pass=admin \
    --yes

# Enable development settings
echo "🔧 Configuring development settings…"

# Create/update settings.local.php for development
cat > /workspace/web/sites/default/settings.local.php << 'EOF'
<?php
/**
 * @file
 * Local development settings.
 */

// Disable CSS and JS aggregation.
$config['system.performance']['css']['preprocess'] = FALSE;
$config['system.performance']['js']['preprocess'] = FALSE;

// Enable verbose error reporting.
$config['system.logging']['error_level'] = 'verbose';

// Disable the render cache and dynamic page cache.
$settings['cache']['bins']['render'] = 'cache.backend.null';
$settings['cache']['bins']['page'] = 'cache.backend.null';
$settings['cache']['bins']['dynamic_page_cache'] = 'cache.backend.null';

// Enable local development services.
$settings['container_yamls'][] = DRUPAL_ROOT . '/sites/development.services.yml';

// Trusted host configuration for development.
$settings['trusted_host_patterns'] = [
  '^localhost$',
  '^127\.0\.0\.1$',
  '^0\.0\.0\.0$',
  '^host\.docker\.internal$',
];
EOF

# Include settings.local.php in settings.php if not already included
if ! grep -q "settings.local.php" /workspace/web/sites/default/settings.php; then
    cat >> /workspace/web/sites/default/settings.php << 'EOF'

/**
 * Load local development override configuration, if available.
 */
if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
  include $app_root . '/' . $site_path . '/settings.local.php';
}
EOF
fi

# Set proper permissions
chmod 444 /workspace/web/sites/default/settings.php
chmod 555 /workspace/web/sites/default

# Enable useful development modules if available
echo "🧩 Enabling development modules…"
drush en devel webprofiler dblog views_ui field_ui -y --root=/workspace/web || echo "Some modules not available, continuing..."

# Set up PHPUnit configuration for core testing
if [ -f "/workspace/drupal-dev/core/phpunit.xml.dist" ] && [ ! -f "/workspace/drupal-dev/core/phpunit.xml" ]; then
    echo "🧪 Setting up PHPUnit configuration…"
    cp /workspace/drupal-dev/core/phpunit.xml.dist /workspace/drupal-dev/core/phpunit.xml

    # Update database settings in phpunit.xml
    sed -i 's|mysql://username:password@localhost/databasename|mysql://drupal:drupal@db/drupal|g' /workspace/drupal-dev/core/phpunit.xml
fi

# Create a convenient script for running tests
cat > /workspace/run-tests.sh << 'EOF'
#!/bin/bash
# Convenience script for running Drupal core tests
# Usage: ./run-tests.sh [test-suite] [specific-test]
# Example: ./run-tests.sh Unit ConfigEntityUnitTest

cd /workspace/drupal-dev/core

if [ -z "$1" ]; then
    echo "Available test suites:"
    echo "  Unit - Unit tests"
    echo "  Kernel - Kernel tests"
    echo "  Functional - Functional tests"
    echo "  FunctionalJavascript - JavaScript tests"
    echo ""
    echo "Usage: ./run-tests.sh [test-suite] [specific-test-class]"
    exit 1
fi

if [ -z "$2" ]; then
    ../../vendor/bin/phpunit --testsuite "$1"
else
    ../../vendor/bin/phpunit --testsuite "$1" --filter "$2"
fi
EOF

chmod +x /workspace/run-tests.sh

# Verify the web directory structure
echo "🔍 Verifying web directory structure…"
echo "Contents of /workspace/web/:"
ls -la /workspace/web/

echo ""
echo "✅ Drupal core development environment ready!"
echo "🌐 Access your site at http://localhost"
echo "👤 Admin login: admin / admin"
echo "🧪 Run tests with: ./run-tests.sh Unit"
echo "📝 Core development code is in: /workspace/drupal-dev/"
echo "🌍 Web root is in: /workspace/web/"
echo "📦 Vendor dependencies are in: /workspace/vendor/"
echo "🔧 Development settings enabled in web/sites/default/settings.local.php"
echo "📁 Your .devcontainer folder is preserved in /workspace/.devcontainer"

# Re-enable Xdebug for development
export XDEBUG_MODE=develop,debug