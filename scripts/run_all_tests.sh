#!/bin/bash
# Run all tests with coverage report
# Usage: ./run_all_tests.sh

set -e

echo "╔══════════════════════════════════════════════╗"
echo "║   Origna GTA - Test Suite Execution         ║"
echo "║   Backend + Frontend Comprehensive Tests    ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Backend Tests
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   BACKEND PYTHON TESTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd functions

echo -e "${GREEN}[1/5]${NC} Installing Python dependencies..."
pip install -q pytest pytest-cov pytest-mock mockito

echo -e "${GREEN}[2/5]${NC} Running payment handler tests..."
pytest tests/test_handlers_payment_stripe.py -v --tb=short

echo -e "${GREEN}[3/5]${NC} Running products & orders tests..."
pytest tests/test_handlers_products_orders.py -v --tb=short

echo -e "${GREEN}[4/5]${NC} Running admin & cron tests..."
pytest tests/test_handlers_admin_cron.py -v --tb=short

echo -e "${GREEN}[5/5]${NC} Running edge cases & security tests..."
pytest tests/test_edge_cases_advanced.py -v --tb=short

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   COVERAGE REPORT - BACKEND${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

pytest tests/test_handlers*.py tests/test_edge*.py tests/test_e2e*.py \
  --cov=handlers \
  --cov-report=term-missing \
  --cov-report=html:../test-results/backend-coverage \
  --cov-fail-under=85 \
  -v

echo ""
echo -e "${GREEN}✓ Backend tests completed!${NC}"
echo "  Coverage report: test-results/backend-coverage/index.html"
echo ""

cd ..

# Frontend Tests
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   FRONTEND DART TESTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd origna_gta

echo -e "${GREEN}[1/3]${NC} Installing Flutter dependencies..."
flutter pub get > /dev/null

echo -e "${GREEN}[2/3]${NC} Running unit tests..."
flutter test test/unit/ --reporter expanded

echo -e "${GREEN}[3/3]${NC} Running advanced ViewModel tests..."
flutter test test/unit/advanced_viewmodel_test.dart --reporter expanded

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   COVERAGE REPORT - FRONTEND${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

flutter test --coverage --coverage-path=../test-results/frontend-coverage/lcov.info

# Generate HTML report (requires lcov)
if command -v genhtml &> /dev/null; then
    genhtml ../test-results/frontend-coverage/lcov.info -o ../test-results/frontend-coverage/html
    echo ""
    echo -e "${GREEN}✓ Frontend tests completed!${NC}"
    echo "  Coverage report: test-results/frontend-coverage/html/index.html"
else
    echo ""
    echo -e "${GREEN}✓ Frontend tests completed!${NC}"
    echo -e "${RED}  Note: Install lcov to generate HTML report (brew install lcov)${NC}"
fi

cd ..

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   TEST SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Count test files
BACKEND_TEST_FILES=$(find functions/tests -name "test_handlers*.py" -o -name "test_edge*.py" -o -name "test_e2e*.py" | wc -l | tr -d ' ')
FRONTEND_TEST_FILES=$(find origna_gta/test/unit -name "*test.dart" | wc -l | tr -d ' ')

echo "📊 Test Files:"
echo "   Backend:  ${BACKEND_TEST_FILES} files"
echo "   Frontend: ${FRONTEND_TEST_FILES} files"
echo ""

echo "📁 Reports Generated:"
echo "   Backend:  test-results/backend-coverage/index.html"
echo "   Frontend: test-results/frontend-coverage/html/index.html"
echo ""

echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ALL TESTS PASSED ✓                  ║${NC}"
echo -e "${GREEN}║   Production Ready - Audit Ready             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Open coverage reports
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Opening coverage reports..."
    open test-results/backend-coverage/index.html
    if [ -f "test-results/frontend-coverage/html/index.html" ]; then
        open test-results/frontend-coverage/html/index.html
    fi
fi
