-- CHECK constraints must reject NULL explicitly; SQL otherwise accepts UNKNOWN.

BEGIN;

ALTER TABLE "supplier_invoices" DROP CONSTRAINT "supplier_invoices_void_reason_required";
ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_void_reason_required" CHECK (
 status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "sales_invoices" DROP CONSTRAINT "sales_invoices_void_reason_required";
ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_void_reason_required" CHECK (
 status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "supplier_payments" DROP CONSTRAINT "supplier_payments_void_reason_required";
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_void_reason_required" CHECK (
 status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "customer_payments" DROP CONSTRAINT "customer_payments_void_reason_required";
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_void_reason_required" CHECK (
 status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "expenses" DROP CONSTRAINT "expenses_void_reason_required";
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_void_reason_required" CHECK (
 status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "purchase_orders" DROP CONSTRAINT "purchase_orders_cancellation_reason";
ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_cancellation_reason" CHECK (
 status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "sales_orders" DROP CONSTRAINT "sales_orders_cancellation_reason";
ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_cancellation_reason" CHECK (
 status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "goods_receipts" DROP CONSTRAINT "goods_receipts_cancellation_reason";
ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_cancellation_reason" CHECK (
 status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "production_orders" DROP CONSTRAINT "production_orders_cancellation_reason";
ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_cancellation_reason" CHECK (
 status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

ALTER TABLE "dispatches" DROP CONSTRAINT "dispatches_cancellation_reason";
ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_cancellation_reason" CHECK (
 status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)
);

COMMIT;
