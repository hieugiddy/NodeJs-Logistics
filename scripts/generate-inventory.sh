#!/bin/sh
set -eu

: "${EC2_HOST:?EC2_HOST is required}"
: "${EC2_USER:?EC2_USER is required}"

cat > ansible/inventory/production.ini <<EOF
[app]
${EC2_HOST} ansible_user=${EC2_USER}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

cat ansible/inventory/production.ini
