#!/usr/bin/env bash
# test-extensions.sh - Run this script to test if extensions are available

echo "🔍 PHP Version and Extensions Test"
echo "================================="
echo "PHP Version: $(php --version | head -n 1)"
echo ""

# Test each required extension
extensions=("gd" "intl" "mbstring" "opcache" "pdo_mysql" "zip" "xdebug")

echo "📦 Extension Status:"
for ext in "${extensions[@]}"; do
    if php -m | grep -i "$ext" > /dev/null; then
        echo "✅ $ext - INSTALLED"
    else
        echo "❌ $ext - MISSING"
    fi
done

echo ""
echo "🎨 GD Extension Details:"
php -r "
if (extension_loaded('gd')) {
    echo '✅ GD Extension is loaded\n';
    print_r(gd_info());
} else {
    echo '❌ GD Extension is NOT loaded\n';
    exit(1);
}
"

echo ""
echo "📋 All Available Extensions:"
php -m

echo ""
echo "📄 PHP Configuration Files:"
php --ini