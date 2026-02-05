#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Get directory name
dir_name=$(basename "$cwd")

# Get git branch if in a git repository
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || echo "detached")
  if [ -n "$git_branch" ]; then
    git_branch=" [git:$git_branch]"
  fi
fi

# Format context usage
context_info=""
if [ -n "$used_pct" ]; then
  context_info=$(printf " | Ctx: %.1f%%" "$used_pct")
fi

# Format token usage (convert to K for readability)
token_info=""
if [ "$input_tokens" != "0" ] || [ "$output_tokens" != "0" ]; then
  in_k=$(echo "scale=1; $input_tokens / 1000" | bc)
  out_k=$(echo "scale=1; $output_tokens / 1000" | bc)
  token_info=$(printf " | IN:%sK OUT:%sK" "$in_k" "$out_k")
fi

# Format cost
cost_info=""
if [ "$cost_usd" != "0" ] && [ "$cost_usd" != "null" ]; then
  cost_info=$(printf " | \$%.3f" "$cost_usd")
fi

# Output status line with colors
# Cyan: directory, Magenta: model, Yellow: tokens, Green: cost
printf "\033[36m%s\033[0m%s \033[35m| %s\033[0m%s\033[33m%s\033[0m\033[32m%s\033[0m" \
  "$dir_name" "$git_branch" "$model" "$context_info" "$token_info" "$cost_info"
