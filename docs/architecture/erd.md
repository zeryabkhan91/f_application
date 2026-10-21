# Factory database ERD

The [generated complete ERD](schema.erd.mmd) contains all 50 models, scalar fields,
and concrete foreign keys. Regenerate it with `npm run erd:generate`. The diagrams
below group the principal relationships; organization scope keys and actor links
apply to every business entity, including child rows.

```mermaid
erDiagram
  Tenant ||--o| TenantBranding : configures
  Tenant ||--o{ Organization : owns
  User ||--o{ Membership : joins
  Organization ||--o{ Membership : has
  Organization ||--o{ Role : defines
  Role ||--o{ Membership : assigns
  Role ||--o{ RolePermission : grants
  Permission ||--o{ RolePermission : defines
  Organization ||--o| OrganizationSettings : configures
  Organization ||--o{ NumberSequence : numbers
  Organization ||--o{ Warehouse : operates
  Organization ||--o{ Unit : measures
  UnitDefinition |o--o{ Unit : supplies_defaults
```

```mermaid
erDiagram
  Supplier ||--o{ PurchaseOrder : receives
  PurchaseOrder ||--o{ PurchaseOrderItem : contains
  PurchaseOrder |o--o{ GoodsReceipt : receives
  GoodsReceipt ||--o{ GoodsReceiptItem : contains
  RawMaterial ||--o{ GoodsReceiptItem : receives
  Supplier ||--o{ SupplierInvoice : bills
  PurchaseOrder |o--o{ SupplierInvoice : references
  SupplierInvoice ||--o{ SupplierInvoiceItem : contains
  Supplier ||--o{ SupplierPayment : receives
  SupplierPayment ||--o{ SupplierPaymentAllocation : allocates
  SupplierInvoice ||--o{ SupplierPaymentAllocation : settles
```

```mermaid
erDiagram
  Customer ||--o{ SalesOrder : places
  SalesOrder ||--o{ SalesOrderItem : contains
  Product ||--o{ SalesOrderItem : sells
  SalesOrder |o--o{ SalesInvoice : bills
  SalesInvoice ||--o{ SalesInvoiceItem : contains
  SalesInvoice ||--o{ PaymentSchedule : schedules
  PaymentSchedule ||--o{ PaymentInstallment : divides
  Customer ||--o{ CustomerPayment : pays
  CustomerPayment ||--o{ CustomerPaymentAllocation : allocates
  SalesInvoice ||--o{ CustomerPaymentAllocation : settles
  PaymentInstallment |o--o{ CustomerPaymentAllocation : optionally_matches
  SalesOrder ||--o{ Dispatch : dispatches
  Dispatch ||--o{ DispatchItem : contains
  SalesOrderItem ||--o{ DispatchItem : fulfills
```

```mermaid
erDiagram
  Product ||--o{ BillOfMaterial : defines
  BillOfMaterial ||--o{ BillOfMaterialItem : consumes
  RawMaterial ||--o{ BillOfMaterialItem : uses
  Product ||--o{ ProductionOrder : produces
  BillOfMaterial |o--o{ ProductionOrder : plans
  ProductionOrder ||--o{ ProductionMaterialConsumption : consumes
  ProductionOrder ||--o{ ProductionOutput : outputs
  Warehouse ||--o{ InventoryMovement : records
  Warehouse ||--o{ InventoryBalance : caches
  RawMaterial |o--o{ InventoryMovement : raw_item
  Product |o--o{ InventoryMovement : finished_item
  ExpenseCategory ||--o{ Expense : classifies
  StoredObject ||--o| Attachment : stores
  Membership ||--o{ Attachment : uploads
  Membership |o--o{ AuditLog : acts
  Membership ||--o{ Notification : receives
```

Every organization-owned relationship includes `(tenantId, organizationId)`.
Payment/invoice references additionally match the counterparty; receipt/dispatch
lines match their parent order/item; production references match the product.
Attachment's polymorphic business target is validated by SQL. Audit and inventory
history are append-only. Derived balance/availability views do not introduce new
financial sources of truth. See [database decisions](database.md) for constraints
and remaining transactional workflow responsibilities.
