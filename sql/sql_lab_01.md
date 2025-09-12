# MariaDB Lab on SQLiteOnline

**Environment:** https://sqliteonline.com  
**Database Engine:** MariaDB - select the MariaDB on the left. It's a fork of MYSQL

> Before running a new step, **clear the editor** so old code doesn’t mix with new code.

---

## Step 1 — Start Clean

**What Happens:**  
This removes any leftover tables from previous runs. If they exist, they’ll be dropped; if they don’t, nothing breaks.

```sql
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
```
---

## Step 2 — Create the Tables

**What Happens:**  
This builds four tables that form a simple store system:

- `customers` — who places orders  
- `products` — what is for sale  
- `orders` — individual orders  
- `order_items` — which products are inside each order  

Foreign keys link them together so data stays consistent.

```sql
CREATE TABLE customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name   VARCHAR(100) NOT NULL,
  email       VARCHAR(255) NOT NULL UNIQUE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
  product_id   INT AUTO_INCREMENT PRIMARY KEY,
  product_name VARCHAR(100) NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  active       TINYINT(1) NOT NULL DEFAULT 1,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
  order_id    INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  status ENUM('PENDING','PAID','SHIPPED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id      INT NOT NULL,
  product_id    INT NOT NULL,
  quantity      INT NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
```
---

## Step 3 — Insert Sample Data

**What Happens:**  
Fills the tables with example data to practice with. Each table gets multiple rows so queries return meaningful results.

```sql
INSERT INTO customers (full_name, email) VALUES
('Alice Johnson', 'alice@example.com'),
('Bob Smith',     'bob@example.com'),
('Carla Gomez',   'carla@example.com'),
('Dan Lee',       'dan@example.com');

INSERT INTO products (product_name, unit_price, active) VALUES
('Mechanical Keyboard', 99.99, 1),
('Wireless Mouse',      29.50, 1),
('USB-C Cable',           9.99, 1),
('27-inch Monitor',    229.00, 1),
('Laptop Stand',        38.00, 1);

INSERT INTO orders (customer_id, status) VALUES
(1, 'PAID'),
(2, 'SHIPPED'),
(1, 'PENDING'),
(3, 'PAID');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 99.99),
(1, 3, 2,  9.99),
(2, 2, 1, 29.50),
(2, 5, 1, 38.00),
(3, 4, 1, 229.00),
(4, 3, 3,  9.99),
(4, 2, 2, 29.50);
```
---

## Step 4 — Sanity Check

**What Happens:**  
Pulls back all rows from every table so you can confirm data loaded correctly.

```sql
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM orders;
SELECT * FROM order_items;
```
---

## Step 5 — Order Totals by Order

**What Happens:**  
Joins three tables together and groups results by order. Calculates total price of each order by summing all its order_items.

```sql
SELECT 
  o.order_id,
  c.full_name,
  o.status,
  o.created_at,
  SUM(oi.quantity * oi.unit_price) AS order_total
FROM orders o
JOIN customers c  ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, c.full_name, o.status, o.created_at
ORDER BY o.order_id;
```

**Key Points**
- `o`, `c`, and `oi` are table aliases (short names).
- `JOIN` connects related rows from multiple tables.
- `SUM()` adds up the cost of all order items for each order.
- `GROUP BY` ensures one row per order.

---

## Step 6 — Revenue by Product

**What Happens:**  
Groups all order_items by product, counts how many sold, and totals the revenue from each.

```sql
SELECT
  p.product_name,
  SUM(oi.quantity) AS units_sold,
  SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY revenue DESC;
```
---

## Step 7 — Orders from One Customer

**What Happens:**  
Filters orders by a single customer’s email. Shows each order’s total amount.

```sql
SELECT
  c.full_name,
  o.order_id,
  o.status,
  SUM(oi.quantity * oi.unit_price) AS total
FROM customers c
JOIN orders o      ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
WHERE c.email = 'alice@example.com'
GROUP BY c.full_name, o.order_id, o.status
ORDER BY o.order_id;
```
---

## Step 8 — Delete with Cascade

**What Happens:**  
Removes order `3` from `orders`. Because of `ON DELETE CASCADE`, its rows in `order_items` are removed automatically too.

```sql
DELETE FROM orders WHERE order_id = 3;

SELECT * FROM orders;
SELECT * FROM order_items WHERE order_id = 3;
```
---

## Step 9 — Full Reset Script

**What Happens:**  
Drops all tables, recreates them, and reloads all starter data. Use this any time you want to start over.  
**Remember: clear the editor first before running this.**

```sql
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name   VARCHAR(100) NOT NULL,
  email       VARCHAR(255) NOT NULL UNIQUE,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
  product_id   INT AUTO_INCREMENT PRIMARY KEY,
  product_name VARCHAR(100) NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  active       TINYINT(1) NOT NULL DEFAULT 1,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
  order_id    INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  status ENUM('PENDING','PAID','SHIPPED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id      INT NOT NULL,
  product_id    INT NOT NULL,
  quantity      INT NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO customers (full_name, email) VALUES
('Alice Johnson', 'alice@example.com'),
('Bob Smith',     'bob@example.com'),
('Carla Gomez',   'carla@example.com'),
('Dan Lee',       'dan@example.com');

INSERT INTO products (product_name, unit_price, active) VALUES
('Mechanical Keyboard', 99.99, 1),
('Wireless Mouse',      29.50, 1),
('USB-C Cable',           9.99, 1),
('27-inch Monitor',    229.00, 1),
('Laptop Stand',        38.00, 1);

INSERT INTO orders (customer_id, status) VALUES
(1, 'PAID'),
(2, 'SHIPPED'),
(1, 'PENDING'),
(3, 'PAID');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 99.99),
(1, 3, 2,  9.99),
(2, 2, 1, 29.50),
(2, 5, 1, 38.00),
(3, 4, 1, 229.00),
(4, 3, 3,  9.99),
(4, 2, 2, 29.50);
```
---

**Tip:** When switching between steps in https://sqliteonline.com, click the trash/bin icon (or clear the editor) before pasting the next block so you don’t accidentally run old statements again.
