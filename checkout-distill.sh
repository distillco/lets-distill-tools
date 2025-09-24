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
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
MAIN_BRANCH="$DISTILL_MAIN_BRANCH"# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
MAIN_BRANCH="$DISTILL_MAIN_BRANCH"# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
MAIN_BRANCH="$DISTILL_MAIN_BRANCH"# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
MAIN_BRANCH="$DISTILL_MAIN_BRANCH"# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
MAIN_BRANCH="$DISTILL_MAIN_BRANCH"# Function to log task to history
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
        echo -e "${RED}Error: Please provide a branch name${NC}"
        echo "Usage: $0 <branch-name>"
        echo ""
        echo "Example: $0 improve-sentry-filtering-matchers"
        echo "         $0 feature/add-dark-mode"
        exit 1
    fi

    # Get branch name from arguments
    BRANCH_NAME="$1"

    # Create a safe directory name from branch
    SAFE_NAME=$(echo "$BRANCH_NAME" | sed 's/[^a-zA-Z0-9-]/-/g')
    TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
    WORKTREE_PATH="$WORKTREE_BASE/$SAFE_NAME-existing-$TIMESTAMP"

    echo -e "${BLUE}🔍 Checking out existing branch: ${YELLOW}$BRANCH_NAME${NC}"
    echo -e "${BLUE}📁 Worktree path: ${NC}$WORKTREE_PATH"
    echo ""

    # Step 1: Update repository
    echo -e "${GREEN}1. Fetching latest changes...${NC}"
    cd "$REPO_BASE"
    git fetch --all

    # Step 2: Check if branch exists
    echo -e "${GREEN}2. Checking if branch exists...${NC}"

    # Check for local branch
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo -e "${GREEN}   Found local branch${NC}"
        BRANCH_REF="$BRANCH_NAME"
    # Check for remote branch
    elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
        echo -e "${GREEN}   Found remote branch${NC}"
        BRANCH_REF="origin/$BRANCH_NAME"
    else
        echo -e "${RED}Error: Branch '$BRANCH_NAME' not found locally or on origin${NC}"
        echo ""
        echo "Available branches containing this pattern:"
        git branch -a | grep -i "$BRANCH_NAME" || echo "  No matching branches found"
        exit 1
    fi

    # Step 3: Create worktree directory if needed
    if [ ! -d "$WORKTREE_BASE" ]; then
        echo -e "${GREEN}Creating worktree base directory...${NC}"
        mkdir -p "$WORKTREE_BASE"
    fi

    # Step 4: Check if worktree already exists for this branch
    existing_worktree=$(git worktree list | grep "\[$BRANCH_NAME\]" | awk '{print $1}' || true)
    if [ -n "$existing_worktree" ]; then
        echo -e "${YELLOW}⚠️  Worktree already exists for branch '$BRANCH_NAME' at:${NC}"
        echo "   $existing_worktree"
        echo ""
        read -p "Switch to existing worktree? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$existing_worktree"
            echo -e "${GREEN}✅ Switched to existing worktree${NC}"
            exec $SHELL
        else
            echo -e "${YELLOW}Creating new worktree for same branch...${NC}"
        fi
    fi

    # Step 5: Create new worktree
    echo -e "${GREEN}3. Creating worktree...${NC}"
    if [[ $BRANCH_REF == origin/* ]]; then
        # For remote branch, create local tracking branch
        LOCAL_BRANCH_NAME="${BRANCH_NAME}"
        git worktree add -b "$LOCAL_BRANCH_NAME" "$WORKTREE_PATH" "$BRANCH_REF"
        # Set upstream
        cd "$WORKTREE_PATH"
        git branch --set-upstream-to="$BRANCH_REF" "$LOCAL_BRANCH_NAME"
    else
        # For local branch, just check it out
        git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
        cd "$WORKTREE_PATH"
    fi

    # Step 6: Pull latest changes if tracking remote
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
        echo -e "${GREEN}4. Pulling latest changes...${NC}"
        git pull --ff-only 2>/dev/null || echo -e "${YELLOW}   Could not fast-forward, may need to merge/rebase${NC}"
    fi

    # Step 7: Install dependencies
    echo -e "${GREEN}5. Installing dependencies...${NC}"
    npm ci --silent

    # Step 8: Log task to history
    echo -e "${GREEN}6. Logging task to history...${NC}"
    log_task "Checkout: $BRANCH_NAME" "$BRANCH_NAME" "$(pwd)"

    # Step 9: Create task info file
    echo "# Task: Working on branch $BRANCH_NAME" > .task-info
    echo "Branch: $BRANCH_NAME" >> .task-info
    echo "Created: $(date)" >> .task-info
    echo "Type: Existing branch checkout" >> .task-info
    echo "" >> .task-info

    # Add commit history
    echo "## Recent commits on this branch:" >> .task-info
    git log --oneline -10 --graph --decorate >> .task-info
    echo "" >> .task-info
    echo "## Notes:" >> .task-info
    echo "" >> .task-info

    # Success message
    echo ""
    echo -e "${GREEN}✅ Worktree ready for branch '$BRANCH_NAME'!${NC}"
    echo -e "${YELLOW}You are now in: $(pwd)${NC}"
    echo ""

    # Show branch status
    echo -e "${BLUE}Branch status:${NC}"
    git status -sb
    echo ""

    echo -e "Quick commands:"
    echo -e "  ${BLUE}npm run dev${NC}     - Start development server"
    echo -e "  ${BLUE}npm run tsc:i${NC}   - Check types"
    echo -e "  ${BLUE}npm test${NC}        - Run tests"
    echo ""
    echo -e "When done, push your changes with:"
    echo -e "  ${BLUE}git add .${NC}"
    echo -e "  ${BLUE}git commit -m \"your message\"${NC}"
    echo -e "  ${BLUE}git push${NC}"

    # Open new shell in the worktree
    echo ""
    echo -e "${YELLOW}Starting new shell in worktree...${NC}"
    exec $SHELL
}

main "$@"