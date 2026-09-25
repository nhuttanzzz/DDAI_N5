
-- =========================================
-- 1. TẠO DATABASE
-- =========================================
IF DB_ID('SalesDataWarehouse') IS NULL
BEGIN
    CREATE DATABASE SalesDataWarehouse;
END;
GO

USE SalesDataWarehouse;
GO

-- =========================================
-- 2. TẠO DIM_PROMOTION
-- =========================================
IF OBJECT_ID('dbo.DIM_PROMOTION', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DIM_PROMOTION
    (
        promotion_key INT IDENTITY(1,1) NOT NULL,
        promo_id VARCHAR(50) NOT NULL,
        promo_name NVARCHAR(255) NULL,
        promo_type NVARCHAR(100) NULL,
        discount_value DECIMAL(18,2) NULL,
        start_date DATE NULL,
        end_date DATE NULL,
        applicable_category NVARCHAR(255) NULL,
        promo_channel NVARCHAR(100) NULL,
        stackable_flag BIT NULL,
        min_order_value DECIMAL(18,2) NULL,

        CONSTRAINT PK_DIM_PROMOTION
            PRIMARY KEY (promotion_key),

        CONSTRAINT UQ_DIM_PROMOTION_PROMO_ID
            UNIQUE (promo_id)
    );
END;
GO

-- =========================================
-- 3. TẠO DIM_ORDER
-- =========================================
IF OBJECT_ID('dbo.DIM_ORDER', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DIM_ORDER
    (
        order_key INT IDENTITY(1,1) NOT NULL,
        order_id BIGINT NOT NULL,
        order_status NVARCHAR(100) NULL,
        payment_method NVARCHAR(100) NULL,
        device_type NVARCHAR(100) NULL,
        order_source NVARCHAR(100) NULL,
        comment NVARCHAR(MAX) NULL,

        CONSTRAINT PK_DIM_ORDER
            PRIMARY KEY (order_key),

        CONSTRAINT UQ_DIM_ORDER_ORDER_ID
            UNIQUE (order_id)
    );
END;
GO

USE SalesDataWarehouse;
GO

-- Kiểm tra số lượng bản ghi
SELECT COUNT(*) AS total_promotions
FROM dbo.DIM_PROMOTION;
SELECT COUNT(*) AS total_orders
FROM dbo.DIM_ORDER;

-- Xem dữ liệu Promotion
SELECT TOP 10 *
FROM dbo.DIM_PROMOTION
ORDER BY promotion_key;

-- Xem dữ liệu Order
SELECT TOP 10 *
FROM dbo.DIM_ORDER
ORDER BY order_key;