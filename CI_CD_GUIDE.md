# CI/CD Guide — Logistics Warehouse Backend

## 1. Mục tiêu

Bộ CI/CD này triển khai backend theo flow:

```text
GitLab
  -> CI/CD
  -> CloudFormation
  -> Ansible
  -> EC2 / Docker
  -> RDS PostgreSQL
  -> ElastiCache Redis
  -> Amazon MQ RabbitMQ
  -> Migration
  -> Deploy
  -> Smoke Test
  -> Rollback
```

Kiến trúc được thiết kế dựa trên tư duy deployment của UdaPeople đã tham khảo, nhưng chuyển orchestration sang GitLab CI/CD và tập trung vào 2 NestJS backend services.

### Kiến trúc hệ thống

```text
Developer -> GitLab CI/CD -> CloudFormation -> Ansible -> EC2 / Docker
                             |
            +----------------------------------+----------------+
            |                  |               |                |
            v                  v               v                v
         Core Service       Notification       RDS PostgreSQL   CloudWatch
            |              Service           (2 databases)
            +------------------+               Redis
                      |              Amazon MQ
                      +----------------+
```

- **Core Service** xử lý authentication/authorization, warehouse, zone, product, inventory, inbound, outbound, CSV import và publish RabbitMQ events.
- **Notification Service** consume RabbitMQ events, lưu notification vào database riêng và cung cấp API đọc/đánh dấu đã đọc.
- **AWS** gồm ALB, EC2, RDS PostgreSQL cho từng service, ElastiCache Redis, Amazon MQ, CloudFormation, CloudWatch và IAM.
- Provision infrastructure trước khi configure server; chạy migration thành công trước khi deploy ứng dụng.

---

## 2. Cấu trúc thư mục

```text
logistics-warehouse/
|
+-- .gitlab-ci.yml
+-- .gitlab/
|   +-- ci/
|       +-- quality.yml
|       +-- test.yml
|       +-- security.yml
|       +-- build.yml
|       +-- provision.yml
|       +-- deploy.yml
|       +-- smoke.yml
|       +-- rollback.yml
|
+-- apps/
|   +-- core/
|   |   +-- src/                    # NestJS modules, tests, Dockerfile
|   +-- notification/
|       +-- src/                    # NestJS API/consumer, tests, Dockerfile
|
+-- infra/
|   +-- cloudformation/
|       +-- network.yml
|       +-- backend.yml
|       +-- database.yml
|       +-- redis.yml
|       +-- rabbitmq.yml
|
+-- ansible/
|   +-- inventory/
|       +-- production.ini.example
|   +-- playbooks/
|       +-- configure-server.yml
|       +-- deploy.yml
|       +-- rollback.yml
|
+-- scripts/
|   +-- migration.sh
|   +-- smoke-test.sh
|   +-- rollback.sh
|
+-- docker-compose.prod.yml
+-- package.json
```

---

# 3. Prerequisites

Cài local:

- Git
- Node.js LTS
- Docker
- AWS CLI
- Ansible
- OpenSSH

AWS cần:

- AWS account
- IAM user/role có quyền deploy
- ECR
- CloudFormation
- EC2
- RDS
- ElastiCache
- Amazon MQ
- CloudWatch

GitLab cần:

- Repository
- GitLab Runner hoặc shared runner
- CI/CD Variables

---

# 4. GitLab CI/CD Variables

Tạo trong:

```text
GitLab
-> Settings
-> CI/CD
-> Variables
```

Tối thiểu:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION

AWS_ACCOUNT_ID

AWS_STACK_PREFIX

EC2_SSH_PRIVATE_KEY
EC2_HOST
EC2_USER
SSH_ALLOWED_CIDR
API_BASE_URL
PREVIOUS_IMAGE_TAG

DB_PASSWORD
JWT_SECRET
JWT_REFRESH_SECRET

REDIS_PASSWORD
RABBITMQ_PASSWORD

APP_ENV
```

Khuyến nghị:

- Mark secrets là `Masked`.
- Mark production secrets là `Protected`.
- Chỉ expose production secrets cho `main`.

> Production có thể nâng cấp từ static AWS credentials sang GitLab OIDC + AWS IAM role. Starter kit này dùng variables để dễ triển khai assignment trước.

---

# 5. Pipeline stages

```text
install
   |
quality
   |
test
   |
security
   |
build
   |
provision
   |
configure
   |
migration
   |
deploy
   |
smoke
   |
rollback
```

## Ý nghĩa

| Stage     | Mục đích                  |
| --------- | ---------------------------- |
| install   | Cài dependency              |
| quality   | ESLint, Prettier, TypeScript |
| test      | Jest, SuperTest              |
| security  | npm audit / security checks  |
| build     | NestJS + Docker              |
| provision | CloudFormation               |
| configure | Ansible + Docker             |
| migration | TypeORM migration            |
| deploy    | Pull/start containers        |
| smoke     | Health/API check             |
| rollback  | Quay về version trước     |

### Branch và môi trường triển khai

```text
feature/* -> Merge Request -> develop -> main -> Production
```

- `feature/*`: chạy install, quality, test, security và build; không deploy production.
- `develop`: chạy CI và có thể deploy môi trường development.
- `main`: chạy đầy đủ pipeline; production deployment chỉ dùng secrets được bảo vệ.
- Đặt Docker image tag theo commit SHA; không dùng `latest` làm version để rollback.

---

# 6. Local development

Chạy infrastructure local:

```bash
docker compose up -d
```

Kiểm tra:

```bash
docker compose ps
```

Chạy migration:

```bash
./scripts/migration.sh
```

Chạy smoke test:

```bash
./scripts/smoke-test.sh http://localhost:3000
```

---

# 7. CloudFormation

CloudFormation được tách thành:

```text
network.yml
backend.yml
database.yml
redis.yml
rabbitmq.yml
```

Thứ tự:

```text
network
   |
   +--> backend
   +--> database
   +--> redis
   +--> rabbitmq
```

Deploy local bằng AWS CLI:

```bash
aws cloudformation deploy \
  --stack-name logistics-network \
  --template-file infra/cloudformation/network.yml \
  --capabilities CAPABILITY_NAMED_IAM
```

Sau đó deploy các stack còn lại theo pipeline.

---

# 8. EC2 + Docker

Ansible configure EC2:

```bash
ansible-playbook \
  -i ansible/inventory/production.ini \
  ansible/playbooks/configure-server.yml
```

Các việc chính:

- Install Docker
- Login ECR
- Create application directory
- Copy docker-compose file
- Configure `.env`
- Start Docker services

---

# 9. Migration

Migration chạy trước deploy application:

```bash
./scripts/migration.sh
```

Trong production:

```text
Provision
    |
Configure
    |
Migration
    |
    +-- FAIL -> STOP
    |
    +-- PASS -> Deploy
```

Không dùng `synchronize: true` hoặc `dropSchema` cho production.

---

# 10. Deploy

Deploy:

```bash
ansible-playbook \
  -i ansible/inventory/production.ini \
  ansible/playbooks/deploy.yml
```

Flow:

```text
ECR
 |
 v
EC2
 |
 +-- docker login
 +-- docker compose pull
 +-- docker compose up -d
 +-- health check
```

Image tag nên là Git commit SHA:

```text
logistics-core:${CI_COMMIT_SHA}
logistics-notification:${CI_COMMIT_SHA}
```

---

# 11. Smoke Test

Health endpoint bắt buộc:

```http
GET /health
```

Ví dụ:

```bash
./scripts/smoke-test.sh https://api.example.com
```

Nếu không nhận `200`, pipeline fail.

---

# 12. Rollback

Rollback dùng version/image tag trước đó:

```bash
./scripts/rollback.sh <previous-tag>
```

Hoặc:

```bash
ansible-playbook \
  -i ansible/inventory/production.ini \
  ansible/playbooks/rollback.yml \
  -e previous_tag=<previous-tag>
```

Flow:

```text
Deploy new version
       |
Smoke test
       |
     FAIL
       |
Rollback
       |
Previous image
       |
Smoke test
```

Database migration rollback phải được thiết kế riêng cho từng migration. Không tự động rollback database nếu migration có destructive change.

### Cleanup

Pipeline có thể xóa temporary files, SSH configuration và deployment artifacts sau khi hoàn tất. Không tự động xóa production database, Redis data hoặc RabbitMQ configuration.

---

# 13. Failure policy

Các lỗi sau phải chặn deployment:

```text
ESLint FAIL
Prettier FAIL
TypeScript FAIL
Unit Test FAIL
Integration Test FAIL
Security FAIL
Build FAIL
CloudFormation FAIL
Migration FAIL
Deploy FAIL
Smoke Test FAIL
```

---

# 14. Production security

Không commit:

```text
.env
.env.production
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
DATABASE_PASSWORD
JWT_SECRET
RABBITMQ_PASSWORD
```

Production database không public Internet.

Security Group nên giới hạn:

```text
Internet -> ALB : 80/443
ALB -> EC2     : application port
EC2 -> RDS     : PostgreSQL 5432
EC2 -> Redis   : Redis port
EC2 -> MQ      : RabbitMQ port
```

SSH `22` chỉ mở từ IP quản trị hoặc thay bằng AWS Systems Manager.

Lưu secrets trong GitLab CI/CD Variables được `Masked`/`Protected` hoặc AWS Secrets Manager; không commit file `.env`. Có thể thay static AWS credentials bằng GitLab OIDC và AWS IAM role.

---

# 15. Assignment mapping

Architecture này hỗ trợ trực tiếp các yêu cầu assignment:

- ESLint
- Prettier
- Dotenv
- PostgreSQL
- TypeORM
- Redis caching
- JWT authentication
- RabbitMQ
- Notification service
- Jest
- SuperTest
- 2 backend services

Theo assignment, Redis được yêu cầu cho caching/rate limiting; TypeORM cho SQL persistence; JWT cho authorization; RabbitMQ cho notification service; Jest/SuperTest cho testing.

---

# 16. Recommended implementation order

### Step 1

Tạo GitLab repository.

### Step 2

Đưa source NestJS vào:

```text
apps/core
apps/notification
```

### Step 3

Chạy local:

```text
PostgreSQL
Redis
RabbitMQ
```

### Step 4

Hoàn thành:

```text
lint
test
build
Docker
```

### Step 5

Tạo AWS:

```text
network
RDS
Redis
RabbitMQ
EC2
```

### Step 6

Configure EC2 bằng Ansible.

### Step 7

Push Docker image vào ECR.

### Step 8

Run TypeORM migration.

### Step 9

Deploy Core + Notification.

### Step 10

Smoke test.

### Step 11

Test rollback.

---

# 17. Final deployment flow

```text
Developer
   |
   | git push
   v
GitLab
   |
   v
Install
   |
   v
Quality
   |
   v
Test
   |
   v
Security
   |
   v
Build
   |
   v
CloudFormation
   |
   v
AWS Infrastructure
   |
   v
Ansible
   |
   v
EC2 + Docker
   |
   v
TypeORM Migration
   |
   v
Deploy
   |
   v
Smoke Test
   |
   +---- PASS ----> Production
   |
   +---- FAIL ----> Rollback
```

---

# 18. Definition of Done

- [ ] GitLab pipeline chạy được.
- [ ] Lint PASS.
- [ ] Prettier PASS.
- [ ] TypeScript build PASS.
- [ ] Unit tests PASS.
- [ ] Integration tests PASS.
- [ ] Security checks PASS.
- [ ] Docker images build được.
- [ ] ECR push thành công.
- [ ] CloudFormation tạo/update infrastructure thành công.
- [ ] EC2 configure thành công.
- [ ] RDS hoạt động.
- [ ] Redis hoạt động.
- [ ] RabbitMQ hoạt động.
- [ ] TypeORM migration thành công.
- [ ] Core Service deploy thành công.
- [ ] Notification Service deploy thành công.
- [ ] `/health` trả `200`.
- [ ] Smoke test PASS.
- [ ] Docker image tag xác định bằng commit SHA.
- [ ] Rollback test thành công.
- [ ] CloudWatch có logs.

---

# 19. Important starter-kit notes

This package is intentionally a **deployment skeleton**, not a drop-in production environment.

Before the first AWS deployment:

1. Replace `ami-REPLACE_ME` in `infra/cloudformation/backend.yml` with an AMI valid for your AWS region.
2. Ensure the CloudFormation KeyPair exists and set `KeyName`.
3. Set `SSH_ALLOWED_CIDR` to the IP/CIDR of the runner/admin that can SSH to EC2. Do not leave `0.0.0.0/0` in production.
4. Set `EC2_HOST` after CloudFormation creates the instance.
5. Set `EC2_USER` (`ec2-user` for Amazon Linux).
6. Set `API_BASE_URL` to the ALB DNS name or your API domain.
7. Set `PREVIOUS_IMAGE_TAG` before enabling automatic rollback.
8. Ensure the EC2 host has AWS CLI available, or add an AWS CLI installation task to the Ansible role.
9. Ensure the GitLab Runner supports Docker-in-Docker if using the provided image build job.
10. Review IAM, security groups, encryption, backups and secret storage before production use.

For the 10-day assignment, this structure is intended to make the deployment flow understandable and demonstrable first; security hardening can then be tightened before production.

---

# 20. Assignment scope

Ưu tiên hoàn thành GitLab CI/CD, Docker, AWS, CloudFormation, Ansible, EC2, RDS PostgreSQL, Redis, RabbitMQ và CloudWatch trong phạm vi assignment 10 ngày. Chưa ưu tiên Kubernetes/EKS, Terraform, ArgoCD, Prometheus/Grafana, service mesh, multi-region hoặc blue/green deployment phức tạp.

Mục tiêu là chứng minh luồng end-to-end:

```text
Code -> Quality -> Test -> Build -> Infrastructure -> Configure
   -> Migration -> Deploy -> Smoke Test -> Rollback
```
