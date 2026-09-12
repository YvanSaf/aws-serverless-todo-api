#!/usr/bin/env bash
#
# 02-injection.sh
# Attack 2: Stored XSS injection
#
# Demonstrates that a script tag submitted in a task title is accepted
# and stored as-is by the vulnerable version. On the hardened version
# the same payload should be rejected with 400 Bad Request by validator.py.
#
# Usage:
#   ./02-injection.sh [vulnerable|hardened]

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

PAYLOAD='<script>alert(document.cookie)</script>'

echo "============================================================"
echo "Attack 2: Stored XSS injection"
echo "Target version : $VERSION"
echo "API endpoint   : $API"
echo "Payload        : $PAYLOAD"
echo "============================================================"
echo

echo "[1/2] Sending POST /tasks with an unescaped script tag as the title..."
STATUS=$(curl -s -o /tmp/injection_result.json -w "%{http_code}" \
    -X POST "$API/tasks" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"${PAYLOAD}\",\"userId\":\"attacker-001\",\"description\":\"XSS test\"}")

echo "HTTP status: $STATUS"
echo
cat /tmp/injection_result.json
echo
echo

if [ "$STATUS" = "201" ]; then
    echo "[2/2] Task accepted, reading it back to confirm the payload is stored raw..."
    if command -v jq >/dev/null 2>&1; then
        TASK_ID=$(jq -r '.task.taskId' /tmp/injection_result.json)
    else
        TASK_ID=$(grep -o '"taskId": *"[^"]*"' /tmp/injection_result.json | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    fi
    curl -s "$API/tasks/${TASK_ID}"
    echo
    echo
    echo "RESULT: VULNERABLE"
    echo "The script tag was stored unescaped in DynamoDB and is returned"
    echo "as-is by the API. Any frontend rendering this field would execute it."
elif [ "$STATUS" = "400" ]; then
    echo "RESULT: BLOCKED"
    echo "The request was rejected before reaching DynamoDB, validator.py"
    echo "detected the disallowed characters."
else
    echo "RESULT: UNEXPECTED"
    echo "Received HTTP $STATUS, review the response above."
fi
