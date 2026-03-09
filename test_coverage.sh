#!/bin/bash
set -e

cd origna_gta || exit 1

echo "Cleaning up old coverage..."
rm -rf coverage tmp_coverage
mkdir -p tmp_coverage

TEST_FILES=$(find test -name "*_test.dart" -type f)
TOTAL_TESTS=$(echo "$TEST_FILES" | wc -l | tr -d ' ')
CURRENT=1
FAILURES=0

for file in $TEST_FILES; do
  echo "[$CURRENT/$TOTAL_TESTS] Running $file..."
  
  # Run the test with a 2-minute timeout to prevent hanging forever
  # If a test fails or times out, we record it but continue
  if timeout 120s flutter test --coverage "$file"; then
    echo "✅ Passed: $file"
    # Rename lcov.info so it doesn't get overwritten
    if [ -f coverage/lcov.info ]; then
      cp coverage/lcov.info tmp_coverage/lcov_${CURRENT}.info
    fi
  else
    echo "❌ Failed or Timed Out: $file"
    FAILURES=$((FAILURES + 1))
  fi
  
  CURRENT=$((CURRENT + 1))
done

echo "Merging coverage reports..."
if command -v lcov >/dev/null 2>&1; then
  LCOV_ARGS=""
  for cov in tmp_coverage/lcov_*.info; do
    LCOV_ARGS="$LCOV_ARGS -a $cov"
  done
  
  if [ -n "$LCOV_ARGS" ]; then
    mkdir -p coverage
    lcov $LCOV_ARGS -o coverage/lcov_merged.info
    
    echo "Filtering generated files..."
    lcov --ignore-errors unused --remove coverage/lcov_merged.info \
        'lib/**/*.g.dart' \
        'lib/**/*.freezed.dart' \
        'lib/**/generated_plugin_registrant.dart' \
        'lib/generated/**' \
        -o coverage/lcov.info
        
    echo "✅ Filtered lcov.info generated successfully."
    genhtml coverage/lcov.info -o coverage/html
    
    # Calculate coverage percentage
    COVERAGE_PCT=$(lcov --summary coverage/lcov.info | grep "lines......" | cut -d ' ' -f 4 | cut -d '%' -f 1)
    echo "📊 Total Coverage: $COVERAGE_PCT%"
    
    # Check if >= 90
    if (( $(echo "$COVERAGE_PCT >= 90.0" | bc -l) )); then
      echo "🎉 Coverage is >= 90% ($COVERAGE_PCT%)"
    else
      echo "⚠️ Coverage is below 90% ($COVERAGE_PCT%)"
      exit 1
    fi
  fi
else
  echo "⚠️ lcov is not installed. Skipping merge."
fi

if [ $FAILURES -gt 0 ]; then
  echo "⚠️ $FAILURES test file(s) failed."
  exit 1
fi

echo "🎉 All tests finished!"
