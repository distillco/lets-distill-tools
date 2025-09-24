#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Use config variables
WORKTREE_BASE="$DISTILL_WORKTREE_BASE"
HISTORY_FILE="$DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"
# Function to get branch status
get_branch_status() {
    local branch="$1"
    local remote_exists=$(git ls-remote --heads origin "$branch" 2>/dev/null)

    if [ -n "$remote_exists" ]; then
        # Check if branch is merged
        if git branch -r --merged origin/main | grep -q "origin/$branch"; then
            echo "merged"
        else
            echo "unmerged"
        fi
    else
        echo "local-only"
    fi
}

# Function to remove a worktree
remove_worktree() {
    local path="$1"
    local branch="$2"

    echo -e "${YELLOW}Removing worktree:${NC}"
    echo -e "  Path: $path"
    echo -e "  Branch: $branch"

    # Remove the worktree
    git worktree remove "$path" --force 2>/dev/null || git worktree prune

    # Optionally delete the branch
    read -p "Delete local branch '$branch'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git branch -D "$branch" 2>/dev/null || echo -e "${YELLOW}Branch already deleted or doesn't exist${NC}"
    fi

    echo -e "${GREEN}✅ Worktree removed${NC}"
}

# Function to clean old worktrees interactively
clean_interactive() {
    echo -e "${CYAN}🧹 Cleaning Old Worktrees${NC}"
    echo ""

    local found_worktrees=false

    while IFS= read -r line; do
        if [[ $line == *"lets-distill"* ]]; then
            found_worktrees=true
            path=$(echo "$line" | awk '{print $1}')
            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

            # Skip if path doesn't exist
            if [ ! -d "$path" ]; then
                echo -e "${YELLOW}Orphaned worktree found (path doesn't exist): $path${NC}"
                git worktree prune
                continue
            fi

            # Get task info
            task_name="Unknown"
            created="Unknown"
            if [ -f "$path/.task-info" ]; then
                task_name=$(grep "^# Task:" "$path/.task-info" 2>/dev/null | sed 's/# Task: //' || echo "Unknown")
                created=$(grep "^Created:" "$path/.task-info" 2>/dev/null | sed 's/Created: //' || echo "Unknown")
            fi

            # Get branch status
            status=$(get_branch_status "$branch")
            status_color="$YELLOW"
            status_text="$status"

            case "$status" in
                merged)
                    status_color="$GREEN"
                    status_text="✅ Merged to main"
                    ;;
                unmerged)
                    status_color="$YELLOW"
                    status_text="⚠️  Not merged"
                    ;;
                local-only)
                    status_color="$BLUE"
                    status_text="📍 Local only"
                    ;;
            esac

            # Get directory age
            age="Unknown"
            if [ -d "$path" ]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    created_timestamp=$(stat -f "%B" "$path" 2>/dev/null)
                else
                    # Linux
                    created_timestamp=$(stat -c "%W" "$path" 2>/dev/null)
                fi

                if [ -n "$created_timestamp" ] && [ "$created_timestamp" != "-" ]; then
                    current_timestamp=$(date +%s)
                    age_seconds=$((current_timestamp - created_timestamp))
                    age_days=$((age_seconds / 86400))
                    age="${age_days} days old"
                fi
            fi

            # Display worktree info
            echo -e "${CYAN}────────────────────────────────────${NC}"
            echo -e "${GREEN}📂 Task: $task_name${NC}"
            echo -e "   Branch: $branch"
            echo -e "   Status: ${status_color}${status_text}${NC}"
            echo -e "   Created: $created"
            echo -e "   Age: $age"
            echo -e "   Path: $path"

            # Ask for action
            echo ""
            read -p "Remove this worktree? (y/N/q to quit): " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Qq]$ ]]; then
                echo -e "${YELLOW}Cleanup cancelled${NC}"
                return
            elif [[ $REPLY =~ ^[Yy]$ ]]; then
                remove_worktree "$path" "$branch"
                echo ""
            fi
        fi
    done < <(git worktree list)

    if [ "$found_worktrees" = false ]; then
        echo -e "${GREEN}No worktrees to clean${NC}"
    else
        echo ""
        echo -e "${GREEN}✅ Cleanup complete${NC}"
    fi
}

# Function to clean all merged worktrees automatically
clean_merged() {
    echo -e "${CYAN}🧹 Cleaning Merged Worktrees${NC}"
    echo ""

    local cleaned=0

    while IFS= read -r line; do
        if [[ $line == *"lets-distill"* ]]; then
            path=$(echo "$line" | awk '{print $1}')
            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

            # Skip if path doesn't exist
            if [ ! -d "$path" ]; then
                git worktree prune
                continue
            fi

            # Check if branch is merged
            status=$(get_branch_status "$branch")

            if [ "$status" == "merged" ]; then
                echo -e "${GREEN}Removing merged worktree: $branch${NC}"
                git worktree remove "$path" --force 2>/dev/null || git worktree prune
                git branch -D "$branch" 2>/dev/null || true
                ((cleaned++))
            fi
        fi
    done < <(git worktree list)

    if [ $cleaned -eq 0 ]; then
        echo -e "${YELLOW}No merged worktrees to clean${NC}"
    else
        echo -e "${GREEN}✅ Cleaned $cleaned merged worktree(s)${NC}"
    fi
}

# Function to prune missing worktrees
prune_missing() {
    echo -e "${CYAN}🔧 Pruning missing worktrees...${NC}"
    git worktree prune
    echo -e "${GREEN}✅ Pruned missing worktrees${NC}"
}

# Main function
main() {
    # Ensure we're in the repo to run git commands
    cd "$REPO_BASE" 2>/dev/null || {
        echo -e "${RED}Error: Repository not found at $REPO_BASE${NC}"
        exit 1
    }

    if ! git worktree list > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        exit 1
    fi

    if [ $# -eq 0 ]; then
        # Interactive mode
        clean_interactive
    else
        case "$1" in
            --merged|-m)
                clean_merged
                ;;
            --prune|-p)
                prune_missing
                ;;
            --all|-a)
                echo -e "${RED}⚠️  This will remove ALL worktrees in $WORKTREE_BASE${NC}"
                read -p "Are you sure? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    while IFS= read -r line; do
                        if [[ $line == *"lets-distill"* ]]; then
                            path=$(echo "$line" | awk '{print $1}')
                            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
                            remove_worktree "$path" "$branch"
                        fi
                    done < <(git worktree list)
                fi
                ;;
            --help|-h)
                echo "Usage: distill-clean [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  (no args)    Interactive cleanup"
                echo "  --merged     Remove all merged worktrees"
                echo "  --prune      Prune missing worktrees"
                echo "  --all        Remove ALL worktrees (dangerous!)"
                echo "  --help       Show this help"
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use: distill-clean --help for options"
                exit 1
                ;;
        esac
    fi
}

main "$@"