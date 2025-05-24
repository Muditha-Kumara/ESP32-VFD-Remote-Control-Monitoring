#!/bin/bash

# -----------------------------------------------------------------------------
# Script: create_github_issues.sh
# Purpose: Batch-create GitHub issues from tasks.txt and assign phase labels.
# Usage: ./create_github_issues.sh
# Requirements:
#   - GitHub CLI (gh) must be installed and authenticated.
#   - Run this script from the root of your repository.
#   - Ensure phase labels (e.g., "Phase 1") exist in your repository.
# -----------------------------------------------------------------------------

set -euo pipefail

PROJECT_NAME="ESP32 VFD Control"
TASKS_FILE="tasks.txt"

# Check for GitHub CLI
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is not installed. Please install it first."
  exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
  echo "Error: GitHub CLI is not authenticated. Run 'gh auth login' first."
  exit 1
fi

# Check tasks file exists
if [[ ! -f "$TASKS_FILE" ]]; then
  echo "Error: $TASKS_FILE not found in current directory."
  exit 1
fi

# Get repo owner/name (e.g., Muditha-Kumara/ESP32-VFD-Remote-Control-Monitoring)
REPO_FULL_NAME=$(gh repo view --json nameWithOwner -q .nameWithOwner)

echo "Creating GitHub issues from $TASKS_FILE..."

current_milestone=""
task_counter=1

while IFS= read -r task || [[ -n "$task" ]]; do
  # Skip empty lines
  [[ -z "$task" ]] && continue

  # Detect milestone header
  if [[ "$task" =~ ^#\ milestone:\ (.*)$ ]]; then
    milestone_line="${BASH_REMATCH[1]}"
    # Safely extract milestone title and time period using parameter expansion (no regex)
    if [[ "$milestone_line" == *"("*")" ]]; then
      milestone_title="${milestone_line%% (*}"
      milestone_time_period="${milestone_line##*\(}"
      milestone_time_period="${milestone_time_period%)}"
      milestone_desc="Time period: $milestone_time_period"
    else
      milestone_title="$milestone_line"
      milestone_desc="Auto-created milestone."
    fi
    current_milestone="$milestone_title"
    # Check if milestone exists, create if not
    milestone_id=$(gh api repos/$REPO_FULL_NAME/milestones --jq ".[] | select(.title==\"$milestone_title\") | .number")
    if [[ -z "$milestone_id" ]]; then
      echo "Milestone '$milestone_title' not found. Creating it..."
      gh api repos/$REPO_FULL_NAME/milestones -f title="$milestone_title" -f description="$milestone_desc"
    fi
    continue
  fi

  # Skip comments
  [[ "$task" =~ ^#.*$ ]] && continue

  # Create issue with milestone if set
  if [[ -n "$current_milestone" ]]; then
    echo "Creating issue: [$current_milestone] $task"
    gh issue create --title "Task $task_counter: $task" --milestone "$current_milestone" --body "Auto-generated task for milestone: $current_milestone."
  else
    echo "Creating issue: $task"
    gh issue create --title "Task $task_counter: $task" --body "Auto-generated task for project completion."
  fi
  task_counter=$((task_counter+1))
done < "$TASKS_FILE"

echo "All issues processed."
