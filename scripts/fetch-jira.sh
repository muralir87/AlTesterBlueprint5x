#!/usr/bin/env bash
# Fetch Jira issues via the REST API.
#
# Required env vars:
#   JIRA_BASE_URL   e.g. https://your-company.atlassian.net
#   JIRA_EMAIL      Atlassian account email
#   JIRA_API_TOKEN  Atlassian API token
#
# Usage:
#   fetch-jira.sh ABC-123                 # fetch a single issue
#   fetch-jira.sh -j 'project = ABC'      # search by JQL
#   fetch-jira.sh -o out.json ABC-123     # write output to a file

set -euo pipefail

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

JQL=""
OUTPUT=""

while getopts "j:o:h" opt; do
  case "$opt" in
    j) JQL="$OPTARG" ;;
    o) OUTPUT="$OPTARG" ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done
shift $((OPTIND - 1))

for var in JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set." >&2
    exit 1
  fi
done

BASE_URL="${JIRA_BASE_URL%/}"

if [[ -n "$JQL" ]]; then
  URL="$BASE_URL/rest/api/3/search/jql"
  CURL_ARGS=(--get --data-urlencode "jql=$JQL" --data-urlencode "fields=*all")
elif [[ $# -ge 1 ]]; then
  URL="$BASE_URL/rest/api/3/issue/$1"
  CURL_ARGS=()
else
  usage 1
fi

# Token is passed via a config on stdin so it does not appear in the process list.
RESPONSE=$(printf 'user = "%s:%s"\n' "$JIRA_EMAIL" "$JIRA_API_TOKEN" |
  curl --silent --show-error --fail-with-body \
    --config - \
    --request GET \
    --header 'Accept: application/json' \
    "${CURL_ARGS[@]+"${CURL_ARGS[@]}"}" \
    "$URL")

if command -v jq >/dev/null 2>&1; then
  RESPONSE=$(printf '%s' "$RESPONSE" | jq .)
fi

if [[ -n "$OUTPUT" ]]; then
  printf '%s\n' "$RESPONSE" > "$OUTPUT"
  echo "Saved to $OUTPUT" >&2
else
  printf '%s\n' "$RESPONSE"
fi
