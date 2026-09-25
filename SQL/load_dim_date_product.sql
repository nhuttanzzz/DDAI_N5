/* ==========================================================================
   SCRIPT: Nạp dữ liệu vào DIM_DATE và DIM_PRODUCT
   Dự án : Data Warehouse - Star schema bán hàng (FACT_SALES)
   Nguồn : products_clean.csv (silver data). DIM_DATE tự sinh bằng recursive CTE.
   Mô tả : 1) Tạo bảng staging (stg_product)
           2) BULK INSERT dữ liệu CSV vào staging
           3) Tạo bảng dimension đích DIM_DATE, DIM_PRODUCT (nếu chưa tồn tại)
           4) Nạp dữ liệu từ staging/CTE sang dimension (ép kiểu, chuẩn hoá, chống trùng)
           5) Kiểm tra chất lượng dữ liệu sau khi nạp

   LƯU Ý: Sửa lại đường dẫn CSV ở bước 2 cho đúng với máy đang chạy script.
   ========================================================================== */

USE SalesDataWarehouse;
GO

-- ==========================================================================
-- BƯỚC 1: TẠO BẢNG STAGING (ánh xạ 1-1 với file CSV, drop & tạo lại mỗi lần chạy)
-- ==========================================================================
IF OBJECT_ID('dbo.stg_product', 'U') IS NOT NULL DROP TABLE dbo.stg_product;
CREATE TABLE dbo.stg_product (
    product_id    VARCHAR(20),
    product_name  VARCHAR(200),
    category      VARCHAR(100),
    segment       VARCHAR(100),
    size          VARCHAR(50),
    color         VARCHAR(50),
    price         VARCHAR(50),   -- nạp thô dạng text, ép kiểu ở bước 4
    cogs          VARCHAR(50)
);
GO

-- ==========================================================================
-- BƯỚC 2: NẠP FILE CSV VÀO STAGING
-- Sửa đường dẫn bên dưới cho khớp với máy đang chạy script
-- ==========================================================================
BULK INSERT dbo.stg_product
FROM 'D:\products_clean.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

-- ==========================================================================
-- BƯỚC 3: TẠO BẢNG DIMENSION ĐÍCH (chỉ tạo nếu chưa tồn tại, không mất dữ liệu khi rerun)
-- ==========================================================================
IF OBJECT_ID('dbo.DIM_DATE', 'U') IS NULL
CREATE TABLE dbo.DIM_DATE (
    date_key    INT NOT NULL PRIMARY KEY,
    full_date   DATE NOT NULL UNIQUE,
    [day]       INT,
    [month]     INT,
    quarter     INT,
    [year]      INT,
    day_name    VARCHAR(20),
    month_name  VARCHAR(20)
);

IF OBJECT_ID('dbo.DIM_PRODUCT', 'U') IS NULL
CREATE TABLE dbo.DIM_PRODUCT (
    product_key   INT IDENTITY(1,1) PRIMARY KEY,
    product_id    INT NOT NULL UNIQUE,
    product_name  VARCHAR(200) NOT NULL,
    category      VARCHAR(100),
    segment       VARCHAR(100),
    size          VARCHAR(50),
    color         VARCHAR(50),
    price         DECIMAL(18,2),
    cogs          DECIMAL(18,2)
);
GO

-- ==========================================================================
-- BƯỚC 4: NẠP DỮ LIỆU TỪ STAGING/CTE SANG DIMENSION
-- (ép kiểu, trim, chống trùng theo business key)
-- ==========================================================================

-- Nạp DIM_DATE trước (độc lập, sinh bằng recursive CTE, khớp range 2012-07-01 - 2022-12-31)
DECLARE @start_date DATE = '2012-07-01';
DECLARE @end_date   DATE = '2022-12-31';

;WITH DateSeq AS (
    SELECT @start_date AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date)
    FROM DateSeq
    WHERE full_date < @end_date
)
INSERT INTO dbo.DIM_DATE (date_key, full_date, [day], [month], quarter, [year], day_name, month_name)
SELECT
    CONVERT(INT, FORMAT(d.full_date, 'yyyyMMdd')),
    d.full_date,
    DAY(d.full_date),
    MONTH(d.full_date),
    DATEPART(QUARTER, d.full_date),
    YEAR(d.full_date),
    DATENAME(WEEKDAY, d.full_date),
    DATENAME(MONTH, d.full_date)
FROM DateSeq d
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DIM_DATE dd WHERE dd.full_date = d.full_date
)
OPTION (MAXRECURSION 0);
GO

-- Nạp DIM_PRODUCT (chống trùng theo product_id, bỏ qua dòng lỗi ép kiểu)
INSERT INTO dbo.DIM_PRODUCT (product_id, product_name, category, segment, size, color, price, cogs)
SELECT
    TRY_CAST(s.product_id AS INT),
    TRIM(s.product_name),
    TRIM(s.category),
    TRIM(s.segment),
    TRIM(s.size),
    TRIM(s.color),
    TRY_CAST(s.price AS DECIMAL(18,2)),
    TRY_CAST(s.cogs AS DECIMAL(18,2))
FROM dbo.stg_product s
WHERE TRY_CAST(s.product_id AS INT) IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM dbo.DIM_PRODUCT p WHERE p.product_id = TRY_CAST(s.product_id AS INT)
);
GO

-- ==========================================================================
-- BƯỚC 5: KIỂM TRA CHẤT LƯỢNG DỮ LIỆU SAU KHI NẠP
-- ==========================================================================

-- 5.1 Số dòng đã nạp (đối chiếu với số dòng thực tế trong file CSV)
SELECT 'DIM_DATE' AS table_name, COUNT(*) AS row_count FROM dbo.DIM_DATE
UNION ALL
SELECT 'DIM_PRODUCT', COUNT(*) FROM dbo.DIM_PRODUCT;

-- 5.2 Bản ghi bị NULL do ép kiểu lỗi (kỳ vọng: không có dòng nào)
SELECT * FROM dbo.DIM_PRODUCT WHERE product_id IS NULL OR price IS NULL OR cogs IS NULL;

-- 5.3 Trùng business key (kỳ vọng: không có dòng nào)
SELECT product_id, COUNT(*) AS so_lan
FROM dbo.DIM_PRODUCT
GROUP BY product_id
HAVING COUNT(*) > 1;

-- 5.4 Xem nhanh vài dòng dữ liệu để soát bằng mắt
SELECT TOP 5 * FROM dbo.DIM_DATE ORDER BY full_date;
SELECT TOP 5 * FROM dbo.DIM_PRODUCT;
