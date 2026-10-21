-- Database defense in depth for the organization-scoped application client.
-- Migration/seed credentials are privileged and must never be used by the API.
BEGIN;

CREATE FUNCTION public.reject_immutable_change() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
BEGIN
  RAISE EXCEPTION '% is append-only; record a reversal instead', TG_TABLE_NAME USING ERRCODE = '23514';
END;
$$;

CREATE FUNCTION public.reject_financial_delete() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
BEGIN
  RAISE EXCEPTION '% cannot be hard-deleted; void or cancel the record', TG_TABLE_NAME USING ERRCODE = '23514';
END;
$$;

CREATE FUNCTION public.reject_scope_change() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
BEGIN
  IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id OR NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
    RAISE EXCEPTION 'Record ownership cannot be changed' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


ALTER TABLE "users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "users" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "users" USING (id = NULLIF(current_setting('app.user_id', true), '')::uuid) WITH CHECK (id = NULLIF(current_setting('app.user_id', true), '')::uuid);


ALTER TABLE "tenants" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "tenants" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "tenants" USING (id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "tenant_branding" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "tenant_branding" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "tenant_branding" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "organizations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "organizations" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "organizations" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "roles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "roles" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "roles" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "role_permissions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "role_permissions" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "role_permissions" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "memberships" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "memberships" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "memberships" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "organization_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "organization_settings" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "organization_settings" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "number_sequences" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "number_sequences" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "number_sequences" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "units" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "units" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "units" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "suppliers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "suppliers" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "suppliers" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "customers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "customers" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "customers" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "raw_materials" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "raw_materials" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "raw_materials" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "products" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "products" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "warehouses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "warehouses" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "warehouses" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "expense_categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "expense_categories" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "expense_categories" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "purchase_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "purchase_orders" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "purchase_orders" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "purchase_order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "purchase_order_items" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "purchase_order_items" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "goods_receipts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "goods_receipts" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "goods_receipts" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "goods_receipt_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "goods_receipt_items" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "goods_receipt_items" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "supplier_invoices" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "supplier_invoices" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "supplier_invoices" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "supplier_invoice_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "supplier_invoice_items" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "supplier_invoice_items" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "sales_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "sales_orders" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "sales_orders" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "sales_order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "sales_order_items" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "sales_order_items" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "sales_invoices" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "sales_invoices" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "sales_invoices" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "sales_invoice_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "sales_invoice_items" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "sales_invoice_items" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "supplier_payments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "supplier_payments" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "supplier_payments" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "customer_payments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "customer_payments" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "customer_payments" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "supplier_payment_allocations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "supplier_payment_allocations" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "supplier_payment_allocations" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "payment_schedules" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "payment_schedules" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "payment_schedules" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "payment_installments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "payment_installments" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "payment_installments" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "customer_payment_allocations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "customer_payment_allocations" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "customer_payment_allocations" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "bills_of_material" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "bills_of_material" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "bills_of_material" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "bill_of_material_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "bill_of_material_items" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "bill_of_material_items" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "production_orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "production_orders" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "production_orders" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "production_material_consumptions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "production_material_consumptions" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "production_material_consumptions" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "production_outputs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "production_outputs" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "production_outputs" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "expenses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "expenses" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "expenses" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "dispatches" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "dispatches" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "dispatches" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "dispatch_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "dispatch_items" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "dispatch_items" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "inventory_movements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "inventory_movements" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "inventory_movements" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "inventory_balances" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "inventory_balances" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "inventory_balances" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "stored_objects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "stored_objects" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "stored_objects" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "attachments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "attachments" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "attachments" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "audit_logs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "audit_logs" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "audit_logs" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


ALTER TABLE "notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "notifications" FORCE ROW LEVEL SECURITY;
CREATE POLICY scope_isolation ON "notifications" USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL) WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid AND organization_id = NULLIF(current_setting('app.organization_id', true), '')::uuid AND NULLIF(current_setting('app.user_id', true), '') IS NOT NULL);


CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "roles" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "role_permissions" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "memberships" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "organization_settings" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "number_sequences" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "units" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "suppliers" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "customers" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "raw_materials" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "products" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "warehouses" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "expense_categories" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "purchase_orders" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "purchase_order_items" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "goods_receipts" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "goods_receipt_items" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "supplier_invoices" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "supplier_invoice_items" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "sales_orders" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "sales_order_items" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "sales_invoices" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "sales_invoice_items" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "supplier_payments" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "customer_payments" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "supplier_payment_allocations" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "payment_schedules" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "payment_installments" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "customer_payment_allocations" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "bills_of_material" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "bill_of_material_items" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "production_orders" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "production_material_consumptions" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "production_outputs" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "expenses" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "dispatches" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "dispatch_items" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "inventory_movements" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "inventory_balances" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "stored_objects" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "attachments" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "audit_logs" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER ownership_immutable BEFORE UPDATE ON "notifications" FOR EACH ROW EXECUTE FUNCTION public.reject_scope_change();

CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON "audit_logs" FOR EACH ROW EXECUTE FUNCTION public.reject_immutable_change();

CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON "inventory_movements" FOR EACH ROW EXECUTE FUNCTION public.reject_immutable_change();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "purchase_orders" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "goods_receipts" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "supplier_invoices" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "supplier_payments" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "supplier_payment_allocations" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "sales_orders" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "sales_invoices" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "customer_payments" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "customer_payment_allocations" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "payment_schedules" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "payment_installments" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "production_orders" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "dispatches" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

CREATE TRIGGER preserve_financial_history BEFORE DELETE ON "expenses" FOR EACH ROW EXECUTE FUNCTION public.reject_financial_delete();

ALTER TABLE "users" ADD CONSTRAINT "active_user_has_password" CHECK (status <> 'ACTIVE' OR (password_hash IS NOT NULL AND length(password_hash) > 0));

ALTER TABLE "organization_settings" ADD CONSTRAINT "settings_payment_terms_nonnegative" CHECK (default_payment_terms_days >= 0);

ALTER TABLE "number_sequences" ADD CONSTRAINT "sequence_valid_counter" CHECK (current_number >= 0 AND padding BETWEEN 1 AND 20 AND length(prefix) > 0);

ALTER TABLE "suppliers" ADD CONSTRAINT "suppliers_terms_nonnegative" CHECK (payment_terms_days >= 0);

ALTER TABLE "customers" ADD CONSTRAINT "customers_terms_nonnegative" CHECK (payment_terms_days >= 0);

ALTER TABLE "customers" ADD CONSTRAINT "customer_credit_limit_nonnegative" CHECK (credit_limit >= 0);

ALTER TABLE "raw_materials" ADD CONSTRAINT "raw_materials_stock_cost_nonnegative" CHECK (minimum_stock_level >= 0 AND standard_cost >= 0);

ALTER TABLE "products" ADD CONSTRAINT "products_stock_cost_nonnegative" CHECK (minimum_stock_level >= 0 AND standard_cost >= 0);

ALTER TABLE "raw_materials" ADD CONSTRAINT "material_cost_reorder_nonnegative" CHECK (reorder_level >= 0 AND last_purchase_cost >= 0);

ALTER TABLE "products" ADD CONSTRAINT "product_price_nonnegative" CHECK (selling_price >= 0);

ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_totals_valid" CHECK (subtotal >= 0 AND discount >= 0 AND discount <= subtotal AND tax >= 0 AND total >= 0 AND total = subtotal - discount + tax);

ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_totals_valid" CHECK (subtotal >= 0 AND discount >= 0 AND discount <= subtotal AND tax >= 0 AND total >= 0 AND total = subtotal - discount + tax);

ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_totals_valid" CHECK (subtotal >= 0 AND discount >= 0 AND discount <= subtotal AND tax >= 0 AND total >= 0 AND total = subtotal - discount + tax);

ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_totals_valid" CHECK (subtotal >= 0 AND discount >= 0 AND discount <= subtotal AND tax >= 0 AND total >= 0 AND total = subtotal - discount + tax);

ALTER TABLE "purchase_order_items" ADD CONSTRAINT "purchase_order_items_amounts_valid" CHECK (quantity > 0 AND unit_price >= 0 AND discount >= 0 AND discount <= round(quantity * unit_price, 2) AND tax >= 0 AND line_total >= 0 AND line_total = round(quantity * unit_price, 2) - discount + tax);

ALTER TABLE "supplier_invoice_items" ADD CONSTRAINT "supplier_invoice_items_amounts_valid" CHECK (quantity > 0 AND unit_price >= 0 AND discount >= 0 AND discount <= round(quantity * unit_price, 2) AND tax >= 0 AND line_total >= 0 AND line_total = round(quantity * unit_price, 2) - discount + tax);

ALTER TABLE "sales_order_items" ADD CONSTRAINT "sales_order_items_amounts_valid" CHECK (quantity > 0 AND unit_price >= 0 AND discount >= 0 AND discount <= round(quantity * unit_price, 2) AND tax >= 0 AND line_total >= 0 AND line_total = round(quantity * unit_price, 2) - discount + tax);

ALTER TABLE "sales_invoice_items" ADD CONSTRAINT "sales_invoice_items_amounts_valid" CHECK (quantity > 0 AND unit_price >= 0 AND discount >= 0 AND discount <= round(quantity * unit_price, 2) AND tax >= 0 AND line_total >= 0 AND line_total = round(quantity * unit_price, 2) - discount + tax);

ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_amount_positive" CHECK (amount > 0);

ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_amount_positive" CHECK (amount > 0);

ALTER TABLE "supplier_payment_allocations" ADD CONSTRAINT "supplier_payment_allocations_amount_positive" CHECK (amount > 0);

ALTER TABLE "customer_payment_allocations" ADD CONSTRAINT "customer_payment_allocations_amount_positive" CHECK (amount > 0);

ALTER TABLE "expenses" ADD CONSTRAINT "expenses_amount_positive" CHECK (amount > 0);

ALTER TABLE "payment_installments" ADD CONSTRAINT "payment_installments_amount_positive" CHECK (amount > 0);

ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_dates_valid" CHECK (due_date >= invoice_date);

ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_dates_valid" CHECK (due_date >= invoice_date);

ALTER TABLE "supplier_invoices" ADD CONSTRAINT "supplier_invoices_void_reason_required" CHECK (status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "sales_invoices" ADD CONSTRAINT "sales_invoices_void_reason_required" CHECK (status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_void_reason_required" CHECK (status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_void_reason_required" CHECK (status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "expenses" ADD CONSTRAINT "expenses_void_reason_required" CHECK (status <> 'VOID' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "purchase_orders" ADD CONSTRAINT "purchase_orders_cancellation_reason" CHECK (status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "sales_orders" ADD CONSTRAINT "sales_orders_cancellation_reason" CHECK (status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "goods_receipts" ADD CONSTRAINT "goods_receipts_cancellation_reason" CHECK (status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "production_orders" ADD CONSTRAINT "production_orders_cancellation_reason" CHECK (status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "dispatches" ADD CONSTRAINT "dispatches_cancellation_reason" CHECK (status <> 'CANCELLED' OR (voided_at IS NOT NULL AND voided_by IS NOT NULL AND length(btrim(void_reason)) > 0));

ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "receipt_quantity_positive" CHECK (quantity_received > 0);

ALTER TABLE "goods_receipt_items" ADD CONSTRAINT "receipt_item_purchase_link" CHECK ((purchase_order_item_id IS NULL) = (purchase_order_id IS NULL));

ALTER TABLE "payment_schedules" ADD CONSTRAINT "schedule_values_positive" CHECK (number_of_installments > 0 AND scheduled_amount > 0);

ALTER TABLE "payment_installments" ADD CONSTRAINT "installment_number_positive" CHECK (installment_number > 0);

ALTER TABLE "inventory_movements" ADD CONSTRAINT "inventory_movements_exactly_one_item" CHECK ((item_type = 'RAW_MATERIAL' AND raw_material_id IS NOT NULL AND product_id IS NULL) OR (item_type = 'PRODUCT' AND product_id IS NOT NULL AND raw_material_id IS NULL));

ALTER TABLE "inventory_balances" ADD CONSTRAINT "inventory_balances_exactly_one_item" CHECK ((item_type = 'RAW_MATERIAL' AND raw_material_id IS NOT NULL AND product_id IS NULL) OR (item_type = 'PRODUCT' AND product_id IS NOT NULL AND raw_material_id IS NULL));

ALTER TABLE "inventory_movements" ADD CONSTRAINT "movement_values_valid" CHECK (quantity > 0 AND unit_cost >= 0 AND reversal_of_id IS DISTINCT FROM id);

ALTER TABLE "inventory_balances" ADD CONSTRAINT "reservation_values_valid" CHECK (quantity_reserved >= 0 AND quantity_reserved <= GREATEST(quantity_on_hand, 0));

ALTER TABLE "bills_of_material" ADD CONSTRAINT "bom_version_positive" CHECK (version > 0);

ALTER TABLE "bill_of_material_items" ADD CONSTRAINT "bom_quantity_wastage_valid" CHECK (quantity_required > 0 AND wastage_percentage >= 0 AND wastage_percentage <= 100);

ALTER TABLE "production_orders" ADD CONSTRAINT "production_quantities_valid" CHECK (planned_quantity > 0 AND actual_quantity >= 0);

ALTER TABLE "production_orders" ADD CONSTRAINT "production_dates_valid" CHECK ((planned_end_date IS NULL OR planned_start_date IS NULL OR planned_end_date >= planned_start_date) AND (actual_end_date IS NULL OR actual_start_date IS NULL OR actual_end_date >= actual_start_date));

ALTER TABLE "production_material_consumptions" ADD CONSTRAINT "consumption_quantities_valid" CHECK (planned_quantity > 0 AND actual_quantity >= 0);

ALTER TABLE "production_outputs" ADD CONSTRAINT "output_quantities_valid" CHECK (quantity_produced >= 0 AND quantity_rejected >= 0 AND quantity_rejected <= quantity_produced);

ALTER TABLE "dispatch_items" ADD CONSTRAINT "dispatch_quantity_positive" CHECK (quantity > 0);

ALTER TABLE "notifications" ADD CONSTRAINT "notification_entity_pair" CHECK ((entity_type IS NULL) = (entity_id IS NULL));


CREATE UNIQUE INDEX roles_default_code_unique ON roles (tenant_id, organization_id, code) WHERE code <> 'CUSTOM';
CREATE UNIQUE INDEX warehouse_one_default ON warehouses (tenant_id, organization_id) WHERE is_default AND deleted_at IS NULL AND status = 'ACTIVE';
CREATE UNIQUE INDEX schedule_one_active ON payment_schedules (tenant_id, organization_id, sales_invoice_id) WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX bom_one_active_version ON bills_of_material (tenant_id, organization_id, product_id) WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX inventory_balance_material_unique ON inventory_balances (tenant_id, organization_id, warehouse_id, raw_material_id) WHERE raw_material_id IS NOT NULL;
CREATE UNIQUE INDEX inventory_balance_product_unique ON inventory_balances (tenant_id, organization_id, warehouse_id, product_id) WHERE product_id IS NOT NULL;

CREATE FUNCTION public.validate_inventory_balance() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
DECLARE allow_negative boolean;
BEGIN
  SELECT allow_negative_stock INTO allow_negative FROM public.organization_settings
  WHERE tenant_id = NEW.tenant_id AND organization_id = NEW.organization_id;
  IF NEW.quantity_on_hand < 0 AND NOT COALESCE(allow_negative, false) THEN
    RAISE EXCEPTION 'Negative stock is disabled for this organization' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER inventory_nonnegative BEFORE INSERT OR UPDATE ON inventory_balances
FOR EACH ROW EXECUTE FUNCTION public.validate_inventory_balance();

CREATE FUNCTION public.validate_receipt_item_order() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
DECLARE header_order uuid;
BEGIN
  SELECT purchase_order_id INTO header_order FROM public.goods_receipts
  WHERE id = NEW.goods_receipt_id AND tenant_id = NEW.tenant_id AND organization_id = NEW.organization_id;
  IF NOT FOUND OR NEW.purchase_order_id IS DISTINCT FROM header_order THEN
    RAISE EXCEPTION 'Receipt item must refer to the header purchase order' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER receipt_order_consistency BEFORE INSERT OR UPDATE ON goods_receipt_items
FOR EACH ROW EXECUTE FUNCTION public.validate_receipt_item_order();

CREATE FUNCTION public.validate_attachment_target() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
DECLARE target_table text; present boolean;
BEGIN
  target_table := CASE NEW.entity_type
    WHEN 'SUPPLIER' THEN 'suppliers' WHEN 'CUSTOMER' THEN 'customers'
    WHEN 'RAW_MATERIAL' THEN 'raw_materials' WHEN 'PRODUCT' THEN 'products'
    WHEN 'PURCHASE_ORDER' THEN 'purchase_orders' WHEN 'SUPPLIER_INVOICE' THEN 'supplier_invoices'
    WHEN 'SUPPLIER_PAYMENT' THEN 'supplier_payments' WHEN 'SALES_ORDER' THEN 'sales_orders'
    WHEN 'SALES_INVOICE' THEN 'sales_invoices' WHEN 'CUSTOMER_PAYMENT' THEN 'customer_payments'
    WHEN 'DISPATCH' THEN 'dispatches' WHEN 'PRODUCTION_ORDER' THEN 'production_orders'
    WHEN 'EXPENSE' THEN 'expenses' END;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I WHERE id = $1 AND tenant_id = $2 AND organization_id = $3)', target_table)
    INTO present USING NEW.entity_id, NEW.tenant_id, NEW.organization_id;
  IF NOT present THEN
    RAISE EXCEPTION 'Attachment target must exist in the same organization' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER attachment_target_scope BEFORE INSERT OR UPDATE ON attachments
FOR EACH ROW EXECUTE FUNCTION public.validate_attachment_target();



CREATE VIEW customer_invoice_balances WITH (security_invoker = true) AS
SELECT i.tenant_id, i.organization_id, i.id AS invoice_id, i.customer_id,
       i.currency_code, i.total,
       COALESCE(paid.amount, 0) AS paid_amount,
       i.total - COALESCE(paid.amount, 0) AS balance_amount
FROM sales_invoices i
LEFT JOIN LATERAL (
  SELECT SUM(a.amount) AS amount
  FROM customer_payment_allocations a JOIN customer_payments p
    ON p.id = a.customer_payment_id AND p.tenant_id = a.tenant_id AND p.organization_id = a.organization_id
  WHERE a.sales_invoice_id = i.id AND a.tenant_id = i.tenant_id AND a.organization_id = i.organization_id
    AND p.status = 'POSTED'
) paid ON true
WHERE i.status NOT IN ('DRAFT', 'VOID');



CREATE VIEW supplier_invoice_balances WITH (security_invoker = true) AS
SELECT i.tenant_id, i.organization_id, i.id AS invoice_id, i.supplier_id,
       i.currency_code, i.total,
       COALESCE(paid.amount, 0) AS paid_amount,
       i.total - COALESCE(paid.amount, 0) AS balance_amount
FROM supplier_invoices i
LEFT JOIN LATERAL (
  SELECT SUM(a.amount) AS amount
  FROM supplier_payment_allocations a JOIN supplier_payments p
    ON p.id = a.supplier_payment_id AND p.tenant_id = a.tenant_id AND p.organization_id = a.organization_id
  WHERE a.supplier_invoice_id = i.id AND a.tenant_id = i.tenant_id AND a.organization_id = i.organization_id
    AND p.status = 'POSTED'
) paid ON true
WHERE i.status NOT IN ('DRAFT', 'VOID');



CREATE VIEW inventory_availability WITH (security_invoker = true) AS
SELECT tenant_id, organization_id, id, warehouse_id, item_type, raw_material_id, product_id,
       quantity_on_hand, quantity_reserved, quantity_on_hand - quantity_reserved AS quantity_available
FROM inventory_balances;

COMMIT;

