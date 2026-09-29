#!/bin/sh
set -eu

BASE_URL="${1:-${API_BASE_URL:-}}"

if [ -z "${BASE_URL}" ]; then
  echo "API base URL is required"
  exit 1
fi

echo "Smoke testing ${BASE_URL}/health"

status="$(curl -sS -o /tmp/health-response.txt -w '%{http_code}' "${BASE_URL}/health")"

cat /tmp/health-response.txt
echo

if [ "${status}" != "200" ]; then
  echo "Smoke test failed with HTTP ${status}"
  exit 1
fi

echo "Smoke test passed"
