-- Stored Procedure: transfer_stock

use inventory_db;
DELIMITER //

CREATE PROCEDURE transfer_stock(
  IN p_product_id INT,
  IN p_from_wh INT,
  IN p_to_wh INT,
  IN p_qty INT,
  IN p_ref TEXT
)
BEGIN
  DECLARE current_qty INT;

  IF p_from_wh = p_to_wh THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Source and destination warehouses must be different';
  END IF;

  IF p_qty <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be positive';
  END IF;

  START TRANSACTION;

  -- Lock source row
  SELECT qty_on_hand INTO current_qty
  FROM stock
  WHERE warehouse_id = p_from_wh AND product_id = p_product_id
  FOR UPDATE;

  IF current_qty IS NULL THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Source stock row not found';
  END IF;

  IF current_qty < p_qty THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock at source warehouse';
  END IF;

  -- Deduct from source
  UPDATE stock
  SET qty_on_hand = qty_on_hand - p_qty
  WHERE warehouse_id = p_from_wh AND product_id = p_product_id;

  INSERT INTO stock_movements (product_id, warehouse_id, qty, movement_type, ref)
  VALUES (p_product_id, p_from_wh, p_qty, 'TRANSFER_OUT', p_ref);

  -- Upsert into destination
  INSERT INTO stock (warehouse_id, product_id, qty_on_hand)
  VALUES (p_to_wh, p_product_id, p_qty)
  ON DUPLICATE KEY UPDATE qty_on_hand = qty_on_hand + VALUES(qty_on_hand);

  INSERT INTO stock_movements (product_id, warehouse_id, qty, movement_type, ref)
  VALUES (p_product_id, p_to_wh, p_qty, 'TRANSFER_IN', p_ref);

  COMMIT;
END//

DELIMITER ;

SELECT product_id, sku FROM products;
SELECT warehouse_id, code FROM warehouses;

-- Example: move 30 units of SKU-001 from WH-DEL to WH-MUM
CALL transfer_stock(1, 1, 2, 30, 'Rebalance Aug 31, 2025');

-- Check results
SELECT * FROM v_stock_status WHERE sku='SKU-001' ORDER BY warehouse;
SELECT * FROM low_stock_alerts WHERE is_open = 1;
SELECT movement_type, warehouse_id, qty, created_at FROM stock_movements WHERE product_id=1 ORDER BY movement_id DESC;


-- 7.1 Top N low items
SELECT * FROM v_stock_status
ORDER BY status='REORDER' DESC, qty_on_hand ASC
LIMIT 10;

-- 7.2 Items below safety stock (extra strict)
SELECT
  w.code AS warehouse, p.sku, p.name, s.qty_on_hand, s.safety_stock
FROM stock s
JOIN products p USING(product_id)
JOIN warehouses w USING(warehouse_id)
WHERE s.safety_stock IS NOT NULL AND s.qty_on_hand < s.safety_stock
ORDER BY w.code, p.sku;

-- 7.3 Supplier purchase list with totals
SELECT
  sup.name AS supplier,
  p.sku, p.name,
  SUM(GREATEST((COALESCE(s.reorder_point, p.default_reorder_level) + COALESCE(s.safety_stock,0)) - s.qty_on_hand, 0)) AS total_recommended_qty
FROM stock s
JOIN products p USING(product_id)
LEFT JOIN suppliers sup ON p.supplier_id = sup.supplier_id
GROUP BY sup.name, p.sku, p.name
HAVING total_recommended_qty > 0
ORDER BY supplier, sku;