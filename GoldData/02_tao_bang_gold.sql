/* BƯỚC 2: Chạy sau khi tạo database. Chưa cần import CSV. */
USE DW_Sales_Gold;
GO

IF OBJECT_ID(N'dbo.DIM_DATE', N'U') IS NULL
CREATE TABLE dbo.DIM_DATE (
    date_key INT NOT NULL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    [day] INT NOT NULL,
    [month] INT NOT NULL,
    [quarter] INT NOT NULL,
    [year] INT NOT NULL,
    day_name NVARCHAR(30),
    month_name NVARCHAR(30)
);
GO

IF OBJECT_ID(N'dbo.DIM_PRODUCT', N'U') IS NULL
CREATE TABLE dbo.DIM_PRODUCT (
    product_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    product_id INT NOT NULL UNIQUE,
    product_name NVARCHAR(255),
    category NVARCHAR(100),
    segment NVARCHAR(100),
    [size] NVARCHAR(100),
    color NVARCHAR(100),
    price DECIMAL(18,2),
    cogs DECIMAL(18,2)
);
GO

IF OBJECT_ID(N'dbo.DIM_CUSTOMER', N'U') IS NULL
CREATE TABLE dbo.DIM_CUSTOMER (
    customer_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id INT NOT NULL UNIQUE,
    signup_date DATE,
    gender NVARCHAR(50),
    age_group NVARCHAR(50),
    acquisition_channel NVARCHAR(100)
);
GO

IF OBJECT_ID(N'dbo.DIM_GEOGRAPHY', N'U') IS NULL
CREATE TABLE dbo.DIM_GEOGRAPHY (
    geography_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    zip INT NOT NULL UNIQUE,
    city NVARCHAR(100),
    region NVARCHAR(100),
    district NVARCHAR(100)
);
GO

IF OBJECT_ID(N'dbo.DIM_PROMOTION', N'U') IS NULL
CREATE TABLE dbo.DIM_PROMOTION (
    promotion_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    promo_id NVARCHAR(100) NOT NULL UNIQUE,
    promo_name NVARCHAR(255),
    promo_type NVARCHAR(100),
    discount_value DECIMAL(18,2),
    start_date DATE,
    end_date DATE,
    applicable_category NVARCHAR(100),
    promo_channel NVARCHAR(100),
    stackable_flag INT,
    min_order_value DECIMAL(18,2)
);
GO

IF OBJECT_ID(N'dbo.DIM_ORDER', N'U') IS NULL
CREATE TABLE dbo.DIM_ORDER (
    order_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    order_id INT NOT NULL UNIQUE,
    order_status NVARCHAR(100),
    payment_method NVARCHAR(100),
    device_type NVARCHAR(100),
    order_source NVARCHAR(100),
    [comment] NVARCHAR(MAX)
);
GO

IF OBJECT_ID(N'dbo.DIM_SALES_EMPLOYEE', N'U') IS NULL
CREATE TABLE dbo.DIM_SALES_EMPLOYEE (
    employee_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    sales_employee_id NVARCHAR(100) NOT NULL UNIQUE,
    sales_employee_name NVARCHAR(255),
    marital_status NVARCHAR(100),
    education_level NVARCHAR(100),
    years_experience INT
);
GO

IF OBJECT_ID(N'dbo.FACT_SALES', N'U') IS NULL
CREATE TABLE dbo.FACT_SALES (
    sales_key BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    date_key INT NOT NULL REFERENCES dbo.DIM_DATE(date_key),
    product_key INT NOT NULL REFERENCES dbo.DIM_PRODUCT(product_key),
    customer_key INT NOT NULL REFERENCES dbo.DIM_CUSTOMER(customer_key),
    geography_key INT NULL REFERENCES dbo.DIM_GEOGRAPHY(geography_key),
    promotion_key INT NULL REFERENCES dbo.DIM_PROMOTION(promotion_key),
    order_key INT NOT NULL REFERENCES dbo.DIM_ORDER(order_key),
    employee_key INT NULL REFERENCES dbo.DIM_SALES_EMPLOYEE(employee_key),
    order_item_id INT NOT NULL UNIQUE,
    quantity INT NOT NULL,
    unit_price DECIMAL(18,2) NOT NULL,
    discount_amount DECIMAL(18,2) NOT NULL,
    gross_revenue DECIMAL(18,2) NOT NULL,
    net_revenue DECIMAL(18,2) NOT NULL,
    cogs_amount DECIMAL(18,2) NOT NULL,
    profit_amount DECIMAL(18,2) NOT NULL
);
GO

SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='dbo' AND (TABLE_NAME LIKE 'DIM_%' OR TABLE_NAME='FACT_SALES')
ORDER BY TABLE_NAME;
GO
