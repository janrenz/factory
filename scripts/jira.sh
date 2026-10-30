#!/usr/bin/env bash
# Minimal Jira Cloud client for the jira flavour.
# Needs JIRA_BASE_URL (https://<site>.atlassian.net), JIRA_EMAIL, JIRA_API_TOKEN.
#   jira.sh get <KEY>                     → issue JSON (summary, description, labels, status)
#   jira.sh comment <KEY> <text>          → plain-text comment
#   jira.sh transition <KEY> <status>     → move to the status with that name
#   jira.sh label <KEY> <add|remove> <l>  → add or remove a label
set -euo pipefail
: "${JIRA_BASE_URL:?}" "${JIRA_EMAIL:?}" "${JIRA_API_TOKEN:?}"
api() { curl -fsS --retry 3 -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H 'Content-Type: application/json' -H 'Accept: application/json' "$@"; }
cmd=${1:?command}; key=${2:?issue key}
case "$cmd" in
  get) api "$JIRA_BASE_URL/rest/api/3/issue/$key?fields=summary,description,labels,status&expand=renderedFields" ;;
  comment)
    body=$(python3 -c 'import json,sys; t=sys.argv[1]; print(json.dumps({"body":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":l}]} for l in t.split("\n") if l.strip()]}}))' "${3:?text}")
    api -X POST "$JIRA_BASE_URL/rest/api/3/issue/$key/comment" -d "$body" >/dev/null ;;
  transition)
    id=$(api "$JIRA_BASE_URL/rest/api/3/issue/$key/transitions" | python3 -c 'import json,sys; want=sys.argv[1].lower(); print(next((t["id"] for t in json.load(sys.stdin)["transitions"] if t["to"]["name"].lower()==want or t["name"].lower()==want), ""))' "${3:?status}")
    [ -n "$id" ] || { echo "jira.sh: no transition to '$3' from the current status" >&2; exit 1; }
    api -X POST "$JIRA_BASE_URL/rest/api/3/issue/$key/transitions" -d "{\"transition\":{\"id\":\"$id\"}}" >/dev/null ;;
  label)
    op=${3:?add|remove}; l=${4:?label}
    api -X PUT "$JIRA_BASE_URL/rest/api/3/issue/$key" -d "{\"update\":{\"labels\":[{\"$op\":\"$l\"}]}}" >/dev/null ;;
  *) echo "jira.sh: unknown command $cmd" >&2; exit 2 ;;
esac
