CREATE INDEX idx_orders_status_order_date
    ON orders (status, order_date DESC);
