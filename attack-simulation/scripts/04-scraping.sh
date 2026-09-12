#!/usr/bin/env bash
#
# 04-scraping.sh
# Attack 4: Scraping and cost abuse
#
# Fires a large number of concurrent requests at GET /tasks to demonstrate
# the absence of rate limiting. On the hardened version, API Gateway
# throttling should start returning 429 Too Many Requests once the
# configured rate is exceeded.
#
# Usage:
#   ./04-scraping.sh [vulnerable|hardened] [request_count] [concurrency]
#
# Defaults: 5000 requests, 50 at a time.

set -uo pipefail

VERSION="${1:-vulnerable}"
COUNT="${2:-5000}"
CONCURRENCY="${3:-50}"

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
echo "Attack 4: Scraping and cost abuse"
echo "Target version : $VERSION"
echo "API endpoint   : $API"
echo "Requests       : $COUNT"
echo "Concurrency    : $CONCURRENCY"
echo "============================================================"
echo

read -p "This will send $COUNT requests to $API/tasks. Continue? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

echo
echo "Sending $COUNT requests, $CONCURRENCY at a time..."
START_TIME=$(date +%s)

seq "$COUNT" | xargs -P "$CONCURRENCY" -I{} curl -s -o /dev/null -w "%{http_code}\n" "$API/tasks" > /tmp/scraping_results.txt

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo
echo "Done in ${ELAPSED}s"
echo
echo "Status code breakdown:"
sort /tmp/scraping_results.txt | uniq -c | sort -rn

TOTAL_200=$(grep -c "^200$" /tmp/scraping_results.txt || true)
TOTAL_429=$(grep -c "^429$" /tmp/scraping_results.txt || true)

echo
if [ "$TOTAL_429" -gt 0 ]; then
    echo "RESULT: BLOCKED"
    echo "$TOTAL_429 requests were throttled with 429 Too Many Requests."
elif [ "$TOTAL_200" -eq "$COUNT" ]; then
    echo "RESULT: VULNERABLE"
    echo "All $COUNT requests succeeded with no throttling of any kind."
else
    echo "RESULT: MIXED"
    echo "Review the status code breakdown above."
fi
