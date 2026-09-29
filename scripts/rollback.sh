#!/bin/sh
set -eu

PREVIOUS_TAG="${1:-${PREVIOUS_IMAGE_TAG:-}}"

if [ -z "${PREVIOUS_TAG}" ]; then
  echo "Usage: ./scripts/rollback.sh <previous-tag>"
  exit 1
fi

ansible-playbook \
  -i ansible/inventory/production.ini \
  ansible/playbooks/rollback.yml \
  -e "previous_tag=${PREVIOUS_TAG}"
