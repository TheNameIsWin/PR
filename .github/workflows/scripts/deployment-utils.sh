#!/bin/bash
set -euo pipefail

COMMAND="${1:-}"
[[ -z "$COMMAND" ]] && { echo "No command"; exit 1; }
shift

# ================================================
# 1) EXTRACT PR INFO (very basic)
# ================================================
if [[ "$COMMAND" == "extract-info" ]]; then
  GITHUB_REF_NAME="$1"
  GH_TOKEN="$2"
  GITHUB_REPOSITORY="$3"

  # PR detect from merge commit
  PR_NUM=""
  MSG=$(git log -1 --pretty=%B || true)

  if echo "$MSG" | grep -q "Merge pull request #[0-9]\+"; then
    PR_NUM=$(echo "$MSG" | grep -o "Merge pull request #[0-9]\+" | grep -o "[0-9]\+")
  else
    PR_NUM=$(git log -10 --pretty=%B | grep -o '#[0-9]\+' | grep -o '[0-9]\+' | head -1 || true)
  fi

  if [[ -z "$PR_NUM" ]]; then
    echo "info=No PR found" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  # Fetch PR JSON
  DATA=$(curl -s \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/$PR_NUM")

  TITLE=$(echo "$DATA" | jq -r '.title')
  BODY=$(echo "$DATA" | jq -r '.body // "No description"')

  INFO="*PR #$PR_NUM:* $TITLE\n*Description:* ${BODY:0:300}"

  DELIM="EOF_$(date +%s)"
  echo "info<<$DELIM" >> $GITHUB_OUTPUT
  echo -e "$INFO" >> $GITHUB_OUTPUT
  echo "$DELIM" >> $GITHUB_OUTPUT

  exit 0
fi

# ================================================
# 2) SEND SLACK NOTIFICATION (basic)
# ================================================
if [[ "$COMMAND" == "notify" ]]; then
  TEXT="$1"
  SLACK_WEBHOOK_URL="$2"

  curl -X POST \
    -H 'Content-type: application/json' \
    --data "{\"text\": \"${TEXT}\"}" \
    "$SLACK_WEBHOOK_URL"

  exit 0
fi

echo "Invalid command"
exit 1
