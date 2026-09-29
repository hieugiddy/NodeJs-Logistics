#!/bin/sh
set -eu

: "${EC2_HOST:?EC2_HOST is required}"
: "${EC2_USER:?EC2_USER is required}"

ssh -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_HOST}" \
  "cd /opt/logistics-warehouse && docker compose exec -T core npm run migration:run"
