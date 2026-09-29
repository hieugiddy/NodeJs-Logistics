# CI/CD Files — Quick Reference

## GitLab

| File | Responsibility |
|---|---|
| `.gitlab-ci.yml` | Pipeline entry point |
| `.gitlab/ci/quality.yml` | ESLint, Prettier, TypeScript |
| `.gitlab/ci/test.yml` | Unit + integration tests |
| `.gitlab/ci/security.yml` | Security checks |
| `.gitlab/ci/build.yml` | NestJS + Docker build/push |
| `.gitlab/ci/provision.yml` | CloudFormation |
| `.gitlab/ci/deploy.yml` | Ansible, migration, deploy |
| `.gitlab/ci/smoke.yml` | Smoke test |
| `.gitlab/ci/rollback.yml` | Rollback |

## AWS / CloudFormation

| File | Responsibility |
|---|---|
| `network.yml` | VPC + subnets + routes |
| `backend.yml` | EC2 + ECR + ALB |
| `database.yml` | RDS PostgreSQL |
| `redis.yml` | ElastiCache Redis |
| `rabbitmq.yml` | Amazon MQ RabbitMQ |

## Ansible

| File | Responsibility |
|---|---|
| `configure-server.yml` | Install/configure EC2 |
| `deploy.yml` | Pull images + start containers |
| `rollback.yml` | Deploy previous image |

## Scripts

| File | Responsibility |
|---|---|
| `migration.sh` | TypeORM migration |
| `smoke-test.sh` | `/health` verification |
| `rollback.sh` | Rollback helper |
| `generate-inventory.sh` | Generate Ansible inventory |
