-- The prior scaffold had no tenant ownership. Refuse to guess ownership of legacy objects.
BEGIN;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM stored_objects) THEN
    RAISE EXCEPTION 'Existing stored_objects need an explicit tenant/organization backfill migration before this foundation can be applied';
  END IF;
END $$;
CREATE EXTENSION IF NOT EXISTS citext;

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'INVITED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "TenantStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "OrganizationStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "MembershipStatus" AS ENUM ('ACTIVE', 'INVITED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "RecordStatus" AS ENUM ('ACTIVE', 'INACTIVE');

-- CreateEnum
CREATE TYPE "RoleCode" AS ENUM ('OWNER', 'ADMIN', 'ACCOUNTS', 'SALES', 'PRODUCTION', 'WAREHOUSE', 'VIEWER', 'CUSTOM');

-- CreateEnum
CREATE TYPE "NumberSequenceType" AS ENUM ('INVOICE', 'ORDER', 'PURCHASE', 'PAYMENT', 'SUPPLIER_PAYMENT', 'SUPPLIER_INVOICE', 'GOODS_RECEIPT', 'PRODUCTION', 'DISPATCH', 'EXPENSE');

-- CreateEnum
CREATE TYPE "PurchaseOrderStatus" AS ENUM ('DRAFT', 'CONFIRMED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "GoodsReceiptStatus" AS ENUM ('DRAFT', 'POSTED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "InvoiceStatus" AS ENUM ('DRAFT', 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'VOID');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('DRAFT', 'POSTED', 'VOID');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('CASH', 'BANK_TRANSFER', 'CHEQUE', 'OTHER');

-- CreateEnum
CREATE TYPE "SalesOrderStatus" AS ENUM ('DRAFT', 'CONFIRMED', 'IN_PRODUCTION', 'READY', 'PARTIALLY_DISPATCHED', 'DISPATCHED', 'DELIVERED', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ScheduleType" AS ENUM ('WEEKLY', 'MONTHLY', 'CUSTOM');

-- CreateEnum
CREATE TYPE "ScheduleStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "InstallmentStatus" AS ENUM ('UPCOMING', 'DUE', 'PARTIALLY_PAID', 'PAID', 'OVERDUE');

-- CreateEnum
CREATE TYPE "InventoryItemType" AS ENUM ('RAW_MATERIAL', 'PRODUCT');

-- CreateEnum
CREATE TYPE "InventoryMovementType" AS ENUM ('PURCHASE_RECEIPT', 'PRODUCTION_CONSUMPTION', 'PRODUCTION_OUTPUT', 'SALE_DISPATCH', 'RETURN_IN', 'RETURN_OUT', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'TRANSFER_IN', 'TRANSFER_OUT');

-- CreateEnum
CREATE TYPE "InventoryReferenceType" AS ENUM ('GOODS_RECEIPT', 'PRODUCTION_ORDER', 'DISPATCH', 'ADJUSTMENT', 'RETURN', 'TRANSFER');

-- CreateEnum
CREATE TYPE "BillOfMaterialStatus" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "ProductionOrderStatus" AS ENUM ('DRAFT', 'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "DispatchStatus" AS ENUM ('DRAFT', 'POSTED', 'DELIVERED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ExpenseStatus" AS ENUM ('DRAFT', 'POSTED', 'VOID');

-- CreateEnum
CREATE TYPE "AttachmentEntityType" AS ENUM ('SUPPLIER', 'CUSTOMER', 'RAW_MATERIAL', 'PRODUCT', 'PURCHASE_ORDER', 'SUPPLIER_INVOICE', 'SUPPLIER_PAYMENT', 'SALES_ORDER', 'SALES_INVOICE', 'CUSTOMER_PAYMENT', 'DISPATCH', 'PRODUCTION_ORDER', 'EXPENSE');

-- CreateEnum
CREATE TYPE "AuditAction" AS ENUM ('CREATE', 'UPDATE', 'VOID', 'CANCEL', 'PAYMENT', 'STATUS_CHANGE', 'DELETE_MASTER_RECORD', 'REVERSE');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('CUSTOMER_PAYMENT_OVERDUE', 'SUPPLIER_PAYMENT_DUE', 'CUSTOMER_INSTALLMENT_DUE', 'LOW_RAW_MATERIAL_STOCK', 'ORDER_DELIVERY_APPROACHING');

-- AlterTable
ALTER TABLE "stored_objects" ADD COLUMN     "created_by" UUID,
ADD COLUMN     "organization_id" UUID NOT NULL,
ADD COLUMN     "tenant_id" UUID NOT NULL,
ADD COLUMN     "updated_by" UUID,
ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(160) NOT NULL,
    "email" CITEXT NOT NULL,
    "password_hash" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'INVITED',
    "last_login_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tenants" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(200) NOT NULL,
    "slug" CITEXT NOT NULL,
    "status" "TenantStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "tenants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tenant_branding" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "application_name" VARCHAR(160),
    "logo_url" TEXT,
    "favicon_url" TEXT,
    "primary_theme" JSONB,
    "custom_domain" CITEXT,
    "support_email" CITEXT,
    "invoice_branding" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "tenant_branding_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "currencies" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" CHAR(3) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "symbol" VARCHAR(10) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "currencies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "countries" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" CHAR(2) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "countries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "unit_definitions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "symbol" VARCHAR(20) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "unit_definitions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "permissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(100) NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "organizations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "slug" CITEXT NOT NULL,
    "legal_name" VARCHAR(200),
    "phone" VARCHAR(40),
    "email" CITEXT,
    "address" TEXT,
    "city" VARCHAR(100),
    "country_code" CHAR(2) NOT NULL DEFAULT 'PK',
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "timezone" VARCHAR(80) NOT NULL DEFAULT 'Asia/Karachi',
    "tax_number" VARCHAR(100),
    "status" "OrganizationStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "code" "RoleCode" NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "role_permissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "role_id" UUID NOT NULL,
    "permission_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "memberships" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role_id" UUID NOT NULL,
    "status" "MembershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "memberships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "organization_settings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "default_currency" CHAR(3) NOT NULL DEFAULT 'PKR',
    "default_payment_terms_days" INTEGER NOT NULL DEFAULT 30,
    "invoice_footer" TEXT,
    "invoice_notes" TEXT,
    "low_stock_notifications_enabled" BOOLEAN NOT NULL DEFAULT true,
    "payment_reminder_enabled" BOOLEAN NOT NULL DEFAULT true,
    "allow_negative_stock" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "organization_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "number_sequences" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "type" "NumberSequenceType" NOT NULL,
    "prefix" VARCHAR(20) NOT NULL,
    "current_number" BIGINT NOT NULL DEFAULT 0,
    "padding" INTEGER NOT NULL DEFAULT 6,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "number_sequences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "units" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "definition_id" UUID,
    "code" VARCHAR(20) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "symbol" VARCHAR(20) NOT NULL,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "units_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "suppliers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "company_name" VARCHAR(200),
    "contact_person" VARCHAR(160),
    "phone" VARCHAR(40),
    "email" CITEXT,
    "tax_number" VARCHAR(100),
    "payment_terms_days" INTEGER NOT NULL DEFAULT 30,
    "opening_balance" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "notes" TEXT,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "address" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "company_name" VARCHAR(200),
    "contact_person" VARCHAR(160),
    "phone" VARCHAR(40),
    "email" CITEXT,
    "tax_number" VARCHAR(100),
    "payment_terms_days" INTEGER NOT NULL DEFAULT 30,
    "opening_balance" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "notes" TEXT,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "billing_address" TEXT,
    "shipping_address" TEXT,
    "credit_limit" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "raw_materials" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "sku" CITEXT NOT NULL,
    "description" TEXT,
    "unit_id" UUID NOT NULL,
    "minimum_stock_level" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "standard_cost" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "reorder_level" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "last_purchase_cost" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "raw_materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "products" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "sku" CITEXT NOT NULL,
    "description" TEXT,
    "unit_id" UUID NOT NULL,
    "minimum_stock_level" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "standard_cost" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "selling_price" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "warehouses" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "code" VARCHAR(30) NOT NULL,
    "address" TEXT,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "warehouses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expense_categories" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "expense_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "purchase_order_number" VARCHAR(50) NOT NULL,
    "supplier_id" UUID NOT NULL,
    "order_date" DATE NOT NULL,
    "expected_delivery_date" DATE,
    "status" "PurchaseOrderStatus" NOT NULL DEFAULT 'DRAFT',
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "subtotal" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "total" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "notes" TEXT,
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "purchase_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchase_order_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "purchase_order_id" UUID NOT NULL,
    "raw_material_id" UUID NOT NULL,
    "description" TEXT,
    "quantity" DECIMAL(18,4) NOT NULL,
    "unit_price" DECIMAL(18,2) NOT NULL,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "line_total" DECIMAL(18,2) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "purchase_order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "goods_receipts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "receipt_number" VARCHAR(50) NOT NULL,
    "purchase_order_id" UUID,
    "supplier_id" UUID NOT NULL,
    "warehouse_id" UUID NOT NULL,
    "received_date" DATE NOT NULL,
    "status" "GoodsReceiptStatus" NOT NULL DEFAULT 'DRAFT',
    "notes" TEXT,
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "goods_receipts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "goods_receipt_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "goods_receipt_id" UUID NOT NULL,
    "purchase_order_id" UUID,
    "purchase_order_item_id" UUID,
    "raw_material_id" UUID NOT NULL,
    "quantity_received" DECIMAL(18,4) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "goods_receipt_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "supplier_invoices" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "supplier_invoice_number" VARCHAR(100) NOT NULL,
    "internal_reference" VARCHAR(50) NOT NULL,
    "supplier_id" UUID NOT NULL,
    "purchase_order_id" UUID,
    "invoice_date" DATE NOT NULL,
    "due_date" DATE NOT NULL,
    "status" "InvoiceStatus" NOT NULL DEFAULT 'DRAFT',
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "subtotal" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "total" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "notes" TEXT,
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "supplier_invoices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "supplier_invoice_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "supplier_invoice_id" UUID NOT NULL,
    "raw_material_id" UUID NOT NULL,
    "description" TEXT,
    "quantity" DECIMAL(18,4) NOT NULL,
    "unit_price" DECIMAL(18,2) NOT NULL,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "line_total" DECIMAL(18,2) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "supplier_invoice_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "order_number" VARCHAR(50) NOT NULL,
    "customer_id" UUID NOT NULL,
    "order_date" DATE NOT NULL,
    "expected_delivery_date" DATE,
    "status" "SalesOrderStatus" NOT NULL DEFAULT 'DRAFT',
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "subtotal" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "total" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "notes" TEXT,
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "sales_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_order_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "sales_order_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "description" TEXT,
    "quantity" DECIMAL(18,4) NOT NULL,
    "unit_price" DECIMAL(18,2) NOT NULL,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "line_total" DECIMAL(18,2) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "sales_order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_invoices" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "invoice_number" VARCHAR(50) NOT NULL,
    "customer_id" UUID NOT NULL,
    "sales_order_id" UUID,
    "invoice_date" DATE NOT NULL,
    "due_date" DATE NOT NULL,
    "status" "InvoiceStatus" NOT NULL DEFAULT 'DRAFT',
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "subtotal" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "total" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "notes" TEXT,
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "sales_invoices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales_invoice_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "sales_invoice_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "description" TEXT,
    "quantity" DECIMAL(18,4) NOT NULL,
    "unit_price" DECIMAL(18,2) NOT NULL,
    "discount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "tax" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "line_total" DECIMAL(18,2) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "sales_invoice_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "supplier_payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "supplier_id" UUID NOT NULL,
    "payment_number" VARCHAR(50) NOT NULL,
    "payment_date" DATE NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "payment_method" "PaymentMethod" NOT NULL,
    "reference_number" VARCHAR(100),
    "notes" TEXT,
    "status" "PaymentStatus" NOT NULL DEFAULT 'POSTED',
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "supplier_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "payment_number" VARCHAR(50) NOT NULL,
    "payment_date" DATE NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "payment_method" "PaymentMethod" NOT NULL,
    "reference_number" VARCHAR(100),
    "notes" TEXT,
    "status" "PaymentStatus" NOT NULL DEFAULT 'POSTED',
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "customer_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "supplier_payment_allocations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "supplier_payment_id" UUID NOT NULL,
    "supplier_invoice_id" UUID NOT NULL,
    "supplier_id" UUID NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "supplier_payment_allocations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_schedules" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "sales_invoice_id" UUID NOT NULL,
    "schedule_type" "ScheduleType" NOT NULL,
    "number_of_installments" INTEGER NOT NULL,
    "scheduled_amount" DECIMAL(18,2) NOT NULL,
    "start_date" DATE NOT NULL,
    "status" "ScheduleStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "payment_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_installments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "payment_schedule_id" UUID NOT NULL,
    "sales_invoice_id" UUID NOT NULL,
    "installment_number" INTEGER NOT NULL,
    "due_date" DATE NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "status" "InstallmentStatus" NOT NULL DEFAULT 'UPCOMING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "payment_installments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_payment_allocations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "customer_payment_id" UUID NOT NULL,
    "sales_invoice_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "payment_installment_id" UUID,
    "amount" DECIMAL(18,2) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "customer_payment_allocations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bills_of_material" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "version" INTEGER NOT NULL,
    "status" "BillOfMaterialStatus" NOT NULL DEFAULT 'DRAFT',
    "effective_from" DATE,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "bills_of_material_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bill_of_material_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "bill_of_material_id" UUID NOT NULL,
    "raw_material_id" UUID NOT NULL,
    "quantity_required" DECIMAL(18,4) NOT NULL,
    "wastage_percentage" DECIMAL(7,4) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "bill_of_material_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "production_number" VARCHAR(50) NOT NULL,
    "product_id" UUID NOT NULL,
    "warehouse_id" UUID NOT NULL,
    "bill_of_material_id" UUID,
    "planned_quantity" DECIMAL(18,4) NOT NULL,
    "actual_quantity" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "planned_start_date" DATE,
    "planned_end_date" DATE,
    "actual_start_date" TIMESTAMPTZ(3),
    "actual_end_date" TIMESTAMPTZ(3),
    "status" "ProductionOrderStatus" NOT NULL DEFAULT 'DRAFT',
    "notes" TEXT,
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "production_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_material_consumptions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "production_order_id" UUID NOT NULL,
    "raw_material_id" UUID NOT NULL,
    "planned_quantity" DECIMAL(18,4) NOT NULL,
    "actual_quantity" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "production_material_consumptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_outputs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "production_order_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "quantity_produced" DECIMAL(18,4) NOT NULL,
    "quantity_rejected" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "production_outputs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expenses" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "expense_number" VARCHAR(50) NOT NULL,
    "category_id" UUID NOT NULL,
    "expense_date" DATE NOT NULL,
    "description" TEXT NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "currency_code" CHAR(3) NOT NULL DEFAULT 'PKR',
    "payment_method" "PaymentMethod" NOT NULL,
    "supplier_id" UUID,
    "reference_number" VARCHAR(100),
    "notes" TEXT,
    "status" "ExpenseStatus" NOT NULL DEFAULT 'POSTED',
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dispatches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "dispatch_number" VARCHAR(50) NOT NULL,
    "sales_order_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "warehouse_id" UUID NOT NULL,
    "dispatch_date" DATE NOT NULL,
    "driver_name" VARCHAR(160),
    "vehicle_number" VARCHAR(50),
    "tracking_reference" VARCHAR(100),
    "status" "DispatchStatus" NOT NULL DEFAULT 'DRAFT',
    "notes" TEXT,
    "voided_at" TIMESTAMPTZ(3),
    "voided_by" UUID,
    "void_reason" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "dispatches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dispatch_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "dispatch_id" UUID NOT NULL,
    "sales_order_id" UUID NOT NULL,
    "sales_order_item_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "quantity" DECIMAL(18,4) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_by" UUID,
    "updated_by" UUID,

    CONSTRAINT "dispatch_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_movements" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "warehouse_id" UUID NOT NULL,
    "item_type" "InventoryItemType" NOT NULL,
    "raw_material_id" UUID,
    "product_id" UUID,
    "movement_type" "InventoryMovementType" NOT NULL,
    "quantity" DECIMAL(18,4) NOT NULL,
    "unit_cost" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "reference_type" "InventoryReferenceType" NOT NULL,
    "reference_id" UUID,
    "reversal_of_id" UUID,
    "movement_date" TIMESTAMPTZ(3) NOT NULL,
    "notes" TEXT,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "inventory_movements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_balances" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "warehouse_id" UUID NOT NULL,
    "item_type" "InventoryItemType" NOT NULL,
    "raw_material_id" UUID,
    "product_id" UUID,
    "quantity_on_hand" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "quantity_reserved" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "inventory_balances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attachments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "stored_object_id" UUID NOT NULL,
    "entity_type" "AttachmentEntityType" NOT NULL,
    "entity_id" UUID NOT NULL,
    "file_name" VARCHAR(255) NOT NULL,
    "uploaded_by" UUID NOT NULL,
    "uploaded_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "user_id" UUID,
    "entity_type" VARCHAR(80) NOT NULL,
    "entity_id" UUID NOT NULL,
    "action" "AuditAction" NOT NULL,
    "old_values" JSONB,
    "new_values" JSONB,
    "ip_address" INET,
    "user_agent" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tenant_id" UUID NOT NULL,
    "organization_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" VARCHAR(200) NOT NULL,
    "message" TEXT NOT NULL,
    "entity_type" VARCHAR(80),
    "entity_id" UUID,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "tenants_slug_key" ON "tenants"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "tenant_branding_tenant_id_key" ON "tenant_branding"("tenant_id");

-- CreateIndex
CREATE UNIQUE INDEX "tenant_branding_custom_domain_key" ON "tenant_branding"("custom_domain");

-- CreateIndex
CREATE UNIQUE INDEX "currencies_code_key" ON "currencies"("code");

-- CreateIndex
CREATE UNIQUE INDEX "countries_code_key" ON "countries"("code");

-- CreateIndex
CREATE UNIQUE INDEX "unit_definitions_code_key" ON "unit_definitions"("code");

-- CreateIndex
CREATE UNIQUE INDEX "permissions_code_key" ON "permissions"("code");

-- CreateIndex
CREATE UNIQUE INDEX "organizations_tenant_id_id_key" ON "organizations"("tenant_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "organizations_tenant_id_slug_key" ON "organizations"("tenant_id", "slug");

-- CreateIndex
CREATE INDEX "roles_organization_id_idx" ON "roles"("organization_id");

-- CreateIndex
CREATE INDEX "roles_tenant_id_organization_id_created_at_idx" ON "roles"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "roles_tenant_id_organization_id_id_key" ON "roles"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "roles_tenant_id_organization_id_name_key" ON "roles"("tenant_id", "organization_id", "name");

-- CreateIndex
CREATE INDEX "role_permissions_organization_id_idx" ON "role_permissions"("organization_id");

-- CreateIndex
CREATE INDEX "role_permissions_tenant_id_organization_id_created_at_idx" ON "role_permissions"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "role_permissions_tenant_id_organization_id_id_key" ON "role_permissions"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "role_permissions_tenant_id_organization_id_role_id_per_1788d5be" ON "role_permissions"("tenant_id", "organization_id", "role_id", "permission_id");

-- CreateIndex
CREATE INDEX "memberships_organization_id_idx" ON "memberships"("organization_id");

-- CreateIndex
CREATE INDEX "memberships_tenant_id_organization_id_created_at_idx" ON "memberships"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "memberships_user_id_status_idx" ON "memberships"("user_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "memberships_tenant_id_organization_id_id_key" ON "memberships"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "memberships_tenant_id_organization_id_user_id_key" ON "memberships"("tenant_id", "organization_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "memberships_organization_id_user_id_key" ON "memberships"("organization_id", "user_id");

-- CreateIndex
CREATE INDEX "organization_settings_organization_id_idx" ON "organization_settings"("organization_id");

-- CreateIndex
CREATE INDEX "organization_settings_tenant_id_organization_id_created_at_idx" ON "organization_settings"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "organization_settings_tenant_id_organization_id_id_key" ON "organization_settings"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "organization_settings_tenant_id_organization_id_key" ON "organization_settings"("tenant_id", "organization_id");

-- CreateIndex
CREATE INDEX "number_sequences_organization_id_idx" ON "number_sequences"("organization_id");

-- CreateIndex
CREATE INDEX "number_sequences_tenant_id_organization_id_created_at_idx" ON "number_sequences"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "number_sequences_tenant_id_organization_id_id_key" ON "number_sequences"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "number_sequences_tenant_id_organization_id_type_key" ON "number_sequences"("tenant_id", "organization_id", "type");

-- CreateIndex
CREATE INDEX "units_organization_id_idx" ON "units"("organization_id");

-- CreateIndex
CREATE INDEX "units_tenant_id_organization_id_created_at_idx" ON "units"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "units_tenant_id_organization_id_id_key" ON "units"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "units_tenant_id_organization_id_code_key" ON "units"("tenant_id", "organization_id", "code");

-- CreateIndex
CREATE INDEX "suppliers_organization_id_idx" ON "suppliers"("organization_id");

-- CreateIndex
CREATE INDEX "suppliers_tenant_id_organization_id_created_at_idx" ON "suppliers"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "suppliers_tenant_id_organization_id_status_idx" ON "suppliers"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE INDEX "suppliers_tenant_id_organization_id_name_idx" ON "suppliers"("tenant_id", "organization_id", "name");

-- CreateIndex
CREATE UNIQUE INDEX "suppliers_tenant_id_organization_id_id_key" ON "suppliers"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "customers_organization_id_idx" ON "customers"("organization_id");

-- CreateIndex
CREATE INDEX "customers_tenant_id_organization_id_created_at_idx" ON "customers"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "customers_tenant_id_organization_id_status_idx" ON "customers"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE INDEX "customers_tenant_id_organization_id_name_idx" ON "customers"("tenant_id", "organization_id", "name");

-- CreateIndex
CREATE UNIQUE INDEX "customers_tenant_id_organization_id_id_key" ON "customers"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "raw_materials_organization_id_idx" ON "raw_materials"("organization_id");

-- CreateIndex
CREATE INDEX "raw_materials_tenant_id_organization_id_created_at_idx" ON "raw_materials"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "raw_materials_tenant_id_organization_id_status_idx" ON "raw_materials"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "raw_materials_tenant_id_organization_id_id_key" ON "raw_materials"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "raw_materials_tenant_id_organization_id_sku_key" ON "raw_materials"("tenant_id", "organization_id", "sku");

-- CreateIndex
CREATE INDEX "products_organization_id_idx" ON "products"("organization_id");

-- CreateIndex
CREATE INDEX "products_tenant_id_organization_id_created_at_idx" ON "products"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "products_tenant_id_organization_id_status_idx" ON "products"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "products_tenant_id_organization_id_id_key" ON "products"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "products_tenant_id_organization_id_sku_key" ON "products"("tenant_id", "organization_id", "sku");

-- CreateIndex
CREATE INDEX "warehouses_organization_id_idx" ON "warehouses"("organization_id");

-- CreateIndex
CREATE INDEX "warehouses_tenant_id_organization_id_created_at_idx" ON "warehouses"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "warehouses_tenant_id_organization_id_id_key" ON "warehouses"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "warehouses_tenant_id_organization_id_code_key" ON "warehouses"("tenant_id", "organization_id", "code");

-- CreateIndex
CREATE INDEX "expense_categories_organization_id_idx" ON "expense_categories"("organization_id");

-- CreateIndex
CREATE INDEX "expense_categories_tenant_id_organization_id_created_at_idx" ON "expense_categories"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "expense_categories_tenant_id_organization_id_id_key" ON "expense_categories"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "expense_categories_tenant_id_organization_id_name_key" ON "expense_categories"("tenant_id", "organization_id", "name");

-- CreateIndex
CREATE INDEX "purchase_orders_organization_id_idx" ON "purchase_orders"("organization_id");

-- CreateIndex
CREATE INDEX "purchase_orders_tenant_id_organization_id_created_at_idx" ON "purchase_orders"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "purchase_orders_tenant_id_organization_id_status_idx" ON "purchase_orders"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE INDEX "purchase_orders_tenant_id_organization_id_supplier_id__add865be" ON "purchase_orders"("tenant_id", "organization_id", "supplier_id", "order_date");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_orders_tenant_id_organization_id_id_key" ON "purchase_orders"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_orders_tenant_id_organization_id_purchase_ord_928cf608" ON "purchase_orders"("tenant_id", "organization_id", "purchase_order_number");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_orders_tenant_id_organization_id_id_supplier_id_key" ON "purchase_orders"("tenant_id", "organization_id", "id", "supplier_id");

-- CreateIndex
CREATE INDEX "purchase_order_items_organization_id_idx" ON "purchase_order_items"("organization_id");

-- CreateIndex
CREATE INDEX "purchase_order_items_tenant_id_organization_id_created_at_idx" ON "purchase_order_items"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "purchase_order_items_tenant_id_organization_id_purchas_5c7d4456" ON "purchase_order_items"("tenant_id", "organization_id", "purchase_order_id");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_order_items_tenant_id_organization_id_id_key" ON "purchase_order_items"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "purchase_order_items_tenant_id_organization_id_id_purc_8d4031d4" ON "purchase_order_items"("tenant_id", "organization_id", "id", "purchase_order_id", "raw_material_id");

-- CreateIndex
CREATE INDEX "goods_receipts_organization_id_idx" ON "goods_receipts"("organization_id");

-- CreateIndex
CREATE INDEX "goods_receipts_tenant_id_organization_id_created_at_idx" ON "goods_receipts"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "goods_receipts_tenant_id_organization_id_supplier_id_r_c4e045df" ON "goods_receipts"("tenant_id", "organization_id", "supplier_id", "received_date");

-- CreateIndex
CREATE INDEX "goods_receipts_tenant_id_organization_id_status_idx" ON "goods_receipts"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "goods_receipts_tenant_id_organization_id_id_key" ON "goods_receipts"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "goods_receipts_tenant_id_organization_id_receipt_number_key" ON "goods_receipts"("tenant_id", "organization_id", "receipt_number");

-- CreateIndex
CREATE UNIQUE INDEX "goods_receipts_tenant_id_organization_id_id_purchase_o_323cfc87" ON "goods_receipts"("tenant_id", "organization_id", "id", "purchase_order_id");

-- CreateIndex
CREATE INDEX "goods_receipt_items_organization_id_idx" ON "goods_receipt_items"("organization_id");

-- CreateIndex
CREATE INDEX "goods_receipt_items_tenant_id_organization_id_created_at_idx" ON "goods_receipt_items"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "goods_receipt_items_tenant_id_organization_id_goods_re_b7800a7e" ON "goods_receipt_items"("tenant_id", "organization_id", "goods_receipt_id");

-- CreateIndex
CREATE UNIQUE INDEX "goods_receipt_items_tenant_id_organization_id_id_key" ON "goods_receipt_items"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "supplier_invoices_organization_id_idx" ON "supplier_invoices"("organization_id");

-- CreateIndex
CREATE INDEX "supplier_invoices_tenant_id_organization_id_created_at_idx" ON "supplier_invoices"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "supplier_invoices_tenant_id_organization_id_status_idx" ON "supplier_invoices"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE INDEX "supplier_invoices_tenant_id_organization_id_supplier_i_9c0f7ce5" ON "supplier_invoices"("tenant_id", "organization_id", "supplier_id", "invoice_date");

-- CreateIndex
CREATE INDEX "supplier_invoices_tenant_id_organization_id_due_date_idx" ON "supplier_invoices"("tenant_id", "organization_id", "due_date");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_invoices_tenant_id_organization_id_id_key" ON "supplier_invoices"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_invoices_tenant_id_organization_id_supplier_i_c53c7781" ON "supplier_invoices"("tenant_id", "organization_id", "supplier_id", "supplier_invoice_number");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_invoices_tenant_id_organization_id_internal_r_574a801f" ON "supplier_invoices"("tenant_id", "organization_id", "internal_reference");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_invoices_tenant_id_organization_id_id_supplier_id_key" ON "supplier_invoices"("tenant_id", "organization_id", "id", "supplier_id");

-- CreateIndex
CREATE INDEX "supplier_invoice_items_organization_id_idx" ON "supplier_invoice_items"("organization_id");

-- CreateIndex
CREATE INDEX "supplier_invoice_items_tenant_id_organization_id_created_at_idx" ON "supplier_invoice_items"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "supplier_invoice_items_tenant_id_organization_id_suppl_d59d595d" ON "supplier_invoice_items"("tenant_id", "organization_id", "supplier_invoice_id");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_invoice_items_tenant_id_organization_id_id_key" ON "supplier_invoice_items"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "sales_orders_organization_id_idx" ON "sales_orders"("organization_id");

-- CreateIndex
CREATE INDEX "sales_orders_tenant_id_organization_id_created_at_idx" ON "sales_orders"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "sales_orders_tenant_id_organization_id_status_idx" ON "sales_orders"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE INDEX "sales_orders_tenant_id_organization_id_customer_id_ord_27e597ee" ON "sales_orders"("tenant_id", "organization_id", "customer_id", "order_date");

-- CreateIndex
CREATE UNIQUE INDEX "sales_orders_tenant_id_organization_id_id_key" ON "sales_orders"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "sales_orders_tenant_id_organization_id_order_number_key" ON "sales_orders"("tenant_id", "organization_id", "order_number");

-- CreateIndex
CREATE UNIQUE INDEX "sales_orders_tenant_id_organization_id_id_customer_id_key" ON "sales_orders"("tenant_id", "organization_id", "id", "customer_id");

-- CreateIndex
CREATE INDEX "sales_order_items_organization_id_idx" ON "sales_order_items"("organization_id");

-- CreateIndex
CREATE INDEX "sales_order_items_tenant_id_organization_id_created_at_idx" ON "sales_order_items"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "sales_order_items_tenant_id_organization_id_sales_order_id_idx" ON "sales_order_items"("tenant_id", "organization_id", "sales_order_id");

-- CreateIndex
CREATE UNIQUE INDEX "sales_order_items_tenant_id_organization_id_id_key" ON "sales_order_items"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "sales_order_items_tenant_id_organization_id_id_sales_o_8089db15" ON "sales_order_items"("tenant_id", "organization_id", "id", "sales_order_id", "product_id");

-- CreateIndex
CREATE INDEX "sales_invoices_organization_id_idx" ON "sales_invoices"("organization_id");

-- CreateIndex
CREATE INDEX "sales_invoices_tenant_id_organization_id_created_at_idx" ON "sales_invoices"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "sales_invoices_tenant_id_organization_id_status_idx" ON "sales_invoices"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE INDEX "sales_invoices_tenant_id_organization_id_customer_id_i_1b9816b5" ON "sales_invoices"("tenant_id", "organization_id", "customer_id", "invoice_date");

-- CreateIndex
CREATE INDEX "sales_invoices_tenant_id_organization_id_due_date_idx" ON "sales_invoices"("tenant_id", "organization_id", "due_date");

-- CreateIndex
CREATE UNIQUE INDEX "sales_invoices_tenant_id_organization_id_id_key" ON "sales_invoices"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "sales_invoices_tenant_id_organization_id_invoice_number_key" ON "sales_invoices"("tenant_id", "organization_id", "invoice_number");

-- CreateIndex
CREATE UNIQUE INDEX "sales_invoices_tenant_id_organization_id_id_customer_id_key" ON "sales_invoices"("tenant_id", "organization_id", "id", "customer_id");

-- CreateIndex
CREATE INDEX "sales_invoice_items_organization_id_idx" ON "sales_invoice_items"("organization_id");

-- CreateIndex
CREATE INDEX "sales_invoice_items_tenant_id_organization_id_created_at_idx" ON "sales_invoice_items"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "sales_invoice_items_tenant_id_organization_id_sales_in_c4bdb5f7" ON "sales_invoice_items"("tenant_id", "organization_id", "sales_invoice_id");

-- CreateIndex
CREATE UNIQUE INDEX "sales_invoice_items_tenant_id_organization_id_id_key" ON "sales_invoice_items"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "supplier_payments_organization_id_idx" ON "supplier_payments"("organization_id");

-- CreateIndex
CREATE INDEX "supplier_payments_tenant_id_organization_id_created_at_idx" ON "supplier_payments"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "supplier_payments_tenant_id_organization_id_supplier_i_78f75bdf" ON "supplier_payments"("tenant_id", "organization_id", "supplier_id", "payment_date");

-- CreateIndex
CREATE INDEX "supplier_payments_tenant_id_organization_id_status_idx" ON "supplier_payments"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_payments_tenant_id_organization_id_id_key" ON "supplier_payments"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_payments_tenant_id_organization_id_payment_number_key" ON "supplier_payments"("tenant_id", "organization_id", "payment_number");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_payments_tenant_id_organization_id_id_supplier_id_key" ON "supplier_payments"("tenant_id", "organization_id", "id", "supplier_id");

-- CreateIndex
CREATE INDEX "customer_payments_organization_id_idx" ON "customer_payments"("organization_id");

-- CreateIndex
CREATE INDEX "customer_payments_tenant_id_organization_id_created_at_idx" ON "customer_payments"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "customer_payments_tenant_id_organization_id_customer_i_4d277426" ON "customer_payments"("tenant_id", "organization_id", "customer_id", "payment_date");

-- CreateIndex
CREATE INDEX "customer_payments_tenant_id_organization_id_status_idx" ON "customer_payments"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "customer_payments_tenant_id_organization_id_id_key" ON "customer_payments"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "customer_payments_tenant_id_organization_id_payment_number_key" ON "customer_payments"("tenant_id", "organization_id", "payment_number");

-- CreateIndex
CREATE UNIQUE INDEX "customer_payments_tenant_id_organization_id_id_customer_id_key" ON "customer_payments"("tenant_id", "organization_id", "id", "customer_id");

-- CreateIndex
CREATE INDEX "supplier_payment_allocations_organization_id_idx" ON "supplier_payment_allocations"("organization_id");

-- CreateIndex
CREATE INDEX "supplier_payment_allocations_tenant_id_organization_id_36f4f01a" ON "supplier_payment_allocations"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "supplier_payment_allocations_tenant_id_organization_id_12dbdeb2" ON "supplier_payment_allocations"("tenant_id", "organization_id", "supplier_invoice_id");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_payment_allocations_tenant_id_organization_id_id_key" ON "supplier_payment_allocations"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_payment_allocations_tenant_id_organization_id_ad0c7874" ON "supplier_payment_allocations"("tenant_id", "organization_id", "supplier_payment_id", "supplier_invoice_id");

-- CreateIndex
CREATE INDEX "payment_schedules_organization_id_idx" ON "payment_schedules"("organization_id");

-- CreateIndex
CREATE INDEX "payment_schedules_tenant_id_organization_id_created_at_idx" ON "payment_schedules"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "payment_schedules_tenant_id_organization_id_id_key" ON "payment_schedules"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_schedules_tenant_id_organization_id_id_sales_i_a0106a16" ON "payment_schedules"("tenant_id", "organization_id", "id", "sales_invoice_id");

-- CreateIndex
CREATE INDEX "payment_installments_organization_id_idx" ON "payment_installments"("organization_id");

-- CreateIndex
CREATE INDEX "payment_installments_tenant_id_organization_id_created_at_idx" ON "payment_installments"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "payment_installments_tenant_id_organization_id_due_dat_c7496098" ON "payment_installments"("tenant_id", "organization_id", "due_date", "status");

-- CreateIndex
CREATE UNIQUE INDEX "payment_installments_tenant_id_organization_id_id_key" ON "payment_installments"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_installments_tenant_id_organization_id_id_sale_8d71e449" ON "payment_installments"("tenant_id", "organization_id", "id", "sales_invoice_id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_installments_tenant_id_organization_id_payment_d74bf7e0" ON "payment_installments"("tenant_id", "organization_id", "payment_schedule_id", "installment_number");

-- CreateIndex
CREATE INDEX "customer_payment_allocations_organization_id_idx" ON "customer_payment_allocations"("organization_id");

-- CreateIndex
CREATE INDEX "customer_payment_allocations_tenant_id_organization_id_9a14d81f" ON "customer_payment_allocations"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "customer_payment_allocations_tenant_id_organization_id_0d73f0e7" ON "customer_payment_allocations"("tenant_id", "organization_id", "sales_invoice_id");

-- CreateIndex
CREATE INDEX "customer_payment_allocations_tenant_id_organization_id_b0269f28" ON "customer_payment_allocations"("tenant_id", "organization_id", "customer_payment_id");

-- CreateIndex
CREATE UNIQUE INDEX "customer_payment_allocations_tenant_id_organization_id_id_key" ON "customer_payment_allocations"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "bills_of_material_organization_id_idx" ON "bills_of_material"("organization_id");

-- CreateIndex
CREATE INDEX "bills_of_material_tenant_id_organization_id_created_at_idx" ON "bills_of_material"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "bills_of_material_tenant_id_organization_id_id_key" ON "bills_of_material"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "bills_of_material_tenant_id_organization_id_product_id_9ba1135c" ON "bills_of_material"("tenant_id", "organization_id", "product_id", "version");

-- CreateIndex
CREATE UNIQUE INDEX "bills_of_material_tenant_id_organization_id_id_product_id_key" ON "bills_of_material"("tenant_id", "organization_id", "id", "product_id");

-- CreateIndex
CREATE INDEX "bill_of_material_items_organization_id_idx" ON "bill_of_material_items"("organization_id");

-- CreateIndex
CREATE INDEX "bill_of_material_items_tenant_id_organization_id_created_at_idx" ON "bill_of_material_items"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "bill_of_material_items_tenant_id_organization_id_id_key" ON "bill_of_material_items"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "bill_of_material_items_tenant_id_organization_id_bill__72a5e3fc" ON "bill_of_material_items"("tenant_id", "organization_id", "bill_of_material_id", "raw_material_id");

-- CreateIndex
CREATE INDEX "production_orders_organization_id_idx" ON "production_orders"("organization_id");

-- CreateIndex
CREATE INDEX "production_orders_tenant_id_organization_id_created_at_idx" ON "production_orders"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "production_orders_tenant_id_organization_id_status_idx" ON "production_orders"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "production_orders_tenant_id_organization_id_id_key" ON "production_orders"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "production_orders_tenant_id_organization_id_id_product_id_key" ON "production_orders"("tenant_id", "organization_id", "id", "product_id");

-- CreateIndex
CREATE UNIQUE INDEX "production_orders_tenant_id_organization_id_production_d620bdc2" ON "production_orders"("tenant_id", "organization_id", "production_number");

-- CreateIndex
CREATE INDEX "production_material_consumptions_organization_id_idx" ON "production_material_consumptions"("organization_id");

-- CreateIndex
CREATE INDEX "production_material_consumptions_tenant_id_organizatio_eaea0241" ON "production_material_consumptions"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "production_material_consumptions_tenant_id_organizatio_24902fa2" ON "production_material_consumptions"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "production_material_consumptions_tenant_id_organizatio_04b08faf" ON "production_material_consumptions"("tenant_id", "organization_id", "production_order_id", "raw_material_id");

-- CreateIndex
CREATE INDEX "production_outputs_organization_id_idx" ON "production_outputs"("organization_id");

-- CreateIndex
CREATE INDEX "production_outputs_tenant_id_organization_id_created_at_idx" ON "production_outputs"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "production_outputs_tenant_id_organization_id_productio_22089b54" ON "production_outputs"("tenant_id", "organization_id", "production_order_id");

-- CreateIndex
CREATE UNIQUE INDEX "production_outputs_tenant_id_organization_id_id_key" ON "production_outputs"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "expenses_organization_id_idx" ON "expenses"("organization_id");

-- CreateIndex
CREATE INDEX "expenses_tenant_id_organization_id_created_at_idx" ON "expenses"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "expenses_tenant_id_organization_id_expense_date_idx" ON "expenses"("tenant_id", "organization_id", "expense_date");

-- CreateIndex
CREATE INDEX "expenses_tenant_id_organization_id_status_idx" ON "expenses"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "expenses_tenant_id_organization_id_id_key" ON "expenses"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "expenses_tenant_id_organization_id_expense_number_key" ON "expenses"("tenant_id", "organization_id", "expense_number");

-- CreateIndex
CREATE INDEX "dispatches_organization_id_idx" ON "dispatches"("organization_id");

-- CreateIndex
CREATE INDEX "dispatches_tenant_id_organization_id_created_at_idx" ON "dispatches"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "dispatches_tenant_id_organization_id_status_idx" ON "dispatches"("tenant_id", "organization_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "dispatches_tenant_id_organization_id_id_key" ON "dispatches"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "dispatches_tenant_id_organization_id_dispatch_number_key" ON "dispatches"("tenant_id", "organization_id", "dispatch_number");

-- CreateIndex
CREATE UNIQUE INDEX "dispatches_tenant_id_organization_id_id_sales_order_id_key" ON "dispatches"("tenant_id", "organization_id", "id", "sales_order_id");

-- CreateIndex
CREATE INDEX "dispatch_items_organization_id_idx" ON "dispatch_items"("organization_id");

-- CreateIndex
CREATE INDEX "dispatch_items_tenant_id_organization_id_created_at_idx" ON "dispatch_items"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "dispatch_items_tenant_id_organization_id_dispatch_id_idx" ON "dispatch_items"("tenant_id", "organization_id", "dispatch_id");

-- CreateIndex
CREATE UNIQUE INDEX "dispatch_items_tenant_id_organization_id_id_key" ON "dispatch_items"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "inventory_movements_organization_id_idx" ON "inventory_movements"("organization_id");

-- CreateIndex
CREATE INDEX "inventory_movements_tenant_id_organization_id_created_at_idx" ON "inventory_movements"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "inventory_movements_tenant_id_organization_id_warehous_638f6b23" ON "inventory_movements"("tenant_id", "organization_id", "warehouse_id", "movement_date");

-- CreateIndex
CREATE INDEX "inventory_movements_tenant_id_organization_id_raw_mate_01d39da3" ON "inventory_movements"("tenant_id", "organization_id", "raw_material_id", "movement_date");

-- CreateIndex
CREATE INDEX "inventory_movements_tenant_id_organization_id_product__7919b56f" ON "inventory_movements"("tenant_id", "organization_id", "product_id", "movement_date");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_movements_tenant_id_organization_id_id_key" ON "inventory_movements"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_movements_tenant_id_organization_id_reversal_9dec0332" ON "inventory_movements"("tenant_id", "organization_id", "reversal_of_id");

-- CreateIndex
CREATE INDEX "inventory_balances_organization_id_idx" ON "inventory_balances"("organization_id");

-- CreateIndex
CREATE INDEX "inventory_balances_tenant_id_organization_id_created_at_idx" ON "inventory_balances"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_balances_tenant_id_organization_id_id_key" ON "inventory_balances"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "attachments_organization_id_idx" ON "attachments"("organization_id");

-- CreateIndex
CREATE INDEX "attachments_tenant_id_organization_id_created_at_idx" ON "attachments"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "attachments_tenant_id_organization_id_entity_type_entity_id_idx" ON "attachments"("tenant_id", "organization_id", "entity_type", "entity_id");

-- CreateIndex
CREATE UNIQUE INDEX "attachments_tenant_id_organization_id_id_key" ON "attachments"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "attachments_tenant_id_organization_id_stored_object_id_key" ON "attachments"("tenant_id", "organization_id", "stored_object_id");

-- CreateIndex
CREATE INDEX "audit_logs_organization_id_idx" ON "audit_logs"("organization_id");

-- CreateIndex
CREATE INDEX "audit_logs_tenant_id_organization_id_created_at_idx" ON "audit_logs"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_tenant_id_organization_id_entity_type_entit_4d0f7faf" ON "audit_logs"("tenant_id", "organization_id", "entity_type", "entity_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "audit_logs_tenant_id_organization_id_id_key" ON "audit_logs"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "notifications_organization_id_idx" ON "notifications"("organization_id");

-- CreateIndex
CREATE INDEX "notifications_tenant_id_organization_id_created_at_idx" ON "notifications"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE INDEX "notifications_tenant_id_organization_id_user_id_is_rea_520405a9" ON "notifications"("tenant_id", "organization_id", "user_id", "is_read", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_tenant_id_organization_id_id_key" ON "notifications"("tenant_id", "organization_id", "id");

-- CreateIndex
CREATE INDEX "stored_objects_organization_id_idx" ON "stored_objects"("organization_id");

-- CreateIndex
CREATE INDEX "stored_objects_tenant_id_organization_id_created_at_idx" ON "stored_objects"("tenant_id", "organization_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "stored_objects_tenant_id_organization_id_id_key" ON "stored_objects"("tenant_id", "organization_id", "id");

-- AddForeignKey
ALTER TABLE "tenant_branding" ADD CONSTRAINT "tenant_branding_tenant_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_tenant_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_country_fkey" FOREIGN KEY ("country_code") REFERENCES "countries"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "roles" ADD CONSTRAINT "roles_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_role_fkey" FOREIGN KEY ("tenant_id", "organization_id", "role_id") REFERENCES "roles"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_permission_fkey" FOREIGN KEY ("permission_id") REFERENCES "permissions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_user_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_role_fkey" FOREIGN KEY ("tenant_id", "organization_id", "role_id") REFERENCES "roles"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "memberships" ADD CONSTRAINT "memberships_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_settings" ADD CONSTRAINT "organization_settings_currency_fkey" FOREIGN KEY ("default_currency") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_settings" ADD CONSTRAINT "organization_settings_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_settings" ADD CONSTRAINT "organization_settings_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_settings" ADD CONSTRAINT "organization_settings_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "number_sequences" ADD CONSTRAINT "number_sequences_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "number_sequences" ADD CONSTRAINT "number_sequences_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "number_sequences" ADD CONSTRAINT "number_sequences_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "units" ADD CONSTRAINT "units_definition_fkey" FOREIGN KEY ("definition_id") REFERENCES "unit_definitions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "units" ADD CONSTRAINT "units_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "units" ADD CONSTRAINT "units_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "units" ADD CONSTRAINT "units_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "suppliers" ADD CONSTRAINT "suppliers_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "suppliers" ADD CONSTRAINT "suppliers_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "suppliers" ADD CONSTRAINT "suppliers_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "suppliers" ADD CONSTRAINT "suppliers_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "raw_materials" ADD CONSTRAINT "raw_materials_unit_fkey" FOREIGN KEY ("tenant_id", "organization_id", "unit_id") REFERENCES "units"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "raw_materials" ADD CONSTRAINT "raw_materials_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "raw_materials" ADD CONSTRAINT "raw_materials_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "raw_materials" ADD CONSTRAINT "raw_materials_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_unit_fkey" FOREIGN KEY ("tenant_id", "organization_id", "unit_id") REFERENCES "units"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "warehouses" ADD CONSTRAINT "warehouses_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "warehouses" ADD CONSTRAINT "warehouses_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "warehouses" ADD CONSTRAINT "warehouses_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expense_categories" ADD CONSTRAINT "expense_categories_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expense_categories" ADD CONSTRAINT "expense_categories_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expense_categories" ADD CONSTRAINT "expense_categories_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_supplier_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_id") REFERENCES "suppliers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_purchase_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "purchase_order_id") REFERENCES "purchase_orders"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_raw_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "raw_material_id") REFERENCES "raw_materials"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_purchase_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "purchase_order_id", "supplier_id") REFERENCES "purchase_orders"("tenant_id", "organization_id", "id", "supplier_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_supplier_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_id") REFERENCES "suppliers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_warehouse_fkey" FOREIGN KEY ("tenant_id", "organization_id", "warehouse_id") REFERENCES "warehouses"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "goods_receipt_items_goods_receipt_fkey" FOREIGN KEY ("tenant_id", "organization_id", "goods_receipt_id", "purchase_order_id") REFERENCES "goods_receipts"("tenant_id", "organization_id", "id", "purchase_order_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "goods_receipt_items_purchase_order_item_fkey" FOREIGN KEY ("tenant_id", "organization_id", "purchase_order_item_id", "purchase_order_id", "raw_material_id") REFERENCES "purchase_order_items"("tenant_id", "organization_id", "id", "purchase_order_id", "raw_material_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "goods_receipt_items_raw_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "raw_material_id") REFERENCES "raw_materials"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "goods_receipt_items_receipt_scope_fkey" FOREIGN KEY ("tenant_id", "organization_id", "goods_receipt_id") REFERENCES "goods_receipts"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "goods_receipt_items_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "goods_receipt_items_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "goods_receipt_items_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_supplier_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_id") REFERENCES "suppliers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_purchase_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "purchase_order_id", "supplier_id") REFERENCES "purchase_orders"("tenant_id", "organization_id", "id", "supplier_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoice_items" ADD CONSTRAINT "supplier_invoice_items_supplier_invoice_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_invoice_id") REFERENCES "supplier_invoices"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoice_items" ADD CONSTRAINT "supplier_invoice_items_raw_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "raw_material_id") REFERENCES "raw_materials"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoice_items" ADD CONSTRAINT "supplier_invoice_items_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoice_items" ADD CONSTRAINT "supplier_invoice_items_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_invoice_items" ADD CONSTRAINT "supplier_invoice_items_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_customer_fkey" FOREIGN KEY ("tenant_id", "organization_id", "customer_id") REFERENCES "customers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_sales_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "sales_order_id") REFERENCES "sales_orders"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_customer_fkey" FOREIGN KEY ("tenant_id", "organization_id", "customer_id") REFERENCES "customers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_sales_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "sales_order_id", "customer_id") REFERENCES "sales_orders"("tenant_id", "organization_id", "id", "customer_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_sales_invoice_fkey" FOREIGN KEY ("tenant_id", "organization_id", "sales_invoice_id") REFERENCES "sales_invoices"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_supplier_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_id") REFERENCES "suppliers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_customer_fkey" FOREIGN KEY ("tenant_id", "organization_id", "customer_id") REFERENCES "customers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payment_allocations" ADD CONSTRAINT "supplier_payment_allocations_supplier_payment_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_payment_id", "supplier_id") REFERENCES "supplier_payments"("tenant_id", "organization_id", "id", "supplier_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payment_allocations" ADD CONSTRAINT "supplier_payment_allocations_supplier_invoice_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_invoice_id", "supplier_id") REFERENCES "supplier_invoices"("tenant_id", "organization_id", "id", "supplier_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payment_allocations" ADD CONSTRAINT "supplier_payment_allocations_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payment_allocations" ADD CONSTRAINT "supplier_payment_allocations_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "supplier_payment_allocations" ADD CONSTRAINT "supplier_payment_allocations_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_schedules" ADD CONSTRAINT "payment_schedules_sales_invoice_fkey" FOREIGN KEY ("tenant_id", "organization_id", "sales_invoice_id") REFERENCES "sales_invoices"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_schedules" ADD CONSTRAINT "payment_schedules_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_schedules" ADD CONSTRAINT "payment_schedules_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_schedules" ADD CONSTRAINT "payment_schedules_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_installments" ADD CONSTRAINT "payment_installments_payment_schedule_fkey" FOREIGN KEY ("tenant_id", "organization_id", "payment_schedule_id", "sales_invoice_id") REFERENCES "payment_schedules"("tenant_id", "organization_id", "id", "sales_invoice_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_installments" ADD CONSTRAINT "payment_installments_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_installments" ADD CONSTRAINT "payment_installments_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "payment_installments" ADD CONSTRAINT "payment_installments_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payment_allocations" ADD CONSTRAINT "customer_payment_allocations_customer_payment_fkey" FOREIGN KEY ("tenant_id", "organization_id", "customer_payment_id", "customer_id") REFERENCES "customer_payments"("tenant_id", "organization_id", "id", "customer_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payment_allocations" ADD CONSTRAINT "customer_payment_allocations_sales_invoice_fkey" FOREIGN KEY ("tenant_id", "organization_id", "sales_invoice_id", "customer_id") REFERENCES "sales_invoices"("tenant_id", "organization_id", "id", "customer_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payment_allocations" ADD CONSTRAINT "customer_payment_allocations_payment_installment_fkey" FOREIGN KEY ("tenant_id", "organization_id", "payment_installment_id", "sales_invoice_id") REFERENCES "payment_installments"("tenant_id", "organization_id", "id", "sales_invoice_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payment_allocations" ADD CONSTRAINT "customer_payment_allocations_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payment_allocations" ADD CONSTRAINT "customer_payment_allocations_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "customer_payment_allocations" ADD CONSTRAINT "customer_payment_allocations_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bills_of_material" ADD CONSTRAINT "bills_of_material_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bills_of_material" ADD CONSTRAINT "bills_of_material_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bills_of_material" ADD CONSTRAINT "bills_of_material_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bills_of_material" ADD CONSTRAINT "bills_of_material_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bill_of_material_items" ADD CONSTRAINT "bill_of_material_items_bill_of_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "bill_of_material_id") REFERENCES "bills_of_material"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bill_of_material_items" ADD CONSTRAINT "bill_of_material_items_raw_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "raw_material_id") REFERENCES "raw_materials"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bill_of_material_items" ADD CONSTRAINT "bill_of_material_items_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bill_of_material_items" ADD CONSTRAINT "bill_of_material_items_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "bill_of_material_items" ADD CONSTRAINT "bill_of_material_items_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_warehouse_fkey" FOREIGN KEY ("tenant_id", "organization_id", "warehouse_id") REFERENCES "warehouses"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_bill_of_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "bill_of_material_id", "product_id") REFERENCES "bills_of_material"("tenant_id", "organization_id", "id", "product_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_material_consumptions" ADD CONSTRAINT "production_material_consumptions_production_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "production_order_id") REFERENCES "production_orders"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_material_consumptions" ADD CONSTRAINT "production_material_consumptions_raw_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "raw_material_id") REFERENCES "raw_materials"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_material_consumptions" ADD CONSTRAINT "production_material_consumptions_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_material_consumptions" ADD CONSTRAINT "production_material_consumptions_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_material_consumptions" ADD CONSTRAINT "production_material_consumptions_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_outputs" ADD CONSTRAINT "production_outputs_production_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "production_order_id", "product_id") REFERENCES "production_orders"("tenant_id", "organization_id", "id", "product_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_outputs" ADD CONSTRAINT "production_outputs_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_outputs" ADD CONSTRAINT "production_outputs_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_outputs" ADD CONSTRAINT "production_outputs_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "production_outputs" ADD CONSTRAINT "production_outputs_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_category_fkey" FOREIGN KEY ("tenant_id", "organization_id", "category_id") REFERENCES "expense_categories"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_supplier_fkey" FOREIGN KEY ("tenant_id", "organization_id", "supplier_id") REFERENCES "suppliers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_currency_fkey" FOREIGN KEY ("currency_code") REFERENCES "currencies"("code") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_sales_order_fkey" FOREIGN KEY ("tenant_id", "organization_id", "sales_order_id", "customer_id") REFERENCES "sales_orders"("tenant_id", "organization_id", "id", "customer_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_customer_fkey" FOREIGN KEY ("tenant_id", "organization_id", "customer_id") REFERENCES "customers"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_warehouse_fkey" FOREIGN KEY ("tenant_id", "organization_id", "warehouse_id") REFERENCES "warehouses"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_voided_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "voided_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatch_items" ADD CONSTRAINT "dispatch_items_dispatch_fkey" FOREIGN KEY ("tenant_id", "organization_id", "dispatch_id", "sales_order_id") REFERENCES "dispatches"("tenant_id", "organization_id", "id", "sales_order_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatch_items" ADD CONSTRAINT "dispatch_items_sales_order_item_fkey" FOREIGN KEY ("tenant_id", "organization_id", "sales_order_item_id", "sales_order_id", "product_id") REFERENCES "sales_order_items"("tenant_id", "organization_id", "id", "sales_order_id", "product_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatch_items" ADD CONSTRAINT "dispatch_items_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatch_items" ADD CONSTRAINT "dispatch_items_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatch_items" ADD CONSTRAINT "dispatch_items_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "dispatch_items" ADD CONSTRAINT "dispatch_items_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inventory_movements_warehouse_fkey" FOREIGN KEY ("tenant_id", "organization_id", "warehouse_id") REFERENCES "warehouses"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inventory_movements_raw_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "raw_material_id") REFERENCES "raw_materials"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inventory_movements_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inventory_movements_reversal_of_fkey" FOREIGN KEY ("tenant_id", "organization_id", "reversal_of_id") REFERENCES "inventory_movements"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inventory_movements_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_movements" ADD CONSTRAINT "inventory_movements_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_balances" ADD CONSTRAINT "inventory_balances_warehouse_fkey" FOREIGN KEY ("tenant_id", "organization_id", "warehouse_id") REFERENCES "warehouses"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_balances" ADD CONSTRAINT "inventory_balances_raw_material_fkey" FOREIGN KEY ("tenant_id", "organization_id", "raw_material_id") REFERENCES "raw_materials"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_balances" ADD CONSTRAINT "inventory_balances_product_fkey" FOREIGN KEY ("tenant_id", "organization_id", "product_id") REFERENCES "products"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "inventory_balances" ADD CONSTRAINT "inventory_balances_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "stored_objects" ADD CONSTRAINT "stored_objects_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "stored_objects" ADD CONSTRAINT "stored_objects_created_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "created_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "stored_objects" ADD CONSTRAINT "stored_objects_updated_by_member_fkey" FOREIGN KEY ("tenant_id", "organization_id", "updated_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_stored_object_fkey" FOREIGN KEY ("tenant_id", "organization_id", "stored_object_id") REFERENCES "stored_objects"("tenant_id", "organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_uploader_fkey" FOREIGN KEY ("tenant_id", "organization_id", "uploaded_by") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actor_fkey" FOREIGN KEY ("tenant_id", "organization_id", "user_id") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recipient_fkey" FOREIGN KEY ("tenant_id", "organization_id", "user_id") REFERENCES "memberships"("tenant_id", "organization_id", "user_id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_organization_fkey" FOREIGN KEY ("tenant_id", "organization_id") REFERENCES "organizations"("tenant_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

COMMIT;
