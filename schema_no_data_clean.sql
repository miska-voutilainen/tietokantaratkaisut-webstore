
DROP TABLE IF EXISTS OrderItems;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS ProductCategories;
DROP TABLE IF EXISTS SupplierAddresses;
DROP TABLE IF EXISTS CustomerAddresses;
DROP TABLE IF EXISTS Suppliers;
DROP TABLE IF EXISTS Customers;

CREATE TABLE Customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(30)
);

CREATE TABLE Suppliers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(100),
    phone VARCHAR(30),
    email VARCHAR(255)
);

CREATE TABLE CustomerAddresses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    street_address VARCHAR(255) NOT NULL,
    postal_code VARCHAR(20),
    city VARCHAR(100) NOT NULL,
    country VARCHAR(100),
    CONSTRAINT fk_customeraddress_customer
        FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

-- SupplierAddresses
CREATE TABLE SupplierAddresses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    street_address VARCHAR(255) NOT NULL,
    postal_code VARCHAR(20),
    city VARCHAR(100) NOT NULL,
    country VARCHAR(100),
    CONSTRAINT fk_supplieraddress_supplier
        FOREIGN KEY (supplier_id) REFERENCES Suppliers(id)
);

CREATE TABLE ProductCategories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE Products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    category_id INT,
    supplier_id INT,
    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id) REFERENCES ProductCategories(id),
    CONSTRAINT fk_product_supplier
        FOREIGN KEY (supplier_id) REFERENCES Suppliers(id)
);

CREATE TABLE Orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivery_date DATETIME,
    shipping_address_id INT,
    status VARCHAR(50) DEFAULT 'NEW',
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES Customers(id),
    CONSTRAINT fk_order_shipping_address
        FOREIGN KEY (shipping_address_id) REFERENCES CustomerAddresses(id)
);

CREATE TABLE OrderItems (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_orderitem_order
        FOREIGN KEY (order_id) REFERENCES Orders(id),
    CONSTRAINT fk_orderitem_product
        FOREIGN KEY (product_id) REFERENCES Products(id)
);