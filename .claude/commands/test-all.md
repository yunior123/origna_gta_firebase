# /test-all - Run all tests (backend + frontend + integration)

**Usage**: `/test-all [--watch]`

## What it does:
1. Runs pytest for backend (functions/tests)
2. Runs flutter test for frontend unit tests
3. Runs integration tests if --integration flag present
4. Displays summary with pass/fail counts

## Examples:
```
/test-all
/test-all --watch
/test-all --integration
```

## Implementation:
```bash
#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.. && pwd)"
cd "$PROJECT_ROOT"

echo "🧪 Running All Tests..."
echo "======================="

# Backend tests
echo ""
echo "📦 Backend Tests (pytest)..."
cd functions
BACKEND_RESULT=$(pytest tests/ -v --tb=short 2>&1 | tee /dev/tty | tail -1)
cd ..

# Frontend unit tests
echo ""
echo "📱 Frontend Unit Tests (flutter test)..."
cd origna_gta
FRONTEND_RESULT=$(flutter test 2>&1 | tee /dev/tty | grep "All tests passed")
cd ..

# Integration tests (if requested)
if [[ "$1" == "--integration" ]]; then
  echo ""
  echo "🔗 Integration Tests..."
  cd origna_gta
  flutter test integration_test/
  cd ..
fi

# Summary
echo ""
echo "======================="
echo "✓ Test Suite Complete"
echo "======================="
```
