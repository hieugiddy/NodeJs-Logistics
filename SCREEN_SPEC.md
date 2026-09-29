# Đặc tả màn hình & API — Quản lý kho Logistics

> Phạm vi: Core Business Service + Notification Service.  
> Stack theo assignment: NodeJS + TypeScript + NestJS + TypeORM + PostgreSQL/MySQL + Redis + RabbitMQ + JWT.  
> Assignment yêu cầu 2 backend service: core business và notification; CRUD, caching, JWT authorization và message broker. 

## 1. Quy ước chung

### 1.1 Core service
Base URL: `/api/v1`

### 1.2 Notification service
Base URL: `/api/v1/notifications`

### 1.3 Authentication
- `POST /auth/login`
- Access token: JWT, gửi qua `Authorization: Bearer <accessToken>`
- Refresh token dùng để cấp access token mới.
- Role: `SUPER_ADMIN`, `ADMIN`.
- Admin chỉ cập nhật/xóa dữ liệu do mình sở hữu theo rule của assignment; dữ liệu nghiệp vụ còn lại cho phép đọc/tạo, còn update/delete kiểm tra ownership. 

### 1.4 Response chuẩn

```json
{
  "success": true,
  "data": {},
  "message": "Success",
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 100
  }
}
```

### 1.5 Error chuẩn

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    { "field": "sku", "message": "SKU already exists" }
  ]
}
```

---

# 2. Sơ đồ chức năng

```text
Đăng nhập
   |
   +-- Dashboard
   |
   +-- Kho hàng
   |    +-- Danh sách kho
   |    +-- Khu vực kho
   |
   +-- Sản phẩm
   |    +-- Danh sách sản phẩm
   |    +-- Import CSV
   |
   +-- Tồn kho
   |    +-- Tra cứu tồn
   |    +-- Lịch sử biến động
   |
   +-- Nhập kho
   |    +-- Danh sách phiếu nhập
   |    +-- Tạo phiếu nhập
   |    +-- Hoàn tất nhập
   |
   +-- Xuất kho
   |    +-- Danh sách đơn xuất
   |    +-- Tạo đơn xuất
   |    +-- Picking / Packing / Shipping
   |
   +-- Người dùng
   |    +-- Quản lý Admin
   |    +-- Quản lý Super Admin
   |
   +-- Thông báo
```

---

# 3. Màn hình / đơn vị chức năng

## M01 — Đăng nhập

### Input
```json
{
  "email": "admin@warehouse.local",
  "password": "******"
}
```

### Output
```json
{
  "accessToken": "jwt...",
  "refreshToken": "jwt...",
  "user": {
    "id": "uuid",
    "email": "admin@warehouse.local",
    "role": "ADMIN"
  }
}
```

### API
`POST /auth/login`

### Logic API
1. Validate email/password.
2. Tìm user theo email.
3. So sánh password với `password_hash`.
4. Tạo access token + refresh token.
5. Lưu hash refresh token và expiry.
6. Trả token cho client.

### SQL
```sql
SELECT id, email, password_hash, full_name, role
FROM users
WHERE email = $1;

UPDATE users
SET refresh_token_hash = $2,
    refresh_token_expires_at = $3
WHERE id = $4;
```

---

## M02 — Dashboard

### Input
- `warehouseId`
- `from`
- `to`

### Output
- Tổng SKU
- Tổng tồn kho
- Số phiếu nhập đang xử lý
- Số đơn xuất đang xử lý
- Số mặt hàng dưới tồn tối thiểu
- Biến động nhập/xuất theo ngày

### API
`GET /dashboard?warehouseId=&from=&to=`

### Logic API
1. Validate query.
2. Lấy aggregate inventory.
3. Lấy số lượng inbound/outbound theo status.
4. Lấy sản phẩm dưới `min_stock`.
5. Cache dashboard bằng Redis, TTL ngắn vì dữ liệu có tần suất thay đổi cao.

### SQL
```sql
SELECT COUNT(DISTINCT product_id) AS sku_count,
       COALESCE(SUM(quantity), 0) AS total_quantity
FROM inventory
WHERE warehouse_id = $1;

SELECT COUNT(*)
FROM inbound_receipts
WHERE warehouse_id = $1
  AND status IN ('DRAFT', 'RECEIVING');

SELECT COUNT(*)
FROM outbound_orders
WHERE warehouse_id = $1
  AND status IN ('PENDING', 'PICKING', 'PACKING');
```

---

## M03 — Danh sách kho

### Input
Query:
`search`, `status`, `page`, `limit`, `sortBy`, `sortOrder`

### Output
Danh sách warehouse + pagination.

### API
- `GET /warehouses`
- `GET /warehouses/:id`
- `POST /warehouses`
- `PATCH /warehouses/:id`
- `DELETE /warehouses/:id`

### Logic API
1. Search theo code/name/address.
2. Filter status.
3. Sort + pagination.
4. Create kiểm tra code unique.
5. Update/delete kiểm tra quyền.

### SQL
```sql
SELECT w.*, u.full_name AS manager_name
FROM warehouses w
LEFT JOIN users u ON u.id = w.manager_id
WHERE ($1 IS NULL OR w.name ILIKE '%' || $1 || '%')
  AND ($2 IS NULL OR w.status = $2)
ORDER BY w.created_at DESC
LIMIT $3 OFFSET $4;
```

---

## M04 — Quản lý khu vực kho

### Input
```json
{
  "warehouseId": "uuid",
  "code": "A01",
  "name": "Kệ hàng A01",
  "zoneType": "STORAGE",
  "capacity": 1000
}
```

### Output
Zone object.

### API
- `GET /warehouses/:warehouseId/zones`
- `POST /warehouses/:warehouseId/zones`
- `PATCH /zones/:id`
- `DELETE /zones/:id`

### Logic API
- Zone phải thuộc warehouse tồn tại.
- `(warehouse_id, code)` unique.
- Không cho xóa zone nếu còn inventory.

### SQL
```sql
SELECT *
FROM warehouse_zones
WHERE warehouse_id = $1
ORDER BY code;

INSERT INTO warehouse_zones
(warehouse_id, code, name, zone_type, capacity)
VALUES ($1, $2, $3, $4, $5);
```

---

## M05 — Danh sách sản phẩm

### Input
Query:
`search`, `status`, `page`, `limit`, `sortBy`, `sortOrder`

### Output
```json
{
  "items": [
    {
      "id": "uuid",
      "sku": "SKU-001",
      "name": "Product A",
      "unit": "PCS",
      "minStock": 10
    }
  ]
}
```

### API
- `GET /products`
- `GET /products/:id`
- `POST /products`
- `PATCH /products/:id`
- `DELETE /products/:id`

### Logic API
- SKU unique.
- `maxStock >= minStock`.
- Chỉ owner được update/delete theo authorization rule.
- Create/update validate DTO.

### SQL
```sql
SELECT *
FROM products
WHERE ($1 IS NULL OR sku ILIKE '%' || $1 || '%' OR name ILIKE '%' || $1 || '%')
  AND ($2 IS NULL OR status = $2)
ORDER BY created_at DESC
LIMIT $3 OFFSET $4;

INSERT INTO products
(sku, name, unit, weight_kg, min_stock, max_stock, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7);
```

---

## M06 — Import sản phẩm CSV

### Input
Multipart form-data:
- `file`: CSV

CSV mẫu:
```csv
sku,name,unit,weight_kg,min_stock,max_stock
SKU-001,Product A,PCS,1.2,10,100
SKU-002,Product B,BOX,2.5,5,50
```

### Output
```json
{
  "total": 2,
  "success": 2,
  "failed": 0,
  "errors": []
}
```

### API
`POST /products/import`

### Logic API
1. Nhận multipart file.
2. Parse CSV.
3. Validate header.
4. Validate từng row.
5. Báo rõ row lỗi.
6. Insert nhiều record trong transaction.
7. Phát event `PRODUCT_IMPORTED`.

### SQL
```sql
INSERT INTO products
(sku, name, unit, weight_kg, min_stock, max_stock, created_by)
VALUES (...);
```

---

## M07 — Tra cứu tồn kho

### Input
Query:
`warehouseId`, `zoneId`, `productId`, `search`, `page`, `limit`

### Output
```json
{
  "items": [
    {
      "warehouseId": "uuid",
      "zoneId": "uuid",
      "productId": "uuid",
      "sku": "SKU-001",
      "productName": "Product A",
      "quantity": 100,
      "reservedQuantity": 20,
      "availableQuantity": 80
    }
  ]
}
```

### API
`GET /inventory`

### Logic API
- Join inventory + product + warehouse + zone.
- `available = quantity - reserved_quantity`.
- Cache các truy vấn đọc nhiều bằng Redis.
- Invalidate cache sau mutation inventory.

### SQL
```sql
SELECT i.id,
       i.warehouse_id,
       i.zone_id,
       i.product_id,
       p.sku,
       p.name AS product_name,
       i.quantity,
       i.reserved_quantity,
       (i.quantity - i.reserved_quantity) AS available_quantity
FROM inventory i
JOIN products p ON p.id = i.product_id
WHERE ($1 IS NULL OR i.warehouse_id = $1)
  AND ($2 IS NULL OR i.zone_id = $2)
  AND ($3 IS NULL OR i.product_id = $3)
ORDER BY p.sku
LIMIT $4 OFFSET $5;
```

---

## M08 — Lịch sử biến động tồn kho

### Input
`warehouseId`, `productId`, `transactionType`, `from`, `to`, `page`, `limit`

### Output
Danh sách transaction.

### API
`GET /inventory/transactions`

### Logic API
- Filter theo warehouse/product/type/date.
- Sort mới nhất trước.
- Chỉ đọc dữ liệu transaction, không sửa transaction cũ.

### SQL
```sql
SELECT it.*, p.sku, p.name AS product_name
FROM inventory_transactions it
JOIN products p ON p.id = it.product_id
WHERE ($1 IS NULL OR it.warehouse_id = $1)
  AND ($2 IS NULL OR it.product_id = $2)
  AND ($3 IS NULL OR it.transaction_type = $3)
  AND ($4 IS NULL OR it.created_at >= $4)
  AND ($5 IS NULL OR it.created_at < $5)
ORDER BY it.created_at DESC
LIMIT $6 OFFSET $7;
```

---

## M09 — Tạo phiếu nhập kho

### Input
```json
{
  "warehouseId": "uuid",
  "supplierName": "Supplier A",
  "items": [
    {
      "productId": "uuid",
      "zoneId": "uuid",
      "expectedQuantity": 100
    }
  ]
}
```

### Output
Phiếu nhập `DRAFT`.

### API
- `POST /inbound-receipts`
- `GET /inbound-receipts`
- `GET /inbound-receipts/:id`

### Logic API
1. Validate warehouse.
2. Validate product.
3. Validate zone thuộc warehouse.
4. Tạo receipt + items transaction.
5. Publish event RabbitMQ.

### SQL
```sql
INSERT INTO inbound_receipts
(receipt_no, warehouse_id, supplier_name, created_by)
VALUES ($1, $2, $3, $4)
RETURNING *;

INSERT INTO inbound_receipt_items
(receipt_id, product_id, zone_id, expected_quantity)
VALUES ($1, $2, $3, $4);
```

---

## M10 — Hoàn tất nhập kho

### Input
```json
{
  "receivedItems": [
    {
      "itemId": "uuid",
      "receivedQuantity": 95
    }
  ]
}
```

### Output
Receipt `COMPLETED`, inventory được cộng.

### API
`POST /inbound-receipts/:id/complete`

### Logic API
Transaction DB:
1. Lock receipt/items.
2. Validate trạng thái.
3. Update received quantity.
4. Upsert inventory.
5. Insert inventory transaction `INBOUND`.
6. Commit.
7. Publish RabbitMQ event sau khi transaction thành công.
8. Xóa/invalidate Redis inventory cache.

### SQL
```sql
UPDATE inbound_receipt_items
SET received_quantity = $1
WHERE id = $2;

INSERT INTO inventory
(warehouse_id, zone_id, product_id, quantity)
VALUES ($1, $2, $3, $4)
ON CONFLICT (warehouse_id, zone_id, product_id)
DO UPDATE SET quantity = inventory.quantity + EXCLUDED.quantity;

INSERT INTO inventory_transactions
(warehouse_id, zone_id, product_id, transaction_type,
 quantity, reference_type, reference_id, created_by)
VALUES ($1, $2, $3, 'INBOUND', $4, 'INBOUND_RECEIPT', $5, $6);

UPDATE inbound_receipts
SET status = 'COMPLETED', received_at = NOW()
WHERE id = $7;
```

---

## M11 — Tạo đơn xuất kho

### Input
```json
{
  "warehouseId": "uuid",
  "customerName": "Customer A",
  "customerPhone": "0900000000",
  "shippingAddress": "Ha Noi",
  "items": [
    {
      "productId": "uuid",
      "requestedQuantity": 5
    }
  ]
}
```

### Output
Đơn `PENDING`.

### API
- `POST /outbound-orders`
- `GET /outbound-orders`
- `GET /outbound-orders/:id`

### Logic API
- Validate product.
- Kiểm tra available stock.
- Reserve stock.
- Tạo order + items.
- Publish `OUTBOUND_CREATED`.

### SQL
```sql
INSERT INTO outbound_orders
(order_no, warehouse_id, customer_name, customer_phone,
 shipping_address, created_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

INSERT INTO outbound_order_items
(order_id, product_id, requested_quantity)
VALUES ($1, $2, $3);

UPDATE inventory
SET reserved_quantity = reserved_quantity + $1
WHERE warehouse_id = $2
  AND product_id = $3
  AND (quantity - reserved_quantity) >= $1;
```

---

## M12 — Picking / Packing / Shipping

### Input
- `orderId`
- Pick quantity / status transition.

### Output
Order với status mới.

### API
- `POST /outbound-orders/:id/pick`
- `POST /outbound-orders/:id/pack`
- `POST /outbound-orders/:id/ship`

### Logic API
#### Pick
- PENDING -> PICKING.
- Không được pick quá requested quantity.
- Ghi `picked_quantity`.

#### Pack
- PICKING -> PACKING.
- Chỉ cho phép khi picked đủ.

#### Ship
- PACKING -> SHIPPED.
- Trừ `quantity`.
- Giảm `reserved_quantity`.
- Ghi transaction `OUTBOUND`.
- Set `shipped_at`.
- Publish event.

### SQL
```sql
UPDATE outbound_order_items
SET picked_quantity = $1
WHERE id = $2;

UPDATE inventory
SET quantity = quantity - $1,
    reserved_quantity = reserved_quantity - $1
WHERE warehouse_id = $2
  AND product_id = $3
  AND quantity >= $1
  AND reserved_quantity >= $1;

INSERT INTO inventory_transactions
(warehouse_id, product_id, transaction_type, quantity,
 reference_type, reference_id, created_by)
VALUES ($1, $2, 'OUTBOUND', $3, 'OUTBOUND_ORDER', $4, $5);

UPDATE outbound_orders
SET status = 'SHIPPED', shipped_at = NOW()
WHERE id = $6;
```

---

## M13 — Quản lý Admin

### Input
```json
{
  "email": "admin2@example.com",
  "password": "******",
  "fullName": "Admin 2",
  "role": "ADMIN"
}
```

### API
- `GET /admins`
- `POST /admins` — chỉ SUPER_ADMIN
- `PATCH /admins/:id`
- `DELETE /admins/:id` — SUPER_ADMIN

### Logic API
- Admin không tạo admin khác.
- Admin chỉ xem/update thông tin của mình.
- SUPER_ADMIN được tạo và xóa ADMIN.
- Password luôn hash trước khi lưu.

### SQL
```sql
SELECT id, email, full_name, role
FROM users
WHERE role = 'ADMIN';

INSERT INTO users
(email, password_hash, full_name, role)
VALUES ($1, $2, $3, 'ADMIN');

DELETE FROM users
WHERE id = $1 AND role = 'ADMIN';
```

---

## M14 — Quản lý Super Admin

### API
- `POST /super-admins` — SUPER_ADMIN
- `PATCH /super-admins/:id` — chỉ chính user đó
- `GET /super-admins`

### Logic API
- SUPER_ADMIN có thể tạo SUPER_ADMIN mới.
- Không được delete SUPER_ADMIN.
- Chỉ owner được update thông tin của mình.

### SQL
```sql
INSERT INTO users
(email, password_hash, full_name, role)
VALUES ($1, $2, $3, 'SUPER_ADMIN');
```

---

## M15 — Logout

### API
- `POST /auth/logout`
- `POST /auth/logout-all`

### Logic API
- Logout single device: revoke refresh token/session hiện tại.
- Logout all: revoke toàn bộ session/token của user.
- Redis có thể dùng blacklist token tới khi token hết hạn.

### SQL
```sql
UPDATE users
SET refresh_token_hash = NULL,
    refresh_token_expires_at = NULL
WHERE id = $1;
```

---

# 4. Notification Service

Assignment yêu cầu notification service có DB riêng, nhận message từ RabbitMQ và lưu notification cho subscriber. fileciteturn0file0L213-L230

## N01 — Danh sách thông báo

### Input
`userId`, `status`, `page`, `limit`

### Output
Danh sách notification.

### API
`GET /notifications`

### Logic API
- Consumer ghi notification vào DB.
- API đọc notification theo user.
- Sort mới nhất.
- Có thể cache unread count bằng Redis.

### SQL
```sql
SELECT *
FROM notifications
WHERE user_id = $1
  AND ($2 IS NULL OR status = $2)
ORDER BY created_at DESC
LIMIT $3 OFFSET $4;
```

## N02 — Đánh dấu đã đọc

### API
`PATCH /notifications/:id/read`

### Logic API
- Kiểm tra notification thuộc user.
- `PENDING/SENT -> READ`.

### SQL
```sql
UPDATE notifications
SET status = 'READ'
WHERE id = $1
  AND user_id = $2;
```

## N03 — RabbitMQ consumer

### Message
```json
{
  "eventType": "INBOUND_COMPLETED",
  "actorUserId": "uuid",
  "warehouseId": "uuid",
  "referenceId": "uuid",
  "message": "Phiếu nhập đã hoàn tất"
}
```

### Logic
1. Consume queue.
2. Xác định subscriber.
3. Insert notification.
4. Có lỗi thì retry/dead-letter theo cấu hình RabbitMQ.

### SQL
```sql
INSERT INTO notifications
(user_id, event_type, title, message, channel, status, payload)
VALUES ($1, $2, $3, $4, 'IN_APP', 'PENDING', $5);
```

---

# 5. RabbitMQ Events

| Event | Producer | Consumer | Khi phát |
|---|---|---|---|
| `PRODUCT_CREATED` | Core | Notification | Tạo sản phẩm |
| `PRODUCT_IMPORTED` | Core | Notification | Import CSV |
| `INBOUND_CREATED` | Core | Notification | Tạo phiếu nhập |
| `INBOUND_COMPLETED` | Core | Notification | Hoàn tất nhập |
| `OUTBOUND_CREATED` | Core | Notification | Tạo đơn xuất |
| `OUTBOUND_SHIPPED` | Core | Notification | Xuất hàng |
| `INVENTORY_LOW` | Core | Notification | Tồn dưới min stock |

---

# 6. Redis Cache

## Key đề xuất

```text
dashboard:{warehouseId}:{from}:{to}
inventory:{warehouseId}:{zoneId}:{productId}:{page}:{limit}
product:{id}
warehouse:{id}
notification:unread:{userId}
```

## Cache strategy

- Read-heavy: cache-aside.
- Khi GET: Redis hit -> trả cache; miss -> SQL -> set cache.
- Khi create/update/delete liên quan dữ liệu: invalidate key.
- Dashboard/inventory TTL ngắn để giảm dữ liệu stale.
- Rate limiter theo user/IP.

Assignment yêu cầu cache các thao tác truy vấn tốn chi phí, TTL và rate limiter. fileciteturn0file0L154-L168

---

# 7. Authorization matrix

| Chức năng | ADMIN | SUPER_ADMIN |
|---|---:|---:|
| Đọc dữ liệu nghiệp vụ | Có | Có |
| Tạo dữ liệu nghiệp vụ | Có | Có |
| Update dữ liệu owned | Có | Có |
| Delete dữ liệu owned | Có | Có |
| Tạo ADMIN | Không | Có |
| Xóa ADMIN | Không | Có |
| Tạo SUPER_ADMIN | Có* | Có |
| Update SUPER_ADMIN | Chỉ bản thân | Chỉ bản thân |
| Delete SUPER_ADMIN | Không | Không |

`*` API thực tế nên giới hạn thao tác tạo SUPER_ADMIN theo rule authorization đã được thống nhất trong implementation.

---

# 8. Mapping Entity → API → SQL

| Entity | API chính | SQL chính |
|---|---|---|
| users | `/auth`, `/admins`, `/super-admins` | SELECT/INSERT/UPDATE/DELETE users |
| warehouses | `/warehouses` | CRUD warehouses |
| warehouse_zones | `/zones` | CRUD zones |
| products | `/products` | CRUD products |
| inventory | `/inventory` | SELECT/UPSERT inventory |
| inbound_receipts | `/inbound-receipts` | CRUD + transaction |
| inbound_receipt_items | nested inbound API | INSERT/UPDATE |
| outbound_orders | `/outbound-orders` | CRUD + reserve |
| outbound_order_items | nested outbound API | INSERT/UPDATE |
| inventory_transactions | `/inventory/transactions` | INSERT/SELECT |
| notifications | `/notifications` | INSERT/SELECT/UPDATE |

---

# 9. Transaction quan trọng

### Nhập kho

```text
BEGIN
  update inbound_receipt_items
  upsert inventory
  insert inventory_transaction
  update inbound_receipt
COMMIT
publish RabbitMQ event
invalidate Redis
```

### Xuất kho

```text
BEGIN
  validate available stock
  update reserved/quantity
  update outbound order
  insert inventory_transaction
COMMIT
publish RabbitMQ event
invalidate Redis
```

Không publish event trước khi transaction DB thành công để tránh notification cho một mutation đã rollback.

---

# 10. Cấu trúc project đề xuất

```text
logistics-warehouse/
├── core-service/
│   ├── src/
│   │   ├── auth/
│   │   ├── users/
│   │   ├── warehouses/
│   │   ├── products/
│   │   ├── inventory/
│   │   ├── inbound/
│   │   ├── outbound/
│   │   ├── dashboard/
│   │   ├── rabbitmq/
│   │   ├── redis/
│   │   └── common/
│   ├── .env
│   └── package.json
│
├── notification-service/
│   ├── src/
│   │   ├── notifications/
│   │   ├── rabbitmq/
│   │   ├── redis/
│   │   └── common/
│   ├── .env
│   └── package.json
│
├── database.sql
├── erd.png
└── README.md
```

---

# 11. Checklist đối chiếu assignment

- [x] Chọn topic logistics/warehouse.
- [x] README có title, description, schema design.
- [x] Core service.
- [x] Notification service.
- [x] CRUD.
- [x] Search/filter/sort/pagination.
- [x] CSV import.
- [x] PostgreSQL schema.
- [x] TypeORM mapping có thể triển khai từ schema.
- [x] Redis cache + TTL.
- [x] Rate limiter.
- [x] JWT authentication/authorization.
- [x] Role ADMIN/SUPER_ADMIN.
- [x] RabbitMQ event.
- [x] Notification DB.
- [x] Error handling và test có thể bổ sung ở phase implementation.

Các yêu cầu về CRUD/query, CSV, TypeORM, security, Redis, RabbitMQ và testing được lấy từ assignment gốc. fileciteturn0file0L130-L152 fileciteturn0file0L170-L180 fileciteturn0file0L182-L211 fileciteturn0file0L232-L244
