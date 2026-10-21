# Factory Management System — MVP Implementation Blueprint

## 1. Product Objective

Build a simple, mobile-first factory management system for managing:

- Raw material purchases
- Supplier payments and outstanding balances
- Customers
- Customer credit and receivables
- Orders
- Invoices
- Weekly/monthly/custom installment schedules
- Customer payments
- Raw material inventory
- Finished goods
- Production
- Expenses
- Dispatches
- Reports
- Notifications
- Documents
- Audit history

The application must be extremely simple for a non-technical factory owner.

The system must also be designed from day one for:

- Multi-tenancy
- Future multiple users
- Future multiple organizations
- Future white-labeling
- Mobile/PWA usage
- Strong financial and inventory data integrity

---

# 2. Technology Stack

Use the following stack unless there is a strong technical reason not to.

### Frontend

- Next.js
- TypeScript
- Responsive mobile-first UI
- PWA
- Tailwind CSS
- Reusable component library
- React Hook Form
- Zod validation
- TanStack Query

### Backend

- Node.js
- TypeScript
- Express.js
- REST APIs
- Zod request/response validation
- OpenAPI specification

### Database

- PostgreSQL
- Prisma ORM

### Storage

- AWS S3

### Deployment

- AWS

Recommended infrastructure:

- ECS/Fargate for API
- ECS/Fargate or AWS-compatible Next.js hosting for frontend
- RDS PostgreSQL
- S3 for documents
- CloudFront
- Application Load Balancer
- AWS Secrets Manager
- CloudWatch
- AWS SES later for email notifications

### Repository Structure

Use a monorepo.

```text
/apps
  /web
  /api

/packages
  /db
  /types
  /validation
  /ui
  /config
  /utils
```

Keep shared DTOs, enums, validation schemas, and common types inside `/packages`.

---

# 3. Core Architectural Principles

The implementation must follow these principles.

### 3.1 Never design only for the current single user

V1 has:

- 1 Tenant
- 1 Organization
- 1 User

But the database must support:

```text
Tenant
 ├── Organization A
 │    ├── User A
 │    ├── User B
 │
 └── Organization B
      ├── User A
      └── User C
```

Do not hardcode assumptions that one user equals one organization.

---

# 4. Multi-Tenant Architecture

## Tenant

Tenant represents the account and future white-label boundary.

Examples:

```text
Tenant: Khan Manufacturing Account
Tenant: ABC Manufacturing Group
```

Tenant owns:

- Subscription/account configuration
- Branding
- Theme
- White-label settings
- Organizations
- Memberships

## Organization

Organization represents an actual company/factory.

Example:

```text
Tenant:
Khan Manufacturing

Organization:
Khan Textile Factory
```

In V1 there will be exactly one organization for each tenant.

---

# 5. User Onboarding

The first-time experience must be extremely short.

User enters:

```text
Your Name
Email
Password
Company Name
```

System automatically creates:

```text
User
Tenant
Organization
Owner Membership
Organization Settings
Default Warehouse
Default numbering sequences
Default roles
Default units
```

Then redirect directly to Dashboard.

Do not ask users to configure complicated settings during onboarding.

Configuration can happen later.

---

# 6. Data Ownership Rules

Three levels of data should exist.

## Platform-Level

Shared across the whole software.

Examples:

- Standard unit definitions
- Countries
- Supported currencies
- Permission definitions

---

## Tenant-Level

Examples:

- Branding
- Subscription
- White-label configuration
- Tenant-wide user management

---

## Organization-Level

Almost all factory data belongs here.

Examples:

- Suppliers
- Customers
- Raw materials
- Products
- Orders
- Purchases
- Payments
- Inventory
- Production
- Expenses
- Invoices
- Reports

Every organization-owned record must contain:

```text
tenantId
organizationId
```

Never query organization data without tenant and organization scope.

---

# 7. Database Design Rules

Before creating APIs or frontend screens, complete and review the database schema.

Use:

```text
UUID
```

for primary keys.

Every normal table should contain:

```text
id
tenantId
organizationId where applicable
createdAt
updatedAt
createdBy where applicable
updatedBy where applicable
```

Use:

```text
TIMESTAMPTZ
```

for timestamps.

Money:

```text
DECIMAL(18,2)
```

Quantities:

```text
DECIMAL(18,4)
```

Never use floating-point numbers for money.

Currency:

```text
currencyCode CHAR(3)
```

Examples:

```text
PKR
USD
GBP
```

---

# 8. Delete Strategy

Master records can use soft deletion.

Examples:

- Customer
- Supplier
- Product
- Raw material

Use:

```text
deletedAt
```

Financial transactions must never simply be deleted.

Examples:

- Invoice
- Payment
- Purchase
- Goods receipt
- Stock transaction

Use:

```text
VOID
CANCELLED
REVERSED
```

with:

```text
voidedAt
voidedBy
voidReason
```

Where necessary create reversal transactions.

---

# 9. Core Database Schema

## Identity and Tenancy

### User

```text
id
name
email
passwordHash
status
lastLoginAt
createdAt
updatedAt
```

### Tenant

```text
id
name
slug
status
createdAt
updatedAt
```

### TenantBranding

```text
id
tenantId
applicationName
logoUrl
faviconUrl
primaryTheme
customDomain
createdAt
updatedAt
```

Keep the schema ready for white-label configuration.

---

### Organization

```text
id
tenantId
name
legalName
phone
email
address
city
country
currencyCode
timezone
taxNumber
status
createdAt
updatedAt
```

---

### Membership

```text
id
tenantId
organizationId
userId
roleId
status
createdAt
updatedAt
```

Unique constraint:

```text
organizationId + userId
```

---

### Role

Default roles:

```text
OWNER
ADMIN
ACCOUNTS
SALES
PRODUCTION
WAREHOUSE
VIEWER
```

---

### Permission

Examples:

```text
customer.read
customer.write

supplier.read
supplier.write

purchase.read
purchase.write

invoice.read
invoice.write

payment.read
payment.write

inventory.read
inventory.write

report.read
```

Use role-permission mappings rather than hardcoding permission checks inside controllers.

---

# 10. Organization Settings

Create:

### OrganizationSettings

Store:

```text
organizationId

invoicePrefix
orderPrefix
purchasePrefix
paymentPrefix
productionPrefix

defaultCurrency
defaultPaymentTermsDays

invoiceFooter
invoiceNotes

lowStockNotificationsEnabled
paymentReminderEnabled
```

---

# 11. Document Number Sequences

Never generate invoice/order numbers using record count.

Create:

### NumberSequence

```text
id
tenantId
organizationId
type
prefix
currentNumber
padding
```

Examples:

```text
INV-000001
ORD-000001
PUR-000001
PAY-000001
PROD-000001
```

Update sequence inside a database transaction.

---

# 12. Supplier Module

### Supplier

```text
id
tenantId
organizationId

name
companyName
contactPerson
phone
email
address
taxNumber

paymentTermsDays
openingBalance

notes
status

createdAt
updatedAt
deletedAt
```

Supplier must support:

- Purchase history
- Outstanding balance
- Payments
- Documents
- Ledger

---

# 13. Customer Module

### Customer

```text
id
tenantId
organizationId

name
companyName
contactPerson
phone
email
billingAddress
shippingAddress

taxNumber

creditLimit
paymentTermsDays
openingBalance

notes
status

createdAt
updatedAt
deletedAt
```

The system should calculate:

```text
Outstanding Receivable
Available Credit
Overdue Amount
```

Do not store calculated values unnecessarily if they can safely be derived.

---

# 14. Units of Measurement

### Unit

Examples:

```text
KG
GRAM
LITER
METER
PIECE
BOX
BAG
ROLL
```

Allow organization-specific units later.

---

# 15. Raw Materials

### RawMaterial

```text
id
tenantId
organizationId

name
sku
description

unitId

minimumStockLevel
reorderLevel

standardCost
lastPurchaseCost

status

createdAt
updatedAt
deletedAt
```

---

# 16. Finished Products

### Product

```text
id
tenantId
organizationId

name
sku
description

unitId

sellingPrice
standardCost

minimumStockLevel

status

createdAt
updatedAt
deletedAt
```

---

# 17. Warehouses

### Warehouse

```text
id
tenantId
organizationId

name
code
address
isDefault
status
```

Create one automatically:

```text
Main Warehouse
```

during onboarding.

---

# 18. Purchase Orders

### PurchaseOrder

```text
id
tenantId
organizationId

purchaseOrderNumber
supplierId

orderDate
expectedDeliveryDate

status

subtotal
discount
tax
total

notes

createdBy
createdAt
updatedAt
```

Statuses:

```text
DRAFT
CONFIRMED
PARTIALLY_RECEIVED
RECEIVED
CANCELLED
```

---

### PurchaseOrderItem

```text
id
purchaseOrderId
rawMaterialId

quantity
unitPrice

discount
tax
lineTotal
```

---

# 19. Goods Receiving

Do not assume purchasing something means it has physically arrived.

### GoodsReceipt

```text
id
tenantId
organizationId

receiptNumber
purchaseOrderId
supplierId
warehouseId

receivedDate
status

notes
```

### GoodsReceiptItem

```text
id
goodsReceiptId
purchaseOrderItemId
rawMaterialId

quantityReceived
```

Posting a goods receipt must create inventory movements.

---

# 20. Supplier Purchases / Supplier Invoices

### SupplierInvoice

```text
id
tenantId
organizationId

supplierInvoiceNumber
internalReference

supplierId
purchaseOrderId

invoiceDate
dueDate

status

subtotal
discount
tax
total

paidAmount
balanceAmount

notes
```

Statuses:

```text
DRAFT
UNPAID
PARTIALLY_PAID
PAID
OVERDUE
VOID
```

---

### SupplierInvoiceItem

```text
id
supplierInvoiceId

rawMaterialId
description

quantity
unitPrice
discount
tax
lineTotal
```

---

# 21. Supplier Payments

### SupplierPayment

```text
id
tenantId
organizationId

paymentNumber
supplierId

paymentDate
amount

paymentMethod
referenceNumber

notes

status
```

Payment methods:

```text
CASH
BANK_TRANSFER
CHEQUE
OTHER
```

---

### SupplierPaymentAllocation

One payment may pay multiple invoices.

```text
id
supplierPaymentId
supplierInvoiceId
amount
```

Example:

```text
Payment: 500,000

Invoice A: 200,000
Invoice B: 300,000
```

---

# 22. Sales Orders

### SalesOrder

```text
id
tenantId
organizationId

orderNumber
customerId

orderDate
expectedDeliveryDate

status

subtotal
discount
tax
total

notes
```

Statuses:

```text
DRAFT
CONFIRMED
IN_PRODUCTION
READY
PARTIALLY_DISPATCHED
DISPATCHED
DELIVERED
COMPLETED
CANCELLED
```

---

### SalesOrderItem

```text
id
salesOrderId
productId

quantity
unitPrice

discount
tax
lineTotal
```

---

# 23. Customer Invoices

### SalesInvoice

```text
id
tenantId
organizationId

invoiceNumber

customerId
salesOrderId

invoiceDate
dueDate

status

subtotal
discount
tax
total

paidAmount
balanceAmount

notes
```

Statuses:

```text
DRAFT
UNPAID
PARTIALLY_PAID
PAID
OVERDUE
VOID
```

---

### SalesInvoiceItem

```text
id
salesInvoiceId

productId
description

quantity
unitPrice
discount
tax
lineTotal
```

Allow:

```text
One order → multiple invoices
```

---

# 24. Invoice Payment Schedules

Payment schedules are expectations, not actual payments.

### PaymentSchedule

```text
id
tenantId
organizationId

salesInvoiceId

scheduleType
numberOfInstallments

startDate
status
```

Types:

```text
WEEKLY
MONTHLY
CUSTOM
```

---

### PaymentInstallment

```text
id
paymentScheduleId

installmentNumber

dueDate
amount

status
```

Statuses:

```text
UPCOMING
DUE
PARTIALLY_PAID
PAID
OVERDUE
```

Allow users to manually modify installment amounts and dates.

Ensure:

```text
sum(installments) = invoice total
```

or invoice balance when creating a schedule after an initial payment.

---

# 25. Customer Payments

### CustomerPayment

```text
id
tenantId
organizationId

paymentNumber
customerId

paymentDate
amount

paymentMethod
referenceNumber

notes
status
```

---

### CustomerPaymentAllocation

```text
id
customerPaymentId
salesInvoiceId
paymentInstallmentId nullable
amount
```

One payment can be allocated across multiple invoices.

---

# 26. Inventory Architecture

Inventory must use an immutable stock movement ledger.

Never simply update:

```text
rawMaterial.quantity = 500
```

without recording why it changed.

Create:

### InventoryMovement

```text
id
tenantId
organizationId

warehouseId

itemType
rawMaterialId nullable
productId nullable

movementType

quantity
unitCost

referenceType
referenceId

movementDate

notes
createdBy
createdAt
```

Movement types:

```text
PURCHASE_RECEIPT
PRODUCTION_CONSUMPTION
PRODUCTION_OUTPUT
SALE_DISPATCH
RETURN_IN
RETURN_OUT
ADJUSTMENT_IN
ADJUSTMENT_OUT
TRANSFER_IN
TRANSFER_OUT
```

Current stock should be calculated from movements or maintained through a transactional inventory balance table.

---

### InventoryBalance

For fast reads:

```text
tenantId
organizationId
warehouseId

itemType
rawMaterialId/productId

quantityOnHand
quantityReserved
quantityAvailable

updatedAt
```

Update movement + balance in the same DB transaction.

---

# 27. Bill of Materials

### BillOfMaterial

```text
id
tenantId
organizationId

productId
version
status

effectiveFrom
```

### BillOfMaterialItem

```text
id
billOfMaterialId
rawMaterialId

quantityRequired
wastagePercentage
```

Example:

```text
Product A

2 KG Material X
0.5 KG Material Y
1 Piece Packaging
```

---

# 28. Production

### ProductionOrder

```text
id
tenantId
organizationId

productionNumber
productId
warehouseId

plannedQuantity
actualQuantity

plannedStartDate
plannedEndDate

actualStartDate
actualEndDate

status

notes
```

Statuses:

```text
DRAFT
PLANNED
IN_PROGRESS
COMPLETED
CANCELLED
```

---

### ProductionMaterialConsumption

```text
id
productionOrderId
rawMaterialId

plannedQuantity
actualQuantity
```

---

### ProductionOutput

```text
id
productionOrderId
productId

quantityProduced
quantityRejected
```

When production completes:

```text
Raw material stock decreases
Finished goods stock increases
```

Create inventory movements automatically.

---

# 29. Expense Management

### ExpenseCategory

Examples:

```text
Electricity
Gas
Labour
Transport
Rent
Packaging
Maintenance
Machine Repair
Miscellaneous
```

### Expense

```text
id
tenantId
organizationId

categoryId

expenseDate
description

amount
paymentMethod

supplierId nullable

referenceNumber
notes
status
```

---

# 30. Dispatch Management

### Dispatch

```text
id
tenantId
organizationId

dispatchNumber

salesOrderId
customerId
warehouseId

dispatchDate

driverName
vehicleNumber
trackingReference

status
notes
```

---

### DispatchItem

```text
id
dispatchId
salesOrderItemId
productId

quantity
```

Posting dispatch should decrease finished goods inventory.

---

# 31. Documents

### Attachment

```text
id
tenantId
organizationId

entityType
entityId

fileName
fileUrl
mimeType
fileSize

uploadedBy
uploadedAt
```

Support attachments for:

```text
Supplier
Customer
Purchase Order
Supplier Invoice
Payment
Sales Order
Sales Invoice
Dispatch
Production Order
Expense
```

Generate S3 pre-signed upload URLs.

---

# 32. Audit Log

Audit logging is mandatory.

### AuditLog

```text
id
tenantId
organizationId

userId

entityType
entityId

action

oldValues JSONB
newValues JSONB

ipAddress
userAgent

createdAt
```

Actions:

```text
CREATE
UPDATE
VOID
CANCEL
PAYMENT
STATUS_CHANGE
DELETE_MASTER_RECORD
```

Audit history must not be editable through normal APIs.

---

# 33. Notifications

### Notification

```text
id
tenantId
organizationId
userId

type
title
message

entityType
entityId

isRead
createdAt
```

Initial notifications:

```text
Customer payment overdue
Supplier payment due
Customer installment due
Low raw-material stock
Order delivery approaching
```

V1 can use in-app notifications.

Email and WhatsApp can be added later.

---

# 34. Financial Source-of-Truth Rules

These rules are extremely important.

### Receivables

Customer receivable originates from:

```text
Sales Invoice
```

not Sales Order.

Formula:

```text
Invoice Total
- Valid Payment Allocations
= Outstanding Receivable
```

---

### Payables

Supplier payable originates from:

```text
Supplier Invoice
```

not Purchase Order.

Formula:

```text
Supplier Invoice Total
- Valid Supplier Payment Allocations
= Outstanding Payable
```

---

### Installments

Installments must NOT create additional receivable.

They only divide an existing receivable into scheduled dates.

---

# 35. Customer Ledger

Generate customer ledger from:

```text
Opening Balance
Invoices
Payments
Credit Adjustments
```

Display:

```text
Date
Reference
Description
Debit
Credit
Running Balance
```

---

# 36. Supplier Ledger

Generate supplier ledger from:

```text
Opening Balance
Supplier Invoices
Supplier Payments
Adjustments
```

---

# 37. Database Indexing

Create indexes at minimum on:

```text
tenantId
organizationId

tenantId + organizationId

customerId
supplierId

invoiceDate
dueDate

status

createdAt

sku

invoiceNumber
orderNumber
purchaseOrderNumber
```

Frequently queried multi-tenant tables should use composite indexes such as:

```text
organizationId + status
organizationId + createdAt
organizationId + customerId
organizationId + supplierId
```

---

# 38. Uniqueness Rules

Examples:

```text
organizationId + invoiceNumber
organizationId + orderNumber
organizationId + sku
organizationId + supplierInvoiceNumber + supplierId
```

Do not use global uniqueness where organization-level uniqueness is correct.

---

# 39. Transaction Boundaries

Use database transactions for:

### Payment creation

```text
Create Payment
Create Allocations
Update Invoice State
Write Audit Log
```

### Goods receipt

```text
Create Goods Receipt
Create Inventory Movement
Update Inventory Balance
Update PO status
```

### Production completion

```text
Consume Material
Create Finished Goods
Update Inventory
Update Production Order
```

### Dispatch

```text
Create Dispatch
Decrease Inventory
Update Order
```

Never allow partial database updates for these workflows.

---

# 40. API Standards

Base path:

```text
/api/v1
```

Use JSON.

Successful single resource:

```json
{
  "data": {}
}
```

Successful collection:

```json
{
  "data": [],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

Error:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Please correct the highlighted fields.",
    "fields": {}
  }
}
```

---

# 41. Common API Features

All list APIs should support where relevant:

```text
page
pageSize
search
status
sortBy
sortOrder
dateFrom
dateTo
```

Default:

```text
pageSize = 20
```

Never return unlimited records.

---

# 42. Authentication APIs

```text
POST /auth/register
POST /auth/login
POST /auth/logout
POST /auth/refresh
POST /auth/forgot-password
POST /auth/reset-password
GET  /auth/me
```

Registration should create the Tenant and Organization.

---

# 43. Organization APIs

```text
GET   /organizations/current
PATCH /organizations/current

GET   /organization-settings
PATCH /organization-settings
```

---

# 44. Dashboard API

```text
GET /dashboard/summary
```

Return:

```text
salesThisMonth
purchasesThisMonth

totalReceivables
overdueReceivables

totalPayables
overduePayables

paymentsReceivedThisMonth
paymentsMadeThisMonth

openOrders
ordersInProduction
ordersReadyForDispatch

lowStockMaterialCount
lowStockMaterials

upcomingCustomerPayments
upcomingSupplierPayments
```

Do not require the frontend to call fifteen APIs to render the dashboard.

---

# 45. Supplier APIs

```text
GET    /suppliers
POST   /suppliers
GET    /suppliers/:id
PATCH  /suppliers/:id
DELETE /suppliers/:id

GET /suppliers/:id/ledger
GET /suppliers/:id/purchases
GET /suppliers/:id/payments
GET /suppliers/:id/outstanding
```

DELETE performs soft delete.

---

# 46. Customer APIs

```text
GET    /customers
POST   /customers
GET    /customers/:id
PATCH  /customers/:id
DELETE /customers/:id

GET /customers/:id/ledger
GET /customers/:id/orders
GET /customers/:id/invoices
GET /customers/:id/payments
GET /customers/:id/outstanding
```

---

# 47. Raw Material APIs

```text
GET    /raw-materials
POST   /raw-materials
GET    /raw-materials/:id
PATCH  /raw-materials/:id
DELETE /raw-materials/:id

GET /raw-materials/:id/stock
GET /raw-materials/:id/movements
```

---

# 48. Product APIs

```text
GET    /products
POST   /products
GET    /products/:id
PATCH  /products/:id
DELETE /products/:id

GET /products/:id/stock
GET /products/:id/movements
GET /products/:id/bom
PUT /products/:id/bom
```

---

# 49. Purchase Order APIs

```text
GET  /purchase-orders
POST /purchase-orders
GET  /purchase-orders/:id
PATCH /purchase-orders/:id

POST /purchase-orders/:id/confirm
POST /purchase-orders/:id/cancel

GET /purchase-orders/:id/receipts
```

---

# 50. Goods Receipt APIs

```text
GET  /goods-receipts
POST /goods-receipts
GET  /goods-receipts/:id

POST /goods-receipts/:id/post
POST /goods-receipts/:id/cancel
```

---

# 51. Supplier Invoice APIs

```text
GET  /supplier-invoices
POST /supplier-invoices
GET  /supplier-invoices/:id
PATCH /supplier-invoices/:id

POST /supplier-invoices/:id/post
POST /supplier-invoices/:id/void
```

---

# 52. Supplier Payment APIs

```text
GET  /supplier-payments
POST /supplier-payments
GET  /supplier-payments/:id

POST /supplier-payments/:id/void
```

Payment creation accepts allocations:

```json
{
  "supplierId": "...",
  "amount": 500000,
  "paymentDate": "...",
  "paymentMethod": "BANK_TRANSFER",
  "allocations": [
    {
      "supplierInvoiceId": "...",
      "amount": 200000
    },
    {
      "supplierInvoiceId": "...",
      "amount": 300000
    }
  ]
}
```

---

# 53. Sales Order APIs

```text
GET  /sales-orders
POST /sales-orders
GET  /sales-orders/:id
PATCH /sales-orders/:id

POST /sales-orders/:id/confirm
POST /sales-orders/:id/cancel

GET /sales-orders/:id/invoices
GET /sales-orders/:id/dispatches
```

---

# 54. Sales Invoice APIs

```text
GET  /sales-invoices
POST /sales-invoices
GET  /sales-invoices/:id
PATCH /sales-invoices/:id

POST /sales-invoices/:id/post
POST /sales-invoices/:id/void

GET /sales-invoices/:id/pdf
```

---

# 55. Installment APIs

```text
POST   /sales-invoices/:id/payment-schedule
GET    /sales-invoices/:id/payment-schedule
PATCH  /payment-schedules/:id

POST /payment-schedules/:id/regenerate
```

Allow:

```text
weekly
monthly
custom
```

---

# 56. Customer Payment APIs

```text
GET  /customer-payments
POST /customer-payments
GET  /customer-payments/:id

POST /customer-payments/:id/void
```

---

# 57. Inventory APIs

```text
GET /inventory
GET /inventory/low-stock
GET /inventory/movements

GET /inventory/raw-materials
GET /inventory/products

POST /inventory/adjustments
```

Inventory adjustment requires:

```text
item
quantity
reason
notes
```

---

# 58. Production APIs

```text
GET  /production-orders
POST /production-orders
GET  /production-orders/:id
PATCH /production-orders/:id

POST /production-orders/:id/start
POST /production-orders/:id/complete
POST /production-orders/:id/cancel
```

---

# 59. Dispatch APIs

```text
GET  /dispatches
POST /dispatches
GET  /dispatches/:id

POST /dispatches/:id/post
POST /dispatches/:id/cancel
```

---

# 60. Expense APIs

```text
GET    /expenses
POST   /expenses
GET    /expenses/:id
PATCH  /expenses/:id
DELETE /expenses/:id

GET /expense-categories
POST /expense-categories
```

---

# 61. Reports APIs

Implement:

```text
GET /reports/sales
GET /reports/purchases
GET /reports/receivables
GET /reports/receivables-aging
GET /reports/payables
GET /reports/payables-aging
GET /reports/inventory
GET /reports/customer-ledger
GET /reports/supplier-ledger
GET /reports/expenses
GET /reports/payment-collections
GET /reports/order-status
GET /reports/production
```

Support:

```text
dateFrom
dateTo
customerId
supplierId
status
```

---

# 62. Documents APIs

```text
POST   /attachments/upload-url
POST   /attachments
GET    /attachments
DELETE /attachments/:id
```

Use S3 pre-signed URLs.

---

# 63. Audit APIs

```text
GET /audit-logs
GET /audit-logs/:entityType/:entityId
```

Only authorized users should access audit logs.

---

# 64. Notification APIs

```text
GET  /notifications
POST /notifications/:id/read
POST /notifications/read-all
```

---

# 65. OpenAPI

Generate and maintain:

```text
/openapi.json
/docs
```

Every endpoint must include:

- Request schema
- Response schema
- Validation
- Permission requirement
- Possible errors

The implementation must never allow controllers and API documentation to drift apart.

---

# 66. Frontend UX Philosophy

The primary user is not technically sophisticated.

Optimize for:

```text
"What do I need to do?"
```

not:

```text
"What features can the software expose?"
```

Do not expose accounting or ERP complexity unless necessary.

---

# 67. Main Navigation

On desktop:

```text
Home
Sales
Purchases
Inventory
Production
Expenses
Reports
More
```

On mobile use a bottom navigation:

```text
Home
Sales
Purchases
Inventory
More
```

Production, Expenses, Reports and Settings can live under More.

---

# 68. Dashboard UX

Dashboard should be extremely simple.

First section:

```text
Good evening

[ + New Order ]
[ + Add Purchase ]
[ + Receive Payment ]
```

Then show cards:

```text
Money to Receive
PKR 850,000

Money to Pay
PKR 430,000

Orders Pending
12

Low Stock Items
4
```

Prefer plain language.

Instead of:

```text
Accounts Receivable
```

display:

```text
Money to Receive
```

Instead of:

```text
Accounts Payable
```

display:

```text
Money to Pay
```

A detailed accounting label may be shown underneath if useful.

---

# 69. Quick Actions

Place these prominently:

```text
New Order
New Purchase
Create Invoice
Receive Payment
Pay Supplier
Add Customer
Add Supplier
Add Expense
```

The user should not need to navigate through multiple pages for common actions.

---

# 70. Form Design

Avoid large forms.

Use progressive disclosure.

For example, creating a purchase should initially show:

```text
Supplier
Date
Material
Quantity
Price
```

Then:

```text
+ Add another item
```

Advanced fields can appear under:

```text
More Options
```

including:

```text
Tax
Discount
Reference
Notes
Attachment
```

---

# 71. Customer Creation

Allow inline customer creation.

When creating an order:

```text
Customer
[ Search customer... ]
[ + Add new customer ]
```

Clicking Add New Customer should open a small modal requiring only:

```text
Customer Name
Phone
```

Everything else is optional.

Do not force the user to leave the order screen.

Do the same for suppliers.

---

# 72. Smart Defaults

Automatically default:

```text
Today's date
Default warehouse
Organization currency
Default payment terms
Last selected payment method where appropriate
```

Avoid asking users for information the system already knows.

---

# 73. Confirmation UX

Avoid modal confirmations for harmless actions.

Require confirmation for:

```text
Void invoice
Cancel payment
Delete customer
Inventory adjustment
Cancel production
Cancel dispatch
```

Explain consequences clearly.

Example:

```text
Void this invoice?

This will remove PKR 250,000 from the customer's outstanding balance.

Reason:
[________________]
```

---

# 74. Invoice UX

Invoice screen should show clearly:

```text
Invoice INV-000124

Customer
ABC Traders

Total
PKR 500,000

Paid
PKR 200,000

Remaining
PKR 300,000
```

Primary actions:

```text
Receive Payment
Payment Plan
Download PDF
```

Do not overcrowd the page.

---

# 75. Payment Schedule UX

When selecting Payment Plan:

```text
How will the customer pay?

○ Weekly
○ Monthly
○ Custom
```

Example:

```text
Invoice Amount:
PKR 400,000

Number of payments:
4

Every:
Monthly

[ Generate Schedule ]
```

Then show editable rows.

---

# 76. Purchase UX

Purchase detail page should emphasize:

```text
Total Purchase
Amount Paid
Amount Remaining
Due Date
```

Actions:

```text
Pay Supplier
Attach Invoice
View Ledger
```

---

# 77. Inventory UX

Do not initially expose a complicated warehouse management interface.

Show:

```text
Raw Materials
Finished Products
Low Stock
```

Each item:

```text
Cotton Yarn

Available:
1,200 KG

Minimum:
500 KG

Status:
Good
```

---

# 78. Search

Global search should eventually support:

```text
Customer
Supplier
Invoice Number
Order Number
Material
Product
```

Every list page should have a prominent search field.

---

# 79. Mobile UX

Assume many operations happen on a phone.

Requirements:

- Touch targets at least 44px
- Large buttons
- Minimal tables
- Cards on mobile
- Sticky primary actions
- Bottom navigation
- Numeric keyboards for amounts
- Date picker optimized for mobile
- Searchable selectors
- Avoid horizontal scrolling

Desktop can use tables.

Mobile should convert tables into cards.

---

# 80. PWA

Implement:

- Web app manifest
- Application icons
- Installable application
- Standalone display mode
- Responsive layouts
- Basic service worker caching

Do not implement complex offline financial writes in V1.

Offline writes create synchronization problems and should be deferred.

The app can cache shell/static assets while requiring connectivity for financial transactions.

---

# 81. Theme

Use a professional grey theme.

Recommended tokens:

```text
App Background: #F5F5F5
Card Background: #FFFFFF

Primary: #3F3F46
Primary Hover: #27272A

Main Text: #18181B
Secondary Text: #71717A

Border: #D4D4D8
Input Background: #FFFFFF

Sidebar: #27272A
Sidebar Text: #F4F4F5
```

Use rounded cards but avoid an overly playful style.

Keep shadows subtle.

Use plenty of whitespace.

---

# 82. Status Colors

The overall application should remain grey, but status colors are allowed because they communicate meaning.

Use subtle colors for:

```text
Paid → Green
Overdue → Red
Due Soon → Amber
Draft → Grey
Completed → Green
Cancelled → Grey/Red
```

Do not make the entire UI monochrome at the expense of usability.

---

# 83. MVP Implementation Phases

## Phase 1 — Foundation

Build:

- Monorepo
- Database
- Prisma
- Authentication
- Tenant model
- Organization model
- Memberships
- Roles
- Permissions
- Audit infrastructure
- Number sequences
- Organization settings
- S3 attachment infrastructure

Do not start building business screens before the database foundation is stable.

---

## Phase 2 — Master Data

Build:

- Customers
- Suppliers
- Units
- Raw materials
- Products
- Warehouses

Complete APIs and UI.

---

## Phase 3 — Purchases and Payables

Build:

```text
Supplier
↓
Purchase
↓
Goods Receipt
↓
Supplier Invoice
↓
Supplier Payment
↓
Supplier Ledger
```

Deliver:

- Purchase management
- Supplier invoices
- Partial supplier payments
- Outstanding supplier balances
- Payables report
- Supplier ledger
- Inventory receiving

---

## Phase 4 — Sales and Receivables

Build:

```text
Customer
↓
Order
↓
Invoice
↓
Payment Schedule
↓
Customer Payment
↓
Customer Ledger
```

Deliver:

- Orders
- Invoices
- Partial invoices
- Weekly payment schedules
- Monthly payment schedules
- Custom installments
- Partial payments
- Receivables
- Aging report

---

## Phase 5 — Inventory

Deliver:

- Inventory movement engine
- Stock balances
- Raw material inventory
- Finished goods inventory
- Low stock detection
- Inventory adjustments
- Stock movement history

---

## Phase 6 — Production

Deliver:

- BOM
- Production orders
- Material consumption
- Production output
- Waste/rejected quantity
- Automatic stock movement

---

## Phase 7 — Dispatch

Deliver:

- Dispatch creation
- Partial dispatch
- Delivery information
- Inventory reduction
- Delivery status

---

## Phase 8 — Expenses

Deliver:

- Expense categories
- Expense entry
- Expense reports

---

## Phase 9 — Dashboard and Reports

Build owner dashboard only after transaction modules work correctly.

Deliver:

- Receivables
- Payables
- Sales
- Purchases
- Expenses
- Inventory
- Aging
- Customer ledger
- Supplier ledger
- Orders
- Production

---

## Phase 10 — Notifications

Add:

- Overdue customer payment
- Upcoming customer installment
- Supplier payment due
- Low stock
- Order delivery due

Start with in-app notifications.

---

## Phase 11 — PWA and Mobile Optimization

Finalize:

- PWA
- Responsive layouts
- Bottom navigation
- Touch optimization
- Installability
- Performance
- Mobile testing

---

# 84. MVP Priority

The first genuinely usable release should contain:

```text
Authentication
Tenant onboarding
Organization

Dashboard

Customers
Suppliers

Raw Materials

Purchases
Supplier invoices
Supplier payments
Supplier balances

Orders
Invoices
Payment schedules
Customer payments
Customer receivables

Inventory

Customer ledger
Supplier ledger

Expenses

Reports

Attachments
Audit logs
```

Production/BOM and advanced dispatch can follow immediately afterward if delivery speed is important.

However, database architecture should support them from the beginning.

---

# 85. Code Architecture Rules

Do not place business logic in controllers.

Use:

```text
Route
↓
Validation
↓
Controller
↓
Service
↓
Repository/Prisma
```

Controllers should:

- Parse request
- Call service
- Return response

Services should contain:

- Business rules
- Transactions
- Permission-sensitive logic
- Financial calculations

---

# 86. Suggested Backend Structure

```text
src/
  modules/
    auth/
    tenants/
    organizations/
    users/
    suppliers/
    customers/
    materials/
    products/
    purchases/
    supplier-payments/
    orders/
    invoices/
    customer-payments/
    inventory/
    production/
    dispatch/
    expenses/
    reports/
    notifications/
    audit/

  middleware/
  database/
  validation/
  errors/
  utils/
  config/
```

Each module should contain:

```text
controller
service
repository where useful
routes
schemas
types
tests
```

---

# 87. Frontend Structure

Organize frontend by product domain rather than creating one giant components folder.

Example:

```text
features/
  dashboard/
  customers/
  suppliers/
  purchases/
  orders/
  invoices/
  payments/
  inventory/
  production/
  expenses/
  reports/
```

Shared UI belongs under:

```text
components/ui
```

---

# 88. Financial Calculation Rule

Never trust totals supplied by the browser.

Frontend may send:

```text
quantity
unitPrice
discount
tax
```

Backend must calculate:

```text
lineTotal
subtotal
taxTotal
grandTotal
balance
```

The backend is always authoritative.

---

# 89. Validation

Validate on:

```text
Frontend
+
Backend
+
Database
```

Examples:

```text
Payment amount > 0
Invoice total >= 0
Quantity > 0
Allocation cannot exceed payment amount
Allocation cannot exceed invoice balance
Stock cannot become negative unless organization explicitly allows it
Credit limit warnings
Installment total must match invoice balance
```

---

# 90. Concurrency

Prevent double-payment and double-stock issues.

Use database transactions and appropriate locking when:

- Allocating payments
- Posting goods receipts
- Posting dispatches
- Completing production
- Adjusting inventory

Do not implement these workflows as independent API updates.

---

# 91. Idempotency

Financial transaction endpoints should support idempotency where practical.

Examples:

```text
POST /customer-payments
POST /supplier-payments
POST /goods-receipts/:id/post
POST /dispatches/:id/post
```

This prevents duplicate transactions caused by:

- Double taps
- Network retries
- Mobile connection issues

---

# 92. Security

Mandatory requirements:

- Password hashing using a modern password hashing algorithm
- Secure HTTP-only cookies or securely managed authentication tokens
- Refresh token rotation if token-based authentication is used
- Rate limiting
- CORS restrictions
- Helmet/security headers
- Input validation
- SQL injection protection through ORM
- Tenant isolation
- Permission middleware
- Secure S3 URLs
- Secrets outside source code
- Production HTTPS only

Never trust:

```text
tenantId
organizationId
userId
```

provided by the browser.

Resolve them from authenticated server context.

---

# 93. Tenant Isolation

Every business service must receive authenticated context:

```ts
{
  userId,
  tenantId,
  organizationId,
  permissions
}
```

All DB queries must scope using this context.

Never expose APIs like:

```text
?tenantId=123
```

to select another tenant.

---

# 94. Testing

At minimum implement:

### Unit tests

For:

- Invoice calculations
- Payment allocations
- Installment calculations
- Stock calculations
- Credit calculations

### Integration tests

For:

- Creating purchase
- Receiving stock
- Paying supplier
- Creating invoice
- Receiving partial payment
- Completing production
- Dispatching goods

### End-to-end tests

Use Playwright for critical workflows.

Test:

```text
Onboarding
Create Supplier
Add Purchase
Pay Supplier

Create Customer
Create Order
Create Invoice
Create Monthly Schedule
Receive Partial Payment

Check Dashboard
```

---

# 95. Seed Data

Provide a development seed.

Example:

```text
Demo Factory

Supplier:
ABC Raw Materials

Customer:
XYZ Traders

Raw Material:
Cotton

Product:
Finished Fabric
```

Seed enough transactions to display useful dashboard information.

---

# 96. Logging

Use structured logging.

Each request should contain:

```text
requestId
userId
tenantId
organizationId
```

Never log:

- Passwords
- Authentication tokens
- Sensitive credentials

---

# 97. Observability

Track:

- API errors
- Database errors
- Slow requests
- Failed financial transactions
- Failed S3 operations
- Failed background jobs

Use CloudWatch initially.

---

# 98. Performance

Avoid premature optimization.

But implement:

- Pagination
- Proper indexes
- Select only required DB fields
- Avoid N+1 queries
- Cache expensive dashboard/report queries later if required

Do not cache financial writes.

---

# 99. Background Jobs

Introduce a lightweight job system when required for:

- Overdue invoice detection
- Notifications
- PDF generation
- Email
- Large exports

Do not make normal API requests wait for expensive report generation.

---

# 100. PDF Invoice

Invoice PDF should contain:

```text
Company information
Invoice number
Invoice date
Customer
Items
Quantity
Rate
Tax
Discount
Total
Paid
Balance

Payment schedule where applicable

Company notes
```

Keep PDF clean and printable.

---

# 101. CSV/Excel Exports

Reports should eventually support:

```text
CSV
Excel
PDF
```

Initial MVP can begin with CSV and PDF.

---

# 102. Audit Requirements

Every important financial action should generate an audit entry.

Examples:

```text
Invoice created
Invoice amount changed
Invoice voided

Payment created
Payment allocation changed
Payment voided

Inventory adjustment made

Supplier invoice created
```

---

# 103. What Not to Build in Initial MVP

Do not add unnecessary complexity such as:

- Complex accounting general ledger
- Payroll
- HR management
- Machine IoT
- Barcode infrastructure
- Offline transaction synchronization
- AI forecasting
- Complex demand planning
- Multiple currencies per invoice
- Advanced tax engine
- Mobile native application
- Bank integration

Keep architecture extensible, but do not build speculative features.

---

# 104. Definition of Done for Each Feature

A feature is not complete until it has:

```text
Database migration
Prisma model

Backend validation
Service layer
API endpoint
Authorization
Tenant isolation

Frontend UI
Loading state
Empty state
Error state
Mobile layout

Audit logging where required

Tests
Documentation
```

Do not declare a feature complete because only the happy path works.

---

# 105. Empty States

Since the owner may be inexperienced with software, empty states must explain what to do.

Bad:

```text
No Records Found
```

Good:

```text
You haven't added any suppliers yet.

Suppliers are companies you purchase raw materials from.

[ Add First Supplier ]
```

---

# 106. Error Messages

Never expose technical errors such as:

```text
Foreign key constraint violation
```

Show:

```text
This payment cannot be deleted because it has already been applied to an invoice.
```

Technical details go to logs.

---

# 107. User Experience Rule

For every feature ask:

> Can the factory owner complete this without understanding accounting or ERP terminology?

If not, simplify it.

For example:

Use:

```text
Receive Payment
```

instead of:

```text
Post Accounts Receivable Transaction
```

Use:

```text
Pay Supplier
```

instead of:

```text
Create AP Settlement
```

---

# 108. AI Agent Development Instructions

The coding agent must follow this sequence.

### Step 1

Read this entire specification before modifying code.

### Step 2

Create project architecture and engineering conventions.

### Step 3

Create the complete database ERD.

### Step 4

Create Prisma schema.

### Step 5

Review:

- Relationships
- Cascades
- Constraints
- Indexes
- Multi-tenancy
- Financial precision

Do not continue until the schema is internally consistent.

### Step 6

Generate migrations.

### Step 7

Implement authentication and tenancy.

### Step 8

Implement common infrastructure:

- Validation
- Error handling
- Permissions
- Audit logging
- Number sequences
- Transactions
- S3

### Step 9

Create the complete REST/OpenAPI contract.

### Step 10

Implement APIs module-by-module.

### Step 11

Add integration tests.

### Step 12

Build frontend design system.

### Step 13

Build simplified frontend workflows.

### Step 14

Add mobile responsive behavior.

### Step 15

Add PWA support.

### Step 16

Complete end-to-end tests.

### Step 17

Perform security and tenant isolation review.

### Step 18

Deploy development/staging environment.

---

# 109. AI Coding Rules

The agent must:

- Prefer simple readable code over clever abstractions.
- Avoid duplication where a clear reusable abstraction exists.
- Avoid premature abstraction.
- Keep functions small.
- Give variables meaningful names.
- Separate business logic from HTTP logic.
- Never duplicate financial calculation logic between frontend and backend.
- Keep source of truth on backend.
- Add comments only when they explain why, not what.
- Never introduce a dependency without a clear need.
- Never bypass TypeScript with unnecessary `any`.
- Never suppress errors simply to make compilation pass.
- Never leave temporary hacks without documenting them.
- Never commit secrets.
- Never hardcode tenant IDs.
- Never hardcode organization IDs.
- Never use floating-point arithmetic for money.
- Never delete posted financial transactions.
- Never change inventory without an inventory movement.
- Never change financial data without an audit trail.
- Never trust monetary totals calculated by the client.

---

# 110. Migration Rules

Every schema modification must be implemented through a migration.

Never manually modify production database structure.

Migrations should be:

```text
Small
Reversible where possible
Reviewed
Named clearly
```

---

# 111. API Compatibility

API responses should remain backward compatible within:

```text
/api/v1
```

Breaking changes should eventually create:

```text
/api/v2
```

Do not casually rename response fields after frontend implementation.

---

# 112. White-Label Readiness

Do not build a complete white-label administration system in MVP.

However, ensure Tenant can eventually configure:

```text
Application name
Logo
Favicon
Primary colors
Support email
Custom domain
Invoice branding
```

Do not embed the original product name throughout the application source code.

Use tenant configuration.

---

# 113. Future Multiple Users

The architecture must already support inviting users.

Future workflow:

```text
Owner
↓
Invite User
↓
Select Role
↓
User Joins Organization
```

No schema redesign should be required.

---

# 114. Recommended Initial Screens

Build these screens first:

```text
Login
Register / Company Setup

Dashboard

Customers
Customer Detail

Suppliers
Supplier Detail

Raw Materials
Inventory

Purchases
Purchase Detail

Supplier Payments

Orders
Order Detail

Invoices
Invoice Detail

Receive Payment

Payment Schedule

Expenses

Reports

Settings
```

Later:

```text
Production
BOM
Dispatch
Advanced Inventory
Users & Roles
```

---

# 115. Final Product Principle

The software should feel like:

> A simple factory notebook that automatically understands inventory, money owed, money payable, orders and payments.

It should not feel like:

> A complicated ERP that requires training before the owner can use it.

The system may be technically sophisticated internally, but the interface must remain extremely simple.

---

# 116. Primary Business Flows

## Purchase Flow

```text
Supplier
   ↓
Purchase Order
   ↓
Material Received
   ↓
Inventory Increased
   ↓
Supplier Invoice
   ↓
Money to Pay
   ↓
Supplier Payment
```

## Sales Flow

```text
Customer
   ↓
Order
   ↓
Production
   ↓
Finished Product
   ↓
Dispatch
   ↓
Invoice
   ↓
Money to Receive
   ↓
Customer Payment
```

## Production Flow

```text
Raw Material
   ↓
Production Order
   ↓
Material Consumption
   ↓
Finished Goods
```

These three flows should remain the conceptual foundation of the entire application.