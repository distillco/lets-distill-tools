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
WORKTREE_BASE="$LETS_DISTILL_WORKTREE_BASE"
HISTORY_FILE="$LETS_DISTILL_HISTORY_FILE"
REPO_BASE="$DISTILL_REPO_BASE"

# Function to display active worktrees
show_worktrees() {
    echo -e "${CYAN}🔍 Active Worktrees:${NC}"
    echo ""

    # Ensure we're in the repo to run git commands
    cd "$REPO_BASE" 2>/dev/null || {
        echo -e "${RED}Error: Repository not found at $REPO_BASE${NC}"
        exit 1
    }

    if ! git worktree list > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        exit 1
    fi

    # Clean up any orphaned worktrees first
    git worktree prune 2>/dev/null || true

    # Get worktrees that match our pattern
    while IFS= read -r line; do
        if [[ $line == *"lets-distill"* ]]; then
            path=$(echo "$line" | awk '{print $1}')
            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

            # Check if path exists
            if [ -d "$path" ]; then
                # Get task info if available
                if [ -f "$path/.task-info" ]; then
                    task_name=$(grep "^# Task:" "$path/.task-info" 2>/dev/null | sed 's/# Task: //' || echo "Unknown")
                    created=$(grep "^Created:" "$path/.task-info" 2>/dev/null | sed 's/Created: //' || echo "Unknown")

                    # Check if this is a PR review task
                    pr_title=$(grep "^- \*\*Title:\*\*" "$path/.task-info" 2>/dev/null | sed 's/^- \*\*Title:\*\* //' || echo "")
                    pr_status=$(grep "^- \*\*Status:\*\*" "$path/.task-info" 2>/dev/null | sed 's/^- \*\*Status:\*\* //' || echo "")
                    pr_number=$(grep "^- \*\*PR Number:\*\*" "$path/.task-info" 2>/dev/null | sed 's/^- \*\*PR Number:\*\* //' || echo "")
                    pr_url=$(grep "^- \*\*URL:\*\*" "$path/.task-info" 2>/dev/null | sed 's/^- \*\*URL:\*\* //' || echo "")

                    echo -e "${GREEN}📂 $task_name${NC}"
                    echo -e "   ${BLUE}Branch:${NC} $branch"
                    echo -e "   ${BLUE}Path:${NC} $path"
                    echo -e "   ${BLUE}Created:${NC} $created"

                    # Display PR info if available
                    if [ -n "$pr_title" ] && [ -n "$pr_number" ]; then
                        echo -e "   ${CYAN}PR:${NC} $pr_number - $pr_title"
                        if [ -n "$pr_status" ]; then
                            case "$pr_status" in
                                "OPEN")
                                    echo -e "   ${YELLOW}Status:${NC} 🟡 Open"
                                    ;;
                                "MERGED")
                                    echo -e "   ${GREEN}Status:${NC} ✅ Merged"
                                    ;;
                                "CLOSED")
                                    echo -e "   ${RED}Status:${NC} ❌ Closed"
                                    ;;
                                *)
                                    echo -e "   ${BLUE}Status:${NC} $pr_status"
                                    ;;
                            esac
                        fi
                        if [ -n "$pr_url" ]; then
                            echo -e "   ${BLUE}URL:${NC} $pr_url"
                        fi
                    fi
                else
                    echo -e "${GREEN}📂 $(basename "$path")${NC}"
                    echo -e "   ${BLUE}Branch:${NC} $branch"
                    echo -e "   ${BLUE}Path:${NC} $path"
                fi
                echo ""
            fi
        fi
    done < <(git worktree list)
}

# Function to show task history
show_history() {
    echo -e "${CYAN}📜 Task History:${NC}"
    echo ""

    if [ ! -f "$HISTORY_FILE" ]; then
        echo -e "${YELLOW}No task history found${NC}"
        return
    fi

    # Show last 20 entries, most recent first
    tail -20 "$HISTORY_FILE" | tac | while IFS= read -r line; do
        echo "  $line"
    done
}

# Function to switch to a worktree
switch_to() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: Please provide a task name or branch name${NC}"
        echo "Usage: distill-tasks switch <name>"
        return 1
    fi

    search_term="$1"
    found_path=""

    # Ensure we're in the repo to run git commands
    cd "$REPO_BASE" 2>/dev/null || {
        echo -e "${RED}Error: Repository not found at $REPO_BASE${NC}"
        return 1
    }

    # Search for matching worktree
    while IFS= read -r line; do
        if [[ $line == *"lets-distill"* ]]; then
            path=$(echo "$line" | awk '{print $1}')
            branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

            # Check if branch or path matches search term
            if [[ $branch == *"$search_term"* ]] || [[ $path == *"$search_term"* ]]; then
                found_path="$path"
                break
            fi

            # Check task info for match
            if [ -f "$path/.task-info" ]; then
                task_name=$(grep "^# Task:" "$path/.task-info" 2>/dev/null | sed 's/# Task: //' || echo "")
                if [[ $task_name == *"$search_term"* ]]; then
                    found_path="$path"
                    break
                fi
            fi
        fi
    done < <(git worktree list)

    if [ -n "$found_path" ]; then
        echo -e "${GREEN}Switching to: $found_path${NC}"
        echo "WORKTREE_DIR:$found_path"
        exit 0
    else
        echo -e "${RED}No worktree found matching: $search_term${NC}"
        return 1
    fi
}

# Main menu
main() {
    if [ $# -eq 0 ]; then
        # No arguments, show menu
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}      Distill Task Manager${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo ""
        show_worktrees
        echo -e "${CYAN}─────────────────────────────────────${NC}"
        echo ""
        echo -e "${YELLOW}Commands:${NC}"
        echo -e "  ${BLUE}distill-tasks list${NC}     - Show active worktrees"
        echo -e "  ${BLUE}distill-tasks history${NC}  - Show task history"
        echo -e "  ${BLUE}distill-tasks switch${NC}   - Switch to a worktree"
        echo -e "  ${BLUE}distill-tasks clean${NC}    - Clean up old worktrees"
        echo ""
        return
    fi

    case "$1" in
        list|ls)
            show_worktrees
            ;;
        history|hist)
            show_history
            ;;
        switch|sw)
            shift
            switch_to "$@"
            ;;
        clean)
            echo -e "${YELLOW}Use distill-clean.sh to remove old worktrees${NC}"
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo "Use: distill-tasks [list|history|switch|clean]"
            exit 1
            ;;
    esac
}

main "$@"