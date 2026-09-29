# 10-Day Backend Development Plan — Logistics Warehouse Management

> **Scope hiện tại:** Backend only.  
> **Frontend:** Angular sẽ triển khai ở phase sau, không nằm trong kế hoạch 10 ngày này.  
> **Mục tiêu:** Hoàn thiện Backend NestJS có Swagger, validation, authentication/authorization, Redis, PostgreSQL/TypeORM, RabbitMQ, Notification Service, testing, Docker, GitLab CI/CD và AWS deployment.

## 1. Backend Scope

### Core Service

- Auth
- Users / Admin
- Warehouses
- Warehouse Zones
- Products
- Inventory
- Inbound
- Outbound
- Dashboard

### Notification Service

- Notifications
- RabbitMQ Consumer

### Frontend

Angular **chưa code trong phase này**. Backend cần ổn định API contract để Angular phase sau tích hợp:

- REST API
- JSON response chuẩn
- HTTP status code
- Pagination
- Search / filter / sort
- JWT Bearer Authentication
- Role-based authorization
- Swagger/OpenAPI
- Error response chuẩn
- CORS

## 2. Technology Stack

### Core / Notification

- Node.js
- TypeScript
- NestJS
- TypeORM
- PostgreSQL
- Redis
- RabbitMQ
- JWT
- bcrypt / password hashing
- Swagger / OpenAPI
- class-validator
- class-transformer
- dotenv / NestJS Config
- ESLint
- Prettier
- Jest
- SuperTest

### DevOps

- Docker / Docker Compose
- Git / GitLab
- GitLab CI/CD
- AWS ECR
- AWS ECS/Fargate
- AWS RDS PostgreSQL
- AWS ElastiCache Redis
- Amazon MQ for RabbitMQ
- CloudWatch
- Secrets Manager
- Application Load Balancer

## 3. Architecture

```text
Angular (future)
      |
      v
 AWS ALB / API Gateway
      |
      +----------------------+
      |                      |
      v                      v
 Core Service          Notification Service
   NestJS                    NestJS
      |                      |
      +----+-----------+     |
           |           |     |
           v           v     v
       PostgreSQL    Redis  RabbitMQ
           |                 |
           |                 v
           |          Notification DB
           |
           +---- business data
```

## 4. Suggested Repository Structure

```text
logistics-warehouse/
├── core-service/
│   └── src/
│       ├── auth/
│       ├── users/
│       ├── warehouses/
│       ├── warehouse-zones/
│       ├── products/
│       ├── inventory/
│       ├── inbound/
│       ├── outbound/
│       ├── dashboard/
│       ├── common/
│       │   ├── decorators/
│       │   ├── guards/
│       │   ├── interceptors/
│       │   ├── filters/
│       │   └── pipes/
│       ├── config/
│       ├── database/
│       ├── redis/
│       ├── rabbitmq/
│       └── main.ts
│
└── notification-service/
    └── src/
        ├── notifications/
        ├── rabbitmq/
        ├── database/
        ├── common/
        ├── config/
        └── main.ts
```

# 5. 10-Day Plan

## Day 1 — Project Foundation

### Goal

Setup foundation cho cả 2 Backend services.

### Tasks

#### Core Service

- [ ] Initialize NestJS + TypeScript
- [ ] Config module
- [ ] `.env`
- [ ] `.env.example`
- [ ] `.gitignore`
- [ ] ESLint
- [ ] Prettier
- [ ] Global logging
- [ ] Global `ValidationPipe`
- [ ] CORS
- [ ] API prefix `/api`
- [ ] API version `/api/v1`
- [ ] Swagger
- [ ] Health check

#### Notification Service

- [ ] Initialize NestJS
- [ ] Config
- [ ] Validation
- [ ] ESLint
- [ ] Prettier
- [ ] Swagger
- [ ] Health check

### Swagger

```text
GET /api/docs
```

### Git

```text
main
└── develop
    ├── feature/auth
    ├── feature/product
    ├── feature/inventory
    └── feature/inbound
```

### Deliverable

Hai service chạy được local, Swagger hoạt động, lint/prettier hoạt động.

---

## Day 2 — PostgreSQL + TypeORM

### Goal

Hoàn thiện database layer.

### Core entities

- [ ] User
- [ ] Warehouse
- [ ] WarehouseZone
- [ ] Product
- [ ] Inventory
- [ ] InboundReceipt
- [ ] InboundReceiptItem
- [ ] OutboundOrder
- [ ] OutboundOrderItem
- [ ] InventoryTransaction

### Notification entities

- [ ] Notification

### Tasks

- [ ] TypeORM configuration
- [ ] Entities
- [ ] Relationships
- [ ] Foreign keys
- [ ] Unique constraints
- [ ] Indexes
- [ ] Enums
- [ ] Migrations
- [ ] Seed data
- [ ] Repository/query layer

### Important indexes

```text
users.email
products.sku
products.name
warehouses.code
inventory.product_id
inventory.warehouse_id
inbound_receipts.code
outbound_orders.code
notifications.user_id
```

### Deliverable

```bash
npm run migration:run
npm run seed
```

Database được tạo hoàn chỉnh từ migration.

---

## Day 3 — Authentication + Authorization

### Goal

Hoàn thiện security layer.

### APIs

```text
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
POST /api/v1/auth/logout-all
GET  /api/v1/auth/me
```

### Tasks

- [ ] Password hashing
- [ ] Login
- [ ] Access token
- [ ] Refresh token
- [ ] JWT strategy
- [ ] JWT guard
- [ ] Role guard
- [ ] Current user decorator
- [ ] Logout
- [ ] Logout all devices
- [ ] Token expiration
- [ ] Password validation
- [ ] Swagger Bearer authentication

### Roles

```text
SUPER_ADMIN
ADMIN
```

### Authorization

```text
SUPER_ADMIN
├── Manage Admin
├── Manage Warehouse
└── System management

ADMIN
├── Manage Warehouse
├── Manage Product
├── Manage Inventory
├── Manage Inbound
└── Manage Outbound
```

### Deliverable

Test được toàn bộ auth flow bằng Swagger, chưa cần Angular.

---

## Day 4 — Warehouse + Product

### Goal

Hoàn thiện CRUD business cơ bản.

### Warehouse

```text
POST   /warehouses
GET    /warehouses
GET    /warehouses/:id
PATCH  /warehouses/:id
DELETE /warehouses/:id
```

Features:

- Search
- Filter
- Sort
- Pagination

### Warehouse Zone

```text
POST   /warehouse-zones
GET    /warehouse-zones
GET    /warehouse-zones/:id
PATCH  /warehouse-zones/:id
DELETE /warehouse-zones/:id
```

### Product

```text
POST   /products
GET    /products
GET    /products/:id
PATCH  /products/:id
DELETE /products/:id
```

Product fields:

- SKU
- Name
- Description
- Unit
- Category
- Minimum stock
- Active/inactive

### Pagination

```http
GET /products?page=1&limit=20
```

Response:

```json
{
  "data": [],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### Tests

- [ ] Warehouse service
- [ ] Product service
- [ ] Controller integration
- [ ] Swagger

---

## Day 5 — Inventory + Redis

### Goal

Implement inventory và caching.

### APIs

```text
GET /inventory
GET /inventory/:id
GET /inventory/product/:productId
GET /inventory/warehouse/:warehouseId
```

### Inventory

- Stock quantity
- Reserved quantity
- Available quantity
- Minimum stock
- Low-stock detection

```text
available = quantity - reserved_quantity
```

### Redis

- [ ] Redis connection
- [ ] Cache service
- [ ] Cache-aside
- [ ] TTL
- [ ] Cache invalidation
- [ ] Cache key convention
- [ ] Rate limiter

Example keys:

```text
inventory:list:{query}
inventory:{id}
product:{id}
warehouse:{id}
```

### Read strategy

```text
API
 ↓
Redis
 ├── hit  → return
 └── miss → PostgreSQL → Redis SET → return
```

### Write strategy

```text
POST/PATCH/DELETE
 ↓
PostgreSQL
 ↓
Invalidate Redis
```

### Deliverable

Các read operation phù hợp sử dụng Redis cache và có TTL.

---

## Day 6 — Inbound + Outbound

### Goal

Implement nghiệp vụ kho chính.

### Inbound APIs

```text
POST /inbound-receipts
GET /inbound-receipts
GET /inbound-receipts/:id
PATCH /inbound-receipts/:id
POST /inbound-receipts/:id/complete
```

Flow:

```text
DRAFT
  ↓
RECEIVING
  ↓
COMPLETED
```

Khi complete:

```text
Inbound
 ↓
Inventory increase
 ↓
Inventory Transaction
 ↓
RabbitMQ event
```

### Outbound APIs

```text
POST /outbound-orders
GET /outbound-orders
GET /outbound-orders/:id
PATCH /outbound-orders/:id
POST /outbound-orders/:id/pick
POST /outbound-orders/:id/pack
POST /outbound-orders/:id/ship
```

Flow:

```text
CREATED
   ↓
PICKING
   ↓
PACKED
   ↓
SHIPPED
```

Khi ship:

```text
Outbound
 ↓
Inventory decrease
 ↓
Inventory Transaction
 ↓
RabbitMQ event
```

### Database transaction

```text
BEGIN
  Update receipt/order
  Update inventory
  Insert inventory transaction
COMMIT
```

Error:

```text
ROLLBACK
```

### Tests

- [ ] Complete inbound
- [ ] Pick outbound
- [ ] Pack outbound
- [ ] Ship outbound
- [ ] Inventory consistency
- [ ] Rollback

---

## Day 7 — CSV Import + RabbitMQ + Notification

### Goal

Hoàn thiện mass creation và event-driven notification.

### CSV

```text
POST /products/import
```

Content type:

```text
multipart/form-data
```

Validation:

- Required columns
- Data type
- Duplicate SKU
- Invalid rows
- Empty values

Response:

```json
{
  "total": 100,
  "success": 95,
  "failed": 5,
  "errors": []
}
```

### RabbitMQ events

```text
PRODUCT_CREATED
PRODUCT_IMPORTED
INBOUND_CREATED
INBOUND_COMPLETED
OUTBOUND_CREATED
OUTBOUND_SHIPPED
INVENTORY_LOW
```

Flow:

```text
Core business action
      ↓
Publish event
      ↓
RabbitMQ
      ↓
Notification consumer
      ↓
Notification DB
```

### Notification APIs

```text
GET /notifications
GET /notifications/:id
PATCH /notifications/:id/read
PATCH /notifications/read-all
```

### Deliverable

Demo được:

```text
Complete Inbound
 → RabbitMQ
 → Notification Service
 → Notification DB
 → GET /notifications
```

---

## Day 8 — Dashboard + Error Handling + Swagger Completion

### Dashboard

```text
GET /dashboard/summary
GET /dashboard/inventory
GET /dashboard/inbound
GET /dashboard/outbound
GET /dashboard/low-stock
```

Metrics:

- Total warehouses
- Total products
- Total inventory
- Low-stock products
- Pending inbound
- Pending outbound

### Global error handling

- [ ] Exception filter
- [ ] Business exception
- [ ] Validation error
- [ ] Not found
- [ ] Unauthorized
- [ ] Forbidden
- [ ] Conflict
- [ ] Database error
- [ ] RabbitMQ error

Standard response:

```json
{
  "success": false,
  "statusCode": 400,
  "message": "Validation failed",
  "error": "Bad Request",
  "timestamp": "2026-01-01T00:00:00.000Z",
  "path": "/api/v1/products"
}
```

### Swagger completion

Mỗi API có:

- [ ] Summary
- [ ] Description
- [ ] Tags
- [ ] Request body
- [ ] Params
- [ ] Query params
- [ ] Response schema
- [ ] Error responses
- [ ] Bearer auth

Tags:

```text
Auth
Users
Warehouses
Warehouse Zones
Products
Inventory
Inbound
Outbound
Dashboard
Notifications
```

---

## Day 9 — Testing + Docker

### Goal

Quality gate và local infrastructure.

### Unit tests

```text
AuthService
UserService
WarehouseService
WarehouseZoneService
ProductService
InventoryService
InboundService
OutboundService
NotificationService
```

### Integration / E2E flow

```text
Login
 ↓
Create Warehouse
 ↓
Create Product
 ↓
Create Inbound
 ↓
Complete Inbound
 ↓
Check Inventory
 ↓
Create Outbound
 ↓
Ship Outbound
 ↓
Check Inventory
```

### RabbitMQ test

```text
Publish event
 ↓
RabbitMQ
 ↓
Consumer
 ↓
Notification
```

### Quality commands

```bash
npm run lint
npm run format
npm run format:check
npm run test
npm run test:e2e
npm run build
```

### Docker

Create:

```text
Dockerfile
docker-compose.yml
.dockerignore
```

Local services:

```text
PostgreSQL
Redis
RabbitMQ
Core Service
Notification Service
```

Run:

```bash
docker compose up -d
```

---

## Day 10 — GitLab CI/CD + AWS

### Goal

CI/CD và deployment Backend.

### GitLab branches

```text
main
develop
feature/*
bugfix/*
hotfix/*
```

Flow:

```text
feature/*
   ↓
develop
   ↓
main
```

### Pipeline

```text
Install
   ↓
Lint
   ↓
Format Check
   ↓
Unit Test
   ↓
Integration Test
   ↓
Build
   ↓
Docker Build
   ↓
Push ECR
   ↓
Deploy AWS
```

Recommended stages:

```yaml
stages:
  - install
  - quality
  - test
  - build
  - docker
  - deploy
```

### Quality gate

Không deploy nếu:

```text
lint ❌
format ❌
test ❌
build ❌
docker build ❌
```

# 6. AWS Architecture

```text
                     Internet
                        │
                        ▼
                ┌───────────────┐
                │      ALB      │
                └───────┬───────┘
                        │
             ┌──────────┴──────────┐
             ▼                     ▼
       ┌───────────┐         ┌──────────────┐
       │ Core ECS  │         │ Notification │
       │ Fargate   │         │ ECS Fargate  │
       └─────┬─────┘         └──────┬───────┘
             │                      │
       ┌─────┼─────────────┐        │
       ▼     ▼             ▼        ▼
      RDS  Redis       Amazon MQ   RDS
      PG   Cache       RabbitMQ    PG
```

AWS services:

- ECS Fargate
- ECR
- RDS PostgreSQL
- ElastiCache Redis
- Amazon MQ RabbitMQ
- CloudWatch
- Secrets Manager
- Application Load Balancer

# 7. Environment Variables

## Core

```env
NODE_ENV=development
PORT=3000

DATABASE_HOST=
DATABASE_PORT=5432
DATABASE_NAME=
DATABASE_USER=
DATABASE_PASSWORD=

REDIS_HOST=
REDIS_PORT=6379
REDIS_PASSWORD=

RABBITMQ_URL=

JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
```

## Notification

```env
NODE_ENV=development
PORT=3001

DATABASE_HOST=
DATABASE_PORT=5432
DATABASE_NAME=
DATABASE_USER=
DATABASE_PASSWORD=

RABBITMQ_URL=
```

Không commit `.env`; chỉ commit `.env.example`.

# 8. Definition of Done — Mỗi API

Một API hoàn thành khi có:

- [ ] Entity nếu cần
- [ ] Migration nếu cần
- [ ] DTO
- [ ] Validation
- [ ] Controller
- [ ] Service
- [ ] Repository/query
- [ ] Authorization
- [ ] Error handling
- [ ] Swagger
- [ ] Unit test
- [ ] Integration test nếu cần
- [ ] Redis nếu cần caching
- [ ] RabbitMQ event nếu cần notification
- [ ] ESLint pass
- [ ] Prettier pass
- [ ] Build pass

# 9. API Checklist

## Authentication

- [ ] Login
- [ ] Refresh token
- [ ] Logout
- [ ] Logout all
- [ ] Current user

## User / Admin

- [ ] Create admin
- [ ] List admins
- [ ] Get admin
- [ ] Update admin
- [ ] Delete admin

## Warehouse

- [ ] Create
- [ ] List
- [ ] Detail
- [ ] Update
- [ ] Delete

## Warehouse Zone

- [ ] Create
- [ ] List
- [ ] Detail
- [ ] Update
- [ ] Delete

## Product

- [ ] Create
- [ ] List
- [ ] Detail
- [ ] Update
- [ ] Delete
- [ ] CSV import

## Inventory

- [ ] List
- [ ] Detail
- [ ] Product inventory
- [ ] Warehouse inventory
- [ ] Low stock

## Inbound

- [ ] Create
- [ ] List
- [ ] Detail
- [ ] Update
- [ ] Complete

## Outbound

- [ ] Create
- [ ] List
- [ ] Detail
- [ ] Update
- [ ] Pick
- [ ] Pack
- [ ] Ship

## Dashboard

- [ ] Summary
- [ ] Inventory
- [ ] Inbound
- [ ] Outbound
- [ ] Low stock

## Notification

- [ ] List
- [ ] Detail
- [ ] Mark read
- [ ] Mark all read

# 10. Final Backend Demo Flow

```text
1. Open Swagger
       ↓
2. Login
       ↓
3. Get JWT
       ↓
4. Authorize Swagger
       ↓
5. Create Warehouse
       ↓
6. Create Warehouse Zone
       ↓
7. Create Product
       ↓
8. Import Products CSV
       ↓
9. Create Inbound
       ↓
10. Complete Inbound
       ↓
11. Inventory increases
       ↓
12. RabbitMQ event
       ↓
13. Notification created
       ↓
14. Create Outbound
       ↓
15. Pick
       ↓
16. Pack
       ↓
17. Ship
       ↓
18. Inventory decreases
       ↓
19. RabbitMQ event
       ↓
20. Notification created
       ↓
21. Check Redis cache
       ↓
22. Run tests
       ↓
23. GitLab pipeline
       ↓
24. Docker build
       ↓
25. Deploy AWS
```

# 11. Angular — Phase 2

Angular **không nằm trong 10 ngày Backend**.

Sau khi Backend ổn định:

```text
Angular
   ↓
HttpClient
   ↓
REST API
   ↓
JWT
   ↓
Swagger API Contract
```

Các màn hình dự kiến:

```text
Login
Dashboard
Warehouse
Warehouse Zone
Product
Product Import
Inventory
Inventory Transactions
Inbound
Outbound
Admin
Notification
```

# 12. 10-Day Deliverables

| Day | Deliverable |
|---|---|
| 1 | NestJS + Config + Swagger + ESLint + Prettier |
| 2 | PostgreSQL + TypeORM + Entity + Migration + Seed |
| 3 | JWT + Refresh Token + RBAC + Logout |
| 4 | Warehouse + Zone + Product CRUD |
| 5 | Inventory + Redis + Rate Limit |
| 6 | Inbound + Outbound + Transactions |
| 7 | CSV Import + RabbitMQ + Notification |
| 8 | Dashboard + Error Handling + Complete Swagger |
| 9 | Unit Test + E2E + Docker Compose |
| 10 | GitLab CI/CD + AWS Deployment |

# 13. Priority

## P0 — Bắt buộc

```text
NestJS
PostgreSQL
TypeORM
CRUD
JWT
RBAC
Inventory
Inbound
Outbound
Swagger
```

## P1 — Theo assignment

```text
Redis
RabbitMQ
Notification Service
CSV Import
Jest / SuperTest
```

## P2 — DevOps

```text
Docker
GitLab CI/CD
AWS
```

## P3 — Frontend

```text
Angular
```

# 14. Final Backend Definition of Done

- [ ] 2 NestJS services chạy độc lập
- [ ] PostgreSQL hoạt động
- [ ] TypeORM migrations hoạt động
- [ ] CRUD hoàn chỉnh
- [ ] Search / filter / sort / pagination
- [ ] JWT authentication
- [ ] Access token + refresh token
- [ ] Role authorization
- [ ] Logout single device
- [ ] Logout all devices
- [ ] Redis caching
- [ ] TTL
- [ ] Rate limiter
- [ ] CSV mass import
- [ ] RabbitMQ
- [ ] Notification Service
- [ ] Notification database
- [ ] Global error handling
- [ ] Swagger đầy đủ
- [ ] ESLint pass
- [ ] Prettier pass
- [ ] Unit test pass
- [ ] Integration/E2E test pass
- [ ] Docker Compose chạy local
- [ ] GitLab CI pipeline pass
- [ ] Docker image build thành công
- [ ] AWS deployment thành công
- [ ] Angular có thể bắt đầu tích hợp dựa trên Swagger API contract

# 15. Daily Workflow

Mỗi ngày:

```text
Design
  ↓
Entity / DTO
  ↓
Service
  ↓
Controller
  ↓
Swagger
  ↓
Validation
  ↓
Authorization
  ↓
Test
  ↓
Lint
  ↓
Prettier
  ↓
Commit
  ↓
Push GitLab
```

## Commit convention

```text
feat: add product CRUD
feat: add inventory cache
feat: add inbound completion flow
feat: add rabbitmq notification consumer

fix: fix inventory transaction
fix: fix jwt refresh token

test: add product service tests

refactor: improve inventory repository

chore: configure eslint

ci: add gitlab pipeline

docs: update swagger documentation
```
