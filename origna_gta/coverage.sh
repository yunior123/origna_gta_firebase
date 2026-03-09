#!/bin/bash
# scripts/coverage.sh
# A script to run Flutter tests, generate coverage, and filter out generated files.

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure we are in the origna_gta directory
if [ -d "origna_gta" ]; then
  cd origna_gta
fi

echo "🧪 Running Flutter tests with coverage..."
flutter test --coverage

echo "🧹 Filtering out generated files from coverage..."
# Use lcov to remove generated files. Requires lcov to be installed.
# Mac: brew install lcov
# Linux: sudo apt-get install lcov
if command -v lcov >/dev/null 2>&1; then
    lcov --ignore-errors unused --remove coverage/lcov.info \
        'lib/**/*.g.dart' \
        'lib/**/*.freezed.dart' \
        'lib/**/generated_plugin_registrant.dart' \
        'lib/generated/**' \
        'lib/previews/**' \
        -o coverage/lcov.info
    echo "✅ Filtered lcov.info generated successfully."
    
    # Optional: Generate HTML report for easy viewing
    if command -v genhtml >/dev/null 2>&1; then
        genhtml coverage/lcov.info -o coverage/html
        echo "📊 HTML report generated at coverage/html/index.html"
    fi
else
    echo "⚠️  Warning: 'lcov' is not installed. Skipping coverage filtering."
    echo "💡 Install lcov (e.g., 'brew install lcov' or 'sudo apt-get install lcov') to filter generated files."
fi
