#!/bin/bash
# coverage.sh
# A script to run both backend (Python) and frontend (Flutter) tests, generate coverage, and filter out generated files.

# Exit immediately if a command exits with a non-zero status
set -e

echo "============================================="
echo "🐍 Running Backend (Python) Tests & Coverage"
echo "============================================="
if [ -d "functions" ]; then
  cd functions
  # Run pytest with coverage
  python3 -m pytest tests/ --cov=. --cov-report=term-missing --cov-report=xml
  cd ..
  echo "✅ Backend coverage generated successfully."
else
  echo "⚠️  Warning: 'functions' directory not found. Skipping backend tests."
fi

echo ""
echo "============================================="
echo "📱 Running Frontend (Flutter) Tests & Coverage"
echo "============================================="
if [ -d "origna_gta" ]; then
  cd origna_gta
  
  echo "🧪 Running Flutter tests with coverage..."
  flutter test --coverage

  echo "🧹 Filtering out generated files from coverage..."
  # Use lcov to remove generated files. Requires lcov to be installed.
  if command -v lcov >/dev/null 2>&1; then
      lcov --ignore-errors unused --remove coverage/lcov.info \
          'lib/**/*.g.dart' \
          'lib/**/*.freezed.dart' \
          'lib/**/generated_plugin_registrant.dart' \
          'lib/generated/**' \
          -o coverage/lcov.info
      echo "✅ Filtered lcov.info generated successfully."
      
      # Optional: Generate HTML report for easy viewing
      if command -v genhtml >/dev/null 2>&1; then
          genhtml coverage/lcov.info -o coverage/html
          echo "📊 HTML report generated at origna_gta/coverage/html/index.html"
      fi
  else
      echo "⚠️  Warning: 'lcov' is not installed. Skipping coverage filtering."
      echo "💡 Install lcov (e.g., 'brew install lcov' or 'sudo apt-get install lcov') to filter generated files."
  fi
  cd ..
else
  echo "⚠️  Warning: 'origna_gta' directory not found. Skipping frontend tests."
fi

echo ""
echo "🎉 Coverage script completed!"
