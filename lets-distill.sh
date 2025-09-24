#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$LETS_DISTILL_WORKTREE_BASE"
HISTORY_FILE="$LETS_DISTILL_HISTORY_FILE"
MAIN_BRANCH="$LETS_DISTILL_MAIN_BRANCH"
REPO_BASE="$DISTILL_REPO_BASE"

# Function to sanitize task name for branch/directory
sanitize_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//'
}

# Function to log task to history
log_task() {
    local task_name="$1"
    local branch_name="$2"
    local worktree_path="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $task_name | Branch: $branch_name | Path: $worktree_path" >> "$HISTORY_FILE"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: Please provide a task description${NC}"
        echo "Usage: $0 <task-description>"
        echo ""
        echo "Example: $0 fix-auth-bug"
        echo "         $0 review-pr-1234"
        exit 1
    fi

    # Get task description from all arguments
    TASK_DESC="$*"

    # Check if this might be an existing branch name (no spaces, contains dashes/slashes)
    if [[ $# -eq 1 && "$1" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
        echo -e "${YELLOW}🔍 Checking if '$1' is an existing branch...${NC}"
        cd "$REPO_BASE"
        git fetch origin --quiet 2>/dev/null || true

        # Check if it's an existing branch
        if git show-ref --verify --quiet "refs/heads/$1" || git show-ref --verify --quiet "refs/remotes/origin/$1"; then
            echo -e "${GREEN}✅ Found existing branch '$1', using checkout-distill.sh${NC}"
            exec "$SCRIPT_DIR/checkout-distill.sh" "$1"
        else
            echo -e "${BLUE}ℹ️  No existing branch found, creating new task${NC}"
        fi
    fi

    SAFE_NAME=$(sanitize_name "$TASK_DESC")

    # Generate unique branch name with timestamp to avoid conflicts
    TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
    BRANCH_NAME="${SAFE_NAME}-${TIMESTAMP}"

    # Create worktree directory path
    WORKTREE_PATH="$WORKTREE_BASE/$SAFE_NAME-$TIMESTAMP"

    echo -e "${BLUE}🚀 Starting new task: ${YELLOW}$TASK_DESC${NC}"
    echo -e "${BLUE}📁 Worktree path: ${NC}$WORKTREE_PATH"
    echo -e "${BLUE}🌿 Branch name: ${NC}$BRANCH_NAME"
    echo ""

    # Step 1: Update main branch
    echo -e "${GREEN}1. Updating main branch...${NC}"
    cd "$REPO_BASE"
    git fetch origin "$MAIN_BRANCH"

    # Step 2: Create worktree directory if needed
    if [ ! -d "$WORKTREE_BASE" ]; then
        echo -e "${GREEN}Creating worktree base directory...${NC}"
        mkdir -p "$WORKTREE_BASE"
    fi

    # Step 3: Create new worktree with new branch
    echo -e "${GREEN}2. Creating new worktree...${NC}"
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "origin/$MAIN_BRANCH"

    # Step 4: Change to worktree directory
    echo -e "${GREEN}3. Switching to worktree directory...${NC}"
    cd "$WORKTREE_PATH"

    # Step 5: Install dependencies
    echo -e "${GREEN}4. Installing dependencies...${NC}"
    npm ci --silent

    # Step 6: Log task to history
    echo -e "${GREEN}5. Logging task to history...${NC}"
    log_task "$TASK_DESC" "$BRANCH_NAME" "$(pwd)"

    # Step 7: Create task info file in worktree
    echo "# Task: $TASK_DESC" > .task-info
    echo "Branch: $BRANCH_NAME" >> .task-info
    echo "Created: $(date)" >> .task-info
    echo "" >> .task-info
    echo "## Notes:" >> .task-info
    echo "" >> .task-info

    # Success message
    echo ""
    echo -e "${GREEN}✅ Task workspace ready!${NC}"
    echo -e "${YELLOW}You are now in: $(pwd)${NC}"
    echo ""
    echo -e "Quick commands:"
    echo -e "  ${BLUE}npm run dev${NC}     - Start development server"
    echo -e "  ${BLUE}npm run tsc:i${NC}   - Check types"
    echo -e "  ${BLUE}npm test${NC}        - Run tests"
    echo ""
    echo -e "When done, commit your changes and create a PR with:"
    echo -e "  ${BLUE}git add .${NC}"
    echo -e "  ${BLUE}git commit -m \"your message\"${NC}"
    echo -e "  ${BLUE}git push -u origin $BRANCH_NAME${NC}"
    echo -e "  ${BLUE}gh pr create${NC}"

    # Stay in the worktree directory
    echo ""
    echo -e "${YELLOW}Workspace ready at: $(pwd)${NC}"

    # Output the directory for the shell function to parse
    echo "WORKTREE_DIR:$(pwd)"
}

main "$@"