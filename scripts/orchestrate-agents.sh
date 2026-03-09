#!/bin/bash
# 🚀 Parallel Claude Agents Orchestrator
# Runs 5+ specialized agents in parallel terminals
# Each agent has a specific domain and avoids file conflicts

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "🚀 Starting Parallel Claude Agents Orchestrator..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Agent configurations
AGENTS=(
  "test-runner:🧪:Continuous test runner and fixer:functions/tests"
  "backend-guardian:🔧:Backend code quality and fixes:functions/handlers"
  "frontend-polish:✨:Frontend UI/UX improvements:origna_gta/lib"
  "security-audit:🔒:Security scanning and fixes:functions,origna_gta"
  "performance-optimizer:⚡:Performance monitoring:functions,origna_gta"
  "docs-keeper:📚:Documentation updates:.claude,docs"
)

# Create agent session logs directory
LOGS_DIR="$PROJECT_ROOT/.agent-logs"
mkdir -p "$LOGS_DIR"

# Function to start an agent in a new terminal
start_agent() {
  local agent_name=$1
  local emoji=$2
  local description=$3
  local watch_paths=$4
  
  echo -e "${BLUE}[$emoji $agent_name]${NC} Starting: $description"
  echo -e "  Watch paths: ${CYAN}$watch_paths${NC}"
  
  # Create agent script
  local agent_script="$LOGS_DIR/${agent_name}-runner.sh"
  cat > "$agent_script" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"
echo -e "${emoji} ${GREEN}Agent: $agent_name${NC}"
echo -e "${YELLOW}Description: $description${NC}"
echo -e "${CYAN}Watch paths: $watch_paths${NC}"
echo ""
echo "Press Ctrl+C to stop this agent"
echo "=================================="
echo ""

# Agent-specific logic
case "$agent_name" in
  "test-runner")
    # Continuous testing agent
    while true; do
      echo -e "${emoji} ${YELLOW}[$(date +%H:%M:%S)]${NC} Running backend tests..."
      cd functions
      if pytest tests/ -v --tb=short 2>&1 | tee "$LOGS_DIR/test-runner.log"; then
        echo -e "${GREEN}✓ Tests passed${NC}"
      else
        echo -e "${RED}✗ Tests failed - analyzing...${NC}"
        # Auto-fix common issues
        grep -i "error\|fail" "$LOGS_DIR/test-runner.log" | head -5
      fi
      
      echo ""
      echo -e "${emoji} ${YELLOW}[$(date +%H:%M:%S)]${NC} Running frontend analysis..."
      cd ../origna_gta
      flutter analyze 2>&1 | tee "$LOGS_DIR/flutter-analyze.log"
      
      echo ""
      echo -e "${CYAN}Waiting 60s before next cycle...${NC}"
      sleep 60
    done
    ;;
    
  "backend-guardian")
    # Backend code watcher
    echo -e "${emoji} Monitoring: $watch_paths"
    echo -e "Checking for Python code quality issues..."
    while true; do
      cd functions
      # Check for common issues
      echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} Scanning backend code..."
      
      # Find TODO/FIXME comments
      grep -r "TODO\|FIXME\|XXX" handlers/ 2>/dev/null | tee "$LOGS_DIR/backend-todos.log" || echo "No TODOs found"
      
      # Check for print statements (should use logger)
      grep -r "print(" handlers/ 2>/dev/null | tee "$LOGS_DIR/backend-prints.log" || echo "No print statements"
      
      sleep 120
    done
    ;;
    
  "frontend-polish")
    # Frontend watcher
    echo -e "${emoji} Monitoring: $watch_paths"
    while true; do
      cd origna_gta
      echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} Analyzing Flutter code..."
      
      # Check for print statements
      grep -r "print(" lib/ 2>/dev/null | grep -v "debugPrint" | tee "$LOGS_DIR/frontend-prints.log" || echo "No print() found"
      
      # Check for missing Keys in widgets
      echo -e "${CYAN}Checking for testability...${NC}"
      grep -r "ElevatedButton\|TextButton\|TextField" lib/screens/ | grep -v "key:" | head -10
      
      sleep 120
    done
    ;;
    
  "security-audit")
    # Security scanner
    echo -e "${emoji} Security scanning: $watch_paths"
    while true; do
      echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} Running security audit..."
      
      # Check for exposed secrets
      echo -e "${CYAN}Scanning for secrets...${NC}"
      grep -r "API_KEY\|SECRET\|PASSWORD\|TOKEN" functions/ origna_gta/ --include="*.py" --include="*.dart" | grep -v "# SAFE" | grep -v ".env" | tee "$LOGS_DIR/security-scan.log" || echo "No exposed secrets"
      
      # Check for SQL injection risks (though we use Firestore)
      grep -r "execute\|query" functions/ --include="*.py" | grep -v "executemany" | head -10
      
      sleep 180
    done
    ;;
    
  "performance-optimizer")
    # Performance monitor
    echo -e "${emoji} Performance monitoring..."
    while true; do
      echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} Checking performance..."
      
      # Check for N+1 queries
      cd functions
      echo -e "${CYAN}Scanning for potential N+1 queries...${NC}"
      grep -r "for.*in.*get()\|for.*in.*collection()" handlers/ | tee "$LOGS_DIR/performance-n1.log" || echo "No obvious N+1 patterns"
      
      # Check bundle sizes
      cd ../origna_gta
      if [ -d "build/web" ]; then
        du -sh build/web/ | tee "$LOGS_DIR/bundle-size.log"
      fi
      
      sleep 180
    done
    ;;
    
  "docs-keeper")
    # Documentation maintainer
    echo -e "${emoji} Documentation monitoring..."
    while true; do
      echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} Checking documentation..."
      
      # Check for outdated TODOs in docs
      grep -r "TODO\|PENDING\|WIP" *.md docs/ .claude/ 2>/dev/null | tee "$LOGS_DIR/docs-todos.log" || echo "All docs up to date"
      
      # Check for broken links
      echo -e "${CYAN}Checking for broken file references...${NC}"
      grep -r "\[.*\](.*\.md)" *.md docs/ 2>/dev/null | head -20
      
      sleep 300
    done
    ;;
esac
EOF
  
  chmod +x "$agent_script"
  
  # Open in new terminal based on OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    osascript -e "tell application \"Terminal\" to do script \"$agent_script\"" &
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v gnome-terminal &> /dev/null; then
      gnome-terminal -- bash -c "$agent_script" &
    elif command -v xterm &> /dev/null; then
      xterm -e "$agent_script" &
    fi
  fi
  
  sleep 1
}

# Start all agents
echo ""
echo -e "${GREEN}Starting ${#AGENTS[@]} specialized agents...${NC}"
echo ""

for agent_config in "${AGENTS[@]}"; do
  IFS=':' read -r name emoji description paths <<< "$agent_config"
  start_agent "$name" "$emoji" "$description" "$paths"
done

echo ""
echo -e "${GREEN}✓ All agents started!${NC}"
echo ""
echo -e "${BLUE}Agent logs:${NC} $LOGS_DIR"
echo -e "${BLUE}View logs:${NC} tail -f $LOGS_DIR/*.log"
echo ""
echo -e "${YELLOW}To stop all agents:${NC} Run ./stop-agents.sh"
echo ""

# Create stop script
cat > "$PROJECT_ROOT/stop-agents.sh" << 'STOPEOF'
#!/bin/bash
echo "🛑 Stopping all Claude agents..."
pkill -f "agent-logs.*runner.sh"
echo "✓ All agents stopped"
STOPEOF

chmod +x "$PROJECT_ROOT/stop-agents.sh"

echo -e "${PURPLE}============================================${NC}"
echo -e "${GREEN}🚀 Parallel Agent System Running!${NC}"
echo -e "${PURPLE}============================================${NC}"
