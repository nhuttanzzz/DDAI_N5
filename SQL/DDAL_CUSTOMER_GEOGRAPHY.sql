/* ==========================================================================
   SCRIPT: Nạp dữ liệu vào DIM_CUSTOMER và DIM_GEOGRAPHY
   Dự án : Data Warehouse - Star schema bán hàng (FACT_SALES)
   Nguồn : geography_clean.csv, customers_clean.csv (silver data)
   Mô tả : 1) Tạo bảng staging (stg_geography, stg_customer)
           2) BULK INSERT dữ liệu CSV vào staging
           3) Tạo bảng dimension đích DIM_GEOGRAPHY, DIM_CUSTOMER
           4) Nạp dữ liệu từ staging sang dimension (ép kiểu, chuẩn hoá, chống trùng)
           5) Kiểm tra chất lượng dữ liệu sau khi nạp

   LƯU Ý: Sửa lại đường dẫn CSV ở bước 2 cho đúng với máy đang chạy script.
   ========================================================================== */

-- ==========================================================================
-- BƯỚC 1: TẠO BẢNG STAGING (ánh xạ 1-1 với file CSV, drop & tạo lại mỗi lần chạy)
-- ==========================================================================
IF OBJECT_ID('dbo.stg_geography', 'U') IS NOT NULL DROP TABLE dbo.stg_geography;
CREATE TABLE dbo.stg_geography (
    zip      VARCHAR(10),
    city     VARCHAR(100),
    region   VARCHAR(50),
    district VARCHAR(50)
);

IF OBJECT_ID('dbo.stg_customer', 'U') IS NOT NULL DROP TABLE dbo.stg_customer;
CREATE TABLE dbo.stg_customer (
    customer_id          INT,
    zip                  VARCHAR(10),
    city                 VARCHAR(100),
    signup_date          VARCHAR(20),   -- nạp thô dạng text, ép kiểu ở bước 4
    gender               VARCHAR(20),
    age_group            VARCHAR(20),
    acquisition_channel  VARCHAR(30)
);
GO

-- ==========================================================================
-- BƯỚC 2: NẠP FILE CSV VÀO STAGING
-- Sửa đường dẫn bên dưới cho khớp với máy đang chạy script
-- ==========================================================================
BULK INSERT dbo.stg_geography
FROM 'D:\DDAL\Dữ liệu sạch - DDAL\geography_clean.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);

BULK INSERT dbo.stg_customer
FROM 'D:\DDAL\Dữ liệu sạch - DDAL\customers_clean.csv'
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
IF OBJECT_ID('dbo.DIM_GEOGRAPHY', 'U') IS NULL
CREATE TABLE dbo.DIM_GEOGRAPHY (
    geography_key INT IDENTITY(1,1) PRIMARY KEY,
    zip           INT NOT NULL UNIQUE,
    city          VARCHAR(100) NOT NULL,
    region        VARCHAR(50)  NOT NULL,
    district      VARCHAR(50)  NOT NULL
);

IF OBJECT_ID('dbo.DIM_CUSTOMER', 'U') IS NULL
CREATE TABLE dbo.DIM_CUSTOMER (
    customer_key         INT IDENTITY(1,1) PRIMARY KEY,
    customer_id          INT NOT NULL UNIQUE,
    signup_date          DATE NOT NULL,
    gender               VARCHAR(20),
    age_group            VARCHAR(20),
    acquisition_channel  VARCHAR(30)
);
GO

-- ==========================================================================
-- BƯỚC 4: NẠP DỮ LIỆU TỪ STAGING SANG DIMENSION
-- (ép kiểu, trim, chuẩn hoá chữ thường, chống trùng theo business key)
-- ==========================================================================

-- Nạp DIM_GEOGRAPHY trước (độc lập, không phụ thuộc bảng nào khác)
INSERT INTO dbo.DIM_GEOGRAPHY (zip, city, region, district)
SELECT DISTINCT
    TRY_CAST(s.zip AS INT),
    TRIM(s.city),
    TRIM(s.region),
    TRIM(s.district)
FROM dbo.stg_geography s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DIM_GEOGRAPHY g WHERE g.zip = TRY_CAST(s.zip AS INT)
);

-- Nạp DIM_CUSTOMER (chỉ 5 cột thuộc dimension này, bỏ zip/city vì thuộc DIM_GEOGRAPHY)
INSERT INTO dbo.DIM_CUSTOMER (customer_id, signup_date, gender, age_group, acquisition_channel)
SELECT
    s.customer_id,
    TRY_CONVERT(DATE, s.signup_date, 23),      -- 23 = yyyy-mm-dd
    LOWER(TRIM(s.gender)),
    TRIM(s.age_group),
    LOWER(TRIM(s.acquisition_channel))
FROM dbo.stg_customer s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DIM_CUSTOMER c WHERE c.customer_id = s.customer_id
);
GO

-- ==========================================================================
-- BƯỚC 5: KIỂM TRA CHẤT LƯỢNG DỮ LIỆU SAU KHI NẠP
-- ==========================================================================

-- 5.1 Số dòng đã nạp (đối chiếu với số dòng thực tế trong file CSV)
SELECT 'DIM_GEOGRAPHY' AS table_name, COUNT(*) AS row_count FROM dbo.DIM_GEOGRAPHY
UNION ALL
SELECT 'DIM_CUSTOMER', COUNT(*) FROM dbo.DIM_CUSTOMER;

-- 5.2 Bản ghi bị NULL do ép kiểu lỗi (kỳ vọng: không có dòng nào)
SELECT * FROM dbo.DIM_GEOGRAPHY WHERE zip IS NULL;
SELECT * FROM dbo.DIM_CUSTOMER  WHERE signup_date IS NULL;

-- 5.3 Trùng business key (kỳ vọng: không có dòng nào)
SELECT zip, COUNT(*) AS so_lan
FROM dbo.DIM_GEOGRAPHY
GROUP BY zip
HAVING COUNT(*) > 1;

SELECT customer_id, COUNT(*) AS so_lan
FROM dbo.DIM_CUSTOMER
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 5.4 Xem nhanh vài dòng dữ liệu để soát bằng mắt
SELECT TOP 5 * FROM dbo.DIM_GEOGRAPHY;
SELECT TOP 5 * FROM dbo.DIM_CUSTOMER;