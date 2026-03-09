# /fix-tests - Auto-fix common test failures

**Usage**: `/fix-tests [backend|frontend|all]`

## What it does:
1. Runs tests to identify failures
2. Analyzes error messages
3. Applies common fixes:
   - Missing imports
   - Mock/fixture issues
   - Type mismatches
   - Assertion errors
4. Re-runs tests to verify fixes

## Examples:
```
/fix-tests
/fix-tests backend
/fix-tests frontend
```

## Common Fixes Applied:

### Backend (Python/pytest)
- ✅ Add missing Firebase mock fixtures
- ✅ Fix import paths
- ✅ Update test data to match schema
- ✅ Add missing `@patch` decorators

### Frontend (Flutter)
- ✅ Add missing `setUp`/`tearDown`
- ✅ Fix widget test pumping
- ✅ Add missing `ProviderScope` wrapper
- ✅ Update golden files

## Implementation:
```bash
#!/bin/bash
TARGET=${1:-all}

echo "🔧 Auto-fixing tests: $TARGET"

if [[ "$TARGET" == "backend" || "$TARGET" == "all" ]]; then
  cd functions
  pytest tests/ -v --tb=short > test_results.txt 2>&1
  
  # Analyze failures
  grep -A 5 "FAILED" test_results.txt | while read line; do
    if [[ "$line" =~ "ImportError" ]]; then
      echo "Fixing import error..."
      # Auto-fix logic here
    fi
  done
  
  cd ..
fi

if [[ "$TARGET" == "frontend" || "$TARGET" == "all" ]]; then
  cd origna_gta
  flutter test --reporter=expanded > test_results.txt 2>&1
  
  # Analyze and fix
  grep "FAILED" test_results.txt | while read line; do
    echo "Analyzing: $line"
    # Auto-fix logic here
  done
  
  cd ..
fi

echo "✓ Fixes applied. Re-running tests..."
```
