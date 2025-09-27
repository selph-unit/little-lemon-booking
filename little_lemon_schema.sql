-- ===================================================================
-- Little Lemon: Full Schema + Sample Data + Stored Procedures
-- Compatible with MySQL 8.x
-- ===================================================================

-- Create database
DROP DATABASE IF EXISTS little_lemon;
CREATE DATABASE little_lemon CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE little_lemon;

-- =========================
-- Core Tables
-- =========================

-- Customers
CREATE TABLE Customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name   VARCHAR(120) NOT NULL,
  phone       VARCHAR(30),
  email       VARCHAR(120),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Restaurant Tables
CREATE TABLE RestaurantTables (
  table_id  INT AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(20) NOT NULL UNIQUE,
  capacity  INT NOT NULL CHECK (capacity > 0)
);

-- Bookings
CREATE TABLE Bookings (
  booking_id       INT AUTO_INCREMENT PRIMARY KEY,
  customer_id      INT NOT NULL,
  table_id         INT NOT NULL,
  booking_datetime DATETIME NOT NULL,
  num_guests       INT NOT NULL CHECK (num_guests > 0),
  status           ENUM('Booked','Cancelled') NOT NULL DEFAULT 'Booked',
  notes            VARCHAR(255),
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_book_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
  CONSTRAINT fk_book_table    FOREIGN KEY (table_id)    REFERENCES RestaurantTables(table_id),
  CONSTRAINT uq_table_slot UNIQUE (table_id, booking_datetime)
);

-- Menu Items
CREATE TABLE MenuItems (
  item_id     INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  category    VARCHAR(50),
  price       DECIMAL(8,2) NOT NULL CHECK (price >= 0),
  is_active   TINYINT(1) DEFAULT 1
);

-- Orders (optional, useful for reporting)
CREATE TABLE Orders (
  order_id    INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  order_time  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total       DECIMAL(10,2) DEFAULT 0,
  CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

-- Order Items
-- NOTE: Generated columns in MySQL cannot reference another table. We keep unit_price here
-- and compute line_total = quantity * unit_price.
CREATE TABLE OrderItems (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id      INT NOT NULL,
  item_id       INT NOT NULL,
  quantity      INT NOT NULL CHECK (quantity > 0),
  unit_price    DECIMAL(10,2) NOT NULL,
  line_total    DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES Orders(order_id),
  CONSTRAINT fk_oi_item  FOREIGN KEY (item_id)  REFERENCES MenuItems(item_id)
);

-- Trigger: auto-fill unit_price from MenuItems if not provided
DELIMITER $$
DROP TRIGGER IF EXISTS bi_orderitems_unitprice $$
CREATE TRIGGER bi_orderitems_unitprice
BEFORE INSERT ON OrderItems
FOR EACH ROW
BEGIN
  IF NEW.unit_price IS NULL OR NEW.unit_price = 0 THEN
    SET NEW.unit_price = (SELECT price FROM MenuItems WHERE item_id = NEW.item_id);
  END IF;
END $$
DELIMITER ;

-- =========================
-- Sample Data
-- =========================
INSERT INTO Customers (full_name, phone, email) VALUES
('Aisha Noor',  '0500000001', 'aisha@example.com'),
('Omar Said',   '0500000002', 'omar@example.com'),
('Lina Haddad', '0500000003', 'lina@example.com');

INSERT INTO RestaurantTables (name, capacity) VALUES
('T1', 2), ('T2', 2), ('T3', 4), ('T4', 4), ('T5', 6);

INSERT INTO MenuItems (name, category, price) VALUES
('Margherita Pizza','Main',38.00),
('Lemon Pasta',     'Main',44.00),
('Greek Salad',     'Starter',22.00),
('Tiramisu',        'Dessert',20.00);

-- =========================
-- Stored Procedures
-- =========================
DELIMITER $$

-- 1) GetMaxQuantity: returns max quantity from OrderItems
DROP PROCEDURE IF EXISTS GetMaxQuantity $$
CREATE PROCEDURE GetMaxQuantity (OUT max_qty INT)
BEGIN
  SELECT IFNULL(MAX(quantity), 0) INTO max_qty FROM OrderItems;
END $$

-- Helper: find the smallest-capacity available table at exact datetime
DROP PROCEDURE IF EXISTS FindAvailableTable $$
CREATE PROCEDURE FindAvailableTable (
  IN  p_booking_datetime DATETIME,
  IN  p_num_guests INT,
  OUT p_table_id INT
)
BEGIN
  SELECT rt.table_id
    INTO p_table_id
  FROM RestaurantTables rt
  WHERE rt.capacity >= p_num_guests
    AND rt.table_id NOT IN (
      SELECT b.table_id
      FROM Bookings b
      WHERE b.booking_datetime = p_booking_datetime
        AND b.status = 'Booked'
    )
  ORDER BY rt.capacity ASC
  LIMIT 1;

  IF p_table_id IS NULL THEN
    SET p_table_id = -1;
  END IF;
END $$

-- 2) AddBooking: add booking if a table is available
DROP PROCEDURE IF EXISTS AddBooking $$
CREATE PROCEDURE AddBooking (
  IN  p_customer_id INT,
  IN  p_booking_datetime DATETIME,
  IN  p_num_guests INT,
  IN  p_notes VARCHAR(255),
  OUT p_booking_id INT
)
BEGIN
  DECLARE v_table_id INT;
  CALL FindAvailableTable(p_booking_datetime, p_num_guests, v_table_id);

  IF v_table_id = -1 THEN
    SET p_booking_id = -1;
  ELSE
    INSERT INTO Bookings (customer_id, table_id, booking_datetime, num_guests, notes)
    VALUES (p_customer_id, v_table_id, p_booking_datetime, p_num_guests, p_notes);
    SET p_booking_id = LAST_INSERT_ID();
  END IF;
END $$

-- 3) UpdateBooking: reschedule/resize and reassign table if needed
DROP PROCEDURE IF EXISTS UpdateBooking $$
CREATE PROCEDURE UpdateBooking (
  IN  p_booking_id INT,
  IN  p_new_datetime DATETIME,
  IN  p_new_num_guests INT,
  IN  p_new_notes VARCHAR(255),
  OUT p_success TINYINT
)
BEGIN
  DECLARE v_customer INT;
  DECLARE v_old_table INT;
  DECLARE v_new_table INT;

  SELECT customer_id, table_id INTO v_customer, v_old_table
  FROM Bookings WHERE booking_id = p_booking_id AND status = 'Booked';

  IF v_customer IS NULL THEN
    SET p_success = 0;
    LEAVE UpdateBooking;
  END IF;

  CALL FindAvailableTable(p_new_datetime, p_new_num_guests, v_new_table);

  IF v_new_table = -1 THEN
    SET v_new_table = v_old_table;
    IF EXISTS (
      SELECT 1 FROM Bookings
      WHERE table_id = v_new_table
        AND booking_datetime = p_new_datetime
        AND status = 'Booked'
        AND booking_id <> p_booking_id
    ) THEN
      SET p_success = 0;
      LEAVE UpdateBooking;
    END IF;
  END IF;

  UPDATE Bookings
     SET table_id = v_new_table,
         booking_datetime = p_new_datetime,
         num_guests = p_new_num_guests,
         notes = p_new_notes
   WHERE booking_id = p_booking_id;

  SET p_success = 1;
END $$

-- 4) CancelBooking: mark booking as Cancelled
DROP PROCEDURE IF EXISTS CancelBooking $$
CREATE PROCEDURE CancelBooking (
  IN p_booking_id INT,
  OUT p_success TINYINT
)
BEGIN
  UPDATE Bookings SET status = 'Cancelled' WHERE booking_id = p_booking_id;
  SET p_success = IF(ROW_COUNT() > 0, 1, 0);
END $$

-- 5) ManageBooking: unified entry point for ADD / UPDATE / CANCEL
DROP PROCEDURE IF EXISTS ManageBooking $$
CREATE PROCEDURE ManageBooking (
  IN  p_action ENUM('ADD','UPDATE','CANCEL'),
  IN  p_customer_id INT,
  IN  p_booking_id INT,
  IN  p_datetime DATETIME,
  IN  p_num_guests INT,
  IN  p_notes VARCHAR(255),
  OUT p_result_code INT
)
BEGIN
  /*
    p_result_code:
      >0 : booking_id (success)
       0 : success without id (e.g., CANCEL)
      -1 : no table available
      -2 : update failed
      -3 : cancel failed / not found
      -9 : unknown action
  */
  DECLARE v_id INT;
  DECLARE v_ok TINYINT;

  IF p_action = 'ADD' THEN
    CALL AddBooking(p_customer_id, p_datetime, p_num_guests, p_notes, v_id);
    SET p_result_code = v_id;

  ELSEIF p_action = 'UPDATE' THEN
    CALL UpdateBooking(p_booking_id, p_datetime, p_num_guests, p_notes, v_ok);
    SET p_result_code = IF(v_ok = 1, p_booking_id, -2);

  ELSEIF p_action = 'CANCEL' THEN
    CALL CancelBooking(p_booking_id, v_ok);
    SET p_result_code = IF(v_ok = 1, 0, -3);

  ELSE
    SET p_result_code = -9;
  END IF;
END $$

DELIMITER ;

-- =========================
-- Useful Indexes
-- =========================
CREATE INDEX idx_book_time   ON Bookings(booking_datetime);
CREATE INDEX idx_book_status ON Bookings(status);
