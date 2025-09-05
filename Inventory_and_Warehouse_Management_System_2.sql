USE inventory_db;
INSERT INTO suppliers (name, contact_name, phone, email, country)
VALUES
 ('Alpha Supplies','R. Mehta','+91-9876543210','alpha@example.com','India'),
 ('Global Parts','S. Rao','+91-9123456780','global@example.com','India');

INSERT INTO products (sku, name, description, unit, supplier_id, default_reorder_level)
VALUES
 ('SKU-001','USB Keyboard','Wired keyboard','pcs', 1, 20),
 ('SKU-002','Optical Mouse','USB mouse','pcs', 1, 15),
 ('SKU-003','HDMI Cable 1.5m','Video cable','pcs', 2, 25);

INSERT INTO warehouses (code, name, location)
VALUES
 ('WH-DEL','Delhi DC','Delhi'),
 ('WH-MUM','Mumbai DC','Mumbai');

INSERT INTO stock (warehouse_id, product_id, qty_on_hand, reorder_point, safety_stock)
SELECT w.warehouse_id, p.product_id,
       CASE p.sku
         WHEN 'SKU-001' THEN 50
         WHEN 'SKU-002' THEN 12
         WHEN 'SKU-003' THEN 8
       END AS qty_on_hand,
       NULL AS reorder_point,   -- use product default
       5    AS safety_stock
FROM warehouses w
CROSS JOIN products p
WHERE w.code IN ('WH-DEL','WH-MUM');


SELECT w.code, p.sku, s.qty_on_hand
FROM stock s
JOIN warehouses w USING (warehouse_id)
JOIN products p USING (product_id)
ORDER BY w.code, p.sku;

CREATE OR REPLACE VIEW v_stock_status AS
SELECT
  w.code            AS warehouse,
  p.sku, p.name     AS product,
  s.qty_on_hand,
  COALESCE(s.reorder_point, p.default_reorder_level) AS threshold,
  COALESCE(s.safety_stock, 0) AS safety_stock,
  CASE
    WHEN s.qty_on_hand <= COALESCE(s.reorder_point, p.default_reorder_level)
         THEN 'REORDER'
    ELSE 'OK'
  END AS status
FROM stock s
JOIN products p USING (product_id)
JOIN warehouses w USING (warehouse_id);

-- 4.1 Current levels
SELECT * FROM v_stock_status ORDER BY warehouse, sku;



-- 4.2 Items needing reorder (per warehouse)
SELECT * FROM v_stock_status WHERE status = 'REORDER' ORDER BY warehouse, sku;

-- 4.3 Supplier-wise reorder suggestion
SELECT
  sup.name AS supplier,
  w.code   AS warehouse,
  p.sku, p.name,
  s.qty_on_hand,
  COALESCE(s.reorder_point, p.default_reorder_level) AS threshold,
  GREATEST(
    (COALESCE(s.reorder_point, p.default_reorder_level) + COALESCE(s.safety_stock,0)) - s.qty_on_hand,
    0
  ) AS recommended_order_qty
FROM stock s
JOIN products p USING (product_id)
LEFT JOIN suppliers sup ON p.supplier_id = sup.supplier_id
JOIN warehouses w USING (warehouse_id)
WHERE s.qty_on_hand <= COALESCE(s.reorder_point, p.default_reorder_level)
ORDER BY supplier, warehouse, sku;

-- 4.4 Network total stock for a product
SELECT p.sku, p.name, SUM(s.qty_on_hand) AS total_qty
FROM stock s
JOIN products p USING (product_id)
WHERE p.sku = 'SKU-003'
GROUP BY p.sku, p.name;


DELIMITER //

CREATE TRIGGER trg_stock_ai_lowstock
AFTER INSERT ON stock
FOR EACH ROW
BEGIN
  DECLARE threshold INT;
  SELECT COALESCE(NEW.reorder_point, p.default_reorder_level)
    INTO threshold
  FROM products p
  WHERE p.product_id = NEW.product_id;

  IF NEW.qty_on_hand <= threshold THEN
    INSERT INTO low_stock_alerts (product_id, warehouse_id, qty_on_hand, threshold, is_open)
    VALUES (NEW.product_id, NEW.warehouse_id, NEW.qty_on_hand, threshold, 1)
    ON DUPLICATE KEY UPDATE
      qty_on_hand = VALUES(qty_on_hand),
      threshold   = VALUES(threshold);
  ELSE
    UPDATE low_stock_alerts
      SET is_open = 0, resolved_at = NOW()
    WHERE product_id = NEW.product_id
      AND warehouse_id = NEW.warehouse_id
      AND is_open = 1;
  END IF;
END//

CREATE TRIGGER trg_stock_au_lowstock
AFTER UPDATE ON stock
FOR EACH ROW
BEGIN
  DECLARE threshold INT;
  SELECT COALESCE(NEW.reorder_point, p.default_reorder_level)
    INTO threshold
  FROM products p
  WHERE p.product_id = NEW.product_id;

  IF NEW.qty_on_hand <= threshold THEN
    INSERT INTO low_stock_alerts (product_id, warehouse_id, qty_on_hand, threshold, is_open)
    VALUES (NEW.product_id, NEW.warehouse_id, NEW.qty_on_hand, threshold, 1)
    ON DUPLICATE KEY UPDATE
      qty_on_hand = VALUES(qty_on_hand),
      threshold   = VALUES(threshold);
  ELSE
    UPDATE low_stock_alerts
      SET is_open = 0, resolved_at = NOW()
    WHERE product_id = NEW.product_id
      AND warehouse_id = NEW.warehouse_id
      AND is_open = 1;
  END IF;
END//

DELIMITER ;

UPDATE stock s
JOIN products p ON p.product_id = s.product_id
JOIN warehouses w ON w.warehouse_id = s.warehouse_id
SET s.qty_on_hand = 3
WHERE p.sku = 'SKU-003' AND w.code = 'WH-DEL';

SELECT * FROM low_stock_alerts WHERE is_open = 1;