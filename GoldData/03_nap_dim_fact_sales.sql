/*
===============================================================================
03_NAP_DIM_FACT_SALES.sql
Muc dich:
  - Nap 6 bang CSV da import vao DW_Sales_Gold vao cac bang DIM.
  - Nap FACT_SALES voi muc chi tiet la 1 dong Order_Items_RD.
  - Kiem tra dong da nap, dong chua nap, ma khuyen mai va ZIP khong khop.

Cac bang nguon du kien theo ten file CSV:
  dbo.Orders_cleannew  <- Orders_cleannew.csv
  dbo.Order_Items_RD   <- Order_Items_RD.csv
  dbo.products         <- products.csv
  dbo.customer_clean   <- customer_clean.csv
  dbo.geography_clean  <- geography_clean.csv
  dbo.Promotions_RD    <- Promotions_RD.csv

Yeu cau:
  1. Da tao DW_Sales_Gold va cac bang DIM_*, FACT_SALES.
  2. Da import thanh cong ca 6 CSV vao cac bang nguon tren.
  3. Neu ban dat ten bang khac trong Import Flat File, sua ten bang trong script.

Luu y du lieu mau:
  - customer_clean co ZIP nhu 15201, 15202...
  - mau geography_clean ban gui co ZIP nhu 1, 2, 3...
  Neu du lieu that cung nhu vay, ZIP se khong JOIN duoc. Script se gan
  geography_key "Unknown" de khong lam mat dong fact, va truy van cuoi file
  se thong ke so ZIP khong khop. Can kiem tra lai file geography_clean.csv.
===============================================================================
*/

USE DW_Sales_Gold;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* 0. Kiem tra du 6 bang nguon */
IF OBJECT_ID(N'dbo.Orders_cleannew', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Order_Items_RD', N'U') IS NULL
   OR OBJECT_ID(N'dbo.products', N'U') IS NULL
   OR OBJECT_ID(N'dbo.customer_clean', N'U') IS NULL
   OR OBJECT_ID(N'dbo.geography_clean', N'U') IS NULL
   OR OBJECT_ID(N'dbo.Promotions_RD', N'U') IS NULL
BEGIN
    THROW 50001,
      N'Thieu bang nguon. Hay kiem tra ten 6 bang CSV trong Object Explorer va sua ten bang trong script.',
      1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* A. DIM_DATE: moi ngay dat hang chi co 1 dong */
    ;WITH DateSource AS
    (
        SELECT DISTINCT
            COALESCE(
                TRY_CONVERT(DATE, order_date, 101), -- M/D/YYYY
                TRY_CONVERT(DATE, order_date, 126), -- ISO datetime
                TRY_CONVERT(DATE, order_date, 23),  -- YYYY-MM-DD
                TRY_CONVERT(DATE, order_date)
            ) AS full_date
        FROM dbo.Orders_cleannew
    )
    INSERT INTO dbo.DIM_DATE
        (date_key, full_date, [day], [month], [quarter], [year], day_name, month_name)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), d.full_date, 112)),
        d.full_date,
        DAY(d.full_date),
        MONTH(d.full_date),
        DATEPART(QUARTER, d.full_date),
        YEAR(d.full_date),
        DATENAME(WEEKDAY, d.full_date),
        DATENAME(MONTH, d.full_date)
    FROM DateSource AS d
    WHERE d.full_date IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DIM_DATE AS target
          WHERE target.full_date = d.full_date
      );

    /* B. DIM_PRODUCT */
    ;WITH ProductSource AS
    (
        SELECT
            TRY_CONVERT(INT, product_id) AS natural_id,
            product_name,
            category,
            segment,
            [size],
            color,
            TRY_CONVERT(DECIMAL(18,2), price) AS price,
            TRY_CONVERT(DECIMAL(18,2), cogs) AS cogs,
            ROW_NUMBER() OVER
            (
                PARTITION BY TRY_CONVERT(INT, product_id)
                ORDER BY product_name
            ) AS rn
        FROM dbo.products
    )
    INSERT INTO dbo.DIM_PRODUCT
        (product_id, product_name, category, segment, [size], color, price, cogs)
    SELECT
        s.natural_id, s.product_name, s.category, s.segment,
        s.[size], s.color, s.price, s.cogs
    FROM ProductSource AS s
    WHERE s.natural_id IS NOT NULL
      AND s.rn = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DIM_PRODUCT AS target
          WHERE target.product_id = s.natural_id
      );

    /* C. DIM_CUSTOMER
       zip khong dua vao DIM_CUSTOMER theo ERD; zip duoc dung de tim DIM_GEOGRAPHY. */
    ;WITH CustomerSource AS
    (
        SELECT
            TRY_CONVERT(INT, customer_id) AS natural_id,
            COALESCE(
                TRY_CONVERT(DATE, signup_date, 101),
                TRY_CONVERT(DATE, signup_date, 126),
                TRY_CONVERT(DATE, signup_date, 23),
                TRY_CONVERT(DATE, signup_date)
            ) AS signup_dt,
            gender,
            age_group,
            acquisition_channel,
            ROW_NUMBER() OVER
            (
                PARTITION BY TRY_CONVERT(INT, customer_id)
                ORDER BY customer_id
            ) AS rn
        FROM dbo.customer_clean
    )
    INSERT INTO dbo.DIM_CUSTOMER
        (customer_id, signup_date, gender, age_group, acquisition_channel)
    SELECT
        s.natural_id, s.signup_dt, s.gender, s.age_group, s.acquisition_channel
    FROM CustomerSource AS s
    WHERE s.natural_id IS NOT NULL
      AND s.rn = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DIM_CUSTOMER AS target
          WHERE target.customer_id = s.natural_id
      );

    /* D. DIM_GEOGRAPHY: giu 1 dong cho moi ZIP */
    ;WITH GeographySource AS
    (
        SELECT
            TRY_CONVERT(INT, zip) AS natural_zip,
            city,
            region,
            district,
            ROW_NUMBER() OVER
            (
                PARTITION BY TRY_CONVERT(INT, zip)
                ORDER BY city, region, district
            ) AS rn
        FROM dbo.geography_clean
    )
    INSERT INTO dbo.DIM_GEOGRAPHY (zip, city, region, district)
    SELECT s.natural_zip, s.city, s.region, s.district
    FROM GeographySource AS s
    WHERE s.natural_zip IS NOT NULL
      AND s.rn = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DIM_GEOGRAPHY AS target
          WHERE target.zip = s.natural_zip
      );

    /* E. DIM_PROMOTION: promo_id la chuoi, khong ep sang INT */
    ;WITH PromotionSource AS
    (
        SELECT
            NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), promo_id))), N'') AS natural_id,
            promo_name,
            promo_type,
            TRY_CONVERT(DECIMAL(18,2), discount_value) AS discount_value,
            COALESCE(
                TRY_CONVERT(DATE, start_date, 126),
                TRY_CONVERT(DATE, start_date, 23),
                TRY_CONVERT(DATE, start_date)
            ) AS start_dt,
            COALESCE(
                TRY_CONVERT(DATE, end_date, 126),
                TRY_CONVERT(DATE, end_date, 23),
                TRY_CONVERT(DATE, end_date)
            ) AS end_dt,
            applicable_category,
            promo_channel,
            TRY_CONVERT(INT, stackable_flag) AS stackable_flag,
            TRY_CONVERT(DECIMAL(18,2), min_order_value) AS min_order_value,
            ROW_NUMBER() OVER
            (
                PARTITION BY NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), promo_id))), N'')
                ORDER BY promo_id
            ) AS rn
        FROM dbo.Promotions_RD
    )
    INSERT INTO dbo.DIM_PROMOTION
    (
        promo_id, promo_name, promo_type, discount_value, start_date, end_date,
        applicable_category, promo_channel, stackable_flag, min_order_value
    )
    SELECT
        s.natural_id, s.promo_name, s.promo_type, s.discount_value,
        s.start_dt, s.end_dt, s.applicable_category, s.promo_channel,
        s.stackable_flag, COALESCE(s.min_order_value, 0)
    FROM PromotionSource AS s
    WHERE s.natural_id IS NOT NULL
      AND s.rn = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DIM_PROMOTION AS target
          WHERE target.promo_id = s.natural_id
      );

    /* F. DIM_ORDER */
    ;WITH OrderSource AS
    (
        SELECT
            TRY_CONVERT(INT, order_id) AS natural_id,
            order_status,
            payment_method,
            device_type,
            order_source,
            [comment],
            COALESCE(
                TRY_CONVERT(DATETIME2, order_date, 101),
                TRY_CONVERT(DATETIME2, order_date, 126),
                TRY_CONVERT(DATETIME2, order_date, 23),
                TRY_CONVERT(DATETIME2, order_date)
            ) AS order_dt,
            ROW_NUMBER() OVER
            (
                PARTITION BY TRY_CONVERT(INT, order_id)
                ORDER BY
                    COALESCE(
                        TRY_CONVERT(DATETIME2, order_date, 101),
                        TRY_CONVERT(DATETIME2, order_date, 126),
                        TRY_CONVERT(DATETIME2, order_date, 23),
                        TRY_CONVERT(DATETIME2, order_date)
                    ) DESC
            ) AS rn
        FROM dbo.Orders_cleannew
    )
    INSERT INTO dbo.DIM_ORDER
        (order_id, order_status, payment_method, device_type, order_source, [comment])
    SELECT
        s.natural_id, s.order_status, s.payment_method,
        s.device_type, s.order_source, s.[comment]
    FROM OrderSource AS s
    WHERE s.natural_id IS NOT NULL
      AND s.rn = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DIM_ORDER AS target
          WHERE target.order_id = s.natural_id
      );

    /* G. DIM_SALES_EMPLOYEE
       sales_employee_id la ma chuoi, vi du EMP0103, EMP0180.
       Moi ma nhan vien chi nap 1 dong; lay thong tin tu don hang moi nhat. */
    ;WITH EmployeeSource AS
    (
        SELECT
            NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), sales_employee_id))), N'') AS natural_id,
            sales_employee_name,
            marital_status,
            education_level,
            TRY_CONVERT(INT, years_experience) AS years_experience,
            ROW_NUMBER() OVER
            (
                PARTITION BY NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), sales_employee_id))), N'')
                ORDER BY
                    COALESCE(
                        TRY_CONVERT(DATETIME2, order_date, 101),
                        TRY_CONVERT(DATETIME2, order_date, 126),
                        TRY_CONVERT(DATETIME2, order_date, 23),
                        TRY_CONVERT(DATETIME2, order_date)
                    ) DESC,
                    TRY_CONVERT(INT, order_id) DESC
            ) AS rn
        FROM dbo.Orders_cleannew
    )
    INSERT INTO dbo.DIM_SALES_EMPLOYEE
    (
        sales_employee_id, sales_employee_name, marital_status,
        education_level, years_experience
    )
    SELECT
        s.natural_id, s.sales_employee_name, s.marital_status,
        s.education_level, s.years_experience
    FROM EmployeeSource AS s
    WHERE s.natural_id IS NOT NULL
      AND s.rn = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.DIM_SALES_EMPLOYEE AS target
          WHERE target.sales_employee_id = s.natural_id
      );

    /* H. Tao cac dong Unknown.
       Neu ma san pham/khach hang/don hang/ngay khong tim thay, FACT_SALES
       van co the nap va gan vao dong Unknown thay vi lam mat dong ban hang. */
    IF NOT EXISTS (SELECT 1 FROM dbo.DIM_DATE WHERE date_key = 0)
    BEGIN
        INSERT INTO dbo.DIM_DATE
            (date_key, full_date, [day], [month], [quarter], [year], day_name, month_name)
        VALUES (0, '19000101', 0, 0, 0, 0, N'Unknown', N'Unknown');
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.DIM_PRODUCT WHERE product_id = -1)
    BEGIN
        INSERT INTO dbo.DIM_PRODUCT
            (product_id, product_name, category, segment, [size], color, price, cogs)
        VALUES (-1, N'Unknown product', N'Unknown', N'Unknown', N'Unknown', N'Unknown', 0, 0);
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.DIM_CUSTOMER WHERE customer_id = -1)
    BEGIN
        INSERT INTO dbo.DIM_CUSTOMER
            (customer_id, signup_date, gender, age_group, acquisition_channel)
        VALUES (-1, '19000101', N'Unknown', N'Unknown', N'Unknown');
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.DIM_ORDER WHERE order_id = -1)
    BEGIN
        INSERT INTO dbo.DIM_ORDER
            (order_id, order_status, payment_method, device_type, order_source, [comment])
        VALUES (-1, N'Unknown', N'Unknown', N'Unknown', N'Unknown', N'Unknown');
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.DIM_GEOGRAPHY WHERE zip = -1)
    BEGIN
        INSERT INTO dbo.DIM_GEOGRAPHY (zip, city, region, district)
        VALUES (-1, N'Unknown', N'Unknown', N'Unknown');
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.DIM_PROMOTION WHERE promo_id = N'UNKNOWN')
    BEGIN
        INSERT INTO dbo.DIM_PROMOTION
        (
            promo_id, promo_name, promo_type, discount_value,
            start_date, end_date, applicable_category, promo_channel,
            stackable_flag, min_order_value
        )
        VALUES
        (
            N'UNKNOWN', N'Unknown promotion', N'Unknown', 0,
            '19000101', '99991231', N'Unknown', N'Unknown', 0, 0
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DIM_SALES_EMPLOYEE
        WHERE sales_employee_id = N'UNKNOWN'
    )
    BEGIN
        INSERT INTO dbo.DIM_SALES_EMPLOYEE
        (
            sales_employee_id, sales_employee_name, marital_status,
            education_level, years_experience
        )
        VALUES (N'UNKNOWN', N'Unknown', N'Unknown', N'Unknown', 0);
    END;

    /* I. FACT_SALES: moi dong Order_Items_RD la mot dong fact.
       Cong thuc:
         gross_revenue = quantity * unit_price
         net_revenue   = gross_revenue - discount_amount
         cogs_amount   = quantity * cogs cua san pham
         profit_amount = net_revenue - cogs_amount
       discount_amount duoc xem la tien giam cua ca dong order item. */
    ;WITH CustomerZip AS
    (
        SELECT
            TRY_CONVERT(INT, customer_id) AS customer_id,
            TRY_CONVERT(INT, zip) AS zip,
            ROW_NUMBER() OVER
            (
                PARTITION BY TRY_CONVERT(INT, customer_id)
                ORDER BY customer_id
            ) AS rn
        FROM dbo.customer_clean
    )
    INSERT INTO dbo.FACT_SALES
    (
        date_key, product_key, customer_key, geography_key, promotion_key,
        order_key, employee_key, order_item_id, quantity, unit_price,
        discount_amount, gross_revenue, net_revenue, cogs_amount, profit_amount
    )
    SELECT
        COALESCE(dd.date_key, 0) AS date_key,
        COALESCE(dp.product_key,
            (SELECT TOP (1) product_key FROM dbo.DIM_PRODUCT WHERE product_id = -1 ORDER BY product_key)
        ) AS product_key,
        COALESCE(dc.customer_key,
            (SELECT TOP (1) customer_key FROM dbo.DIM_CUSTOMER WHERE customer_id = -1 ORDER BY customer_key)
        ) AS customer_key,
        COALESCE
        (
            dg.geography_key,
            (SELECT TOP (1) geography_key
             FROM dbo.DIM_GEOGRAPHY
             WHERE zip = -1
             ORDER BY geography_key)
        ) AS geography_key,
        COALESCE
        (
            dpr.promotion_key,
            (SELECT TOP (1) promotion_key
             FROM dbo.DIM_PROMOTION
             WHERE promo_id = N'UNKNOWN'
             ORDER BY promotion_key)
        ) AS promotion_key,
        COALESCE(dor.order_key,
            (SELECT TOP (1) order_key FROM dbo.DIM_ORDER WHERE order_id = -1 ORDER BY order_key)
        ) AS order_key,
        COALESCE
        (
            de.employee_key,
            (SELECT TOP (1) employee_key
             FROM dbo.DIM_SALES_EMPLOYEE
             WHERE sales_employee_id = N'UNKNOWN'
             ORDER BY employee_key)
        ) AS employee_key,
        cv.order_item_id,
        cv.quantity,
        cv.unit_price,
        cv.discount_amount,
        calc.gross_revenue,
        CAST(calc.gross_revenue - cv.discount_amount AS DECIMAL(18,2)) AS net_revenue,
        calc.cogs_amount,
        CAST(calc.gross_revenue - cv.discount_amount - calc.cogs_amount AS DECIMAL(18,2)) AS profit_amount
    FROM dbo.Order_Items_RD AS oi
    LEFT JOIN dbo.Orders_cleannew AS o
        ON TRY_CONVERT(INT, oi.order_id) = TRY_CONVERT(INT, o.order_id)
    CROSS APPLY
    (
        SELECT COALESCE(
            TRY_CONVERT(DATE, o.order_date, 101),
            TRY_CONVERT(DATE, o.order_date, 126),
            TRY_CONVERT(DATE, o.order_date, 23),
            TRY_CONVERT(DATE, o.order_date)
        ) AS order_dt
    ) AS od
    LEFT JOIN dbo.DIM_DATE AS dd
        ON dd.full_date = od.order_dt
    LEFT JOIN dbo.DIM_PRODUCT AS dp
        ON dp.product_id = TRY_CONVERT(INT, oi.product_id)
    LEFT JOIN dbo.DIM_CUSTOMER AS dc
        ON dc.customer_id = TRY_CONVERT(INT, o.customer_id)
    LEFT JOIN dbo.DIM_ORDER AS dor
        ON dor.order_id = TRY_CONVERT(INT, o.order_id)
    LEFT JOIN CustomerZip AS cz
        ON cz.customer_id = dc.customer_id
       AND cz.rn = 1
    LEFT JOIN dbo.DIM_GEOGRAPHY AS dg
        ON dg.zip = cz.zip
    LEFT JOIN dbo.DIM_PROMOTION AS dpr
        ON dpr.promo_id = NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), oi.promo_id))), N'')
    LEFT JOIN dbo.DIM_SALES_EMPLOYEE AS de
        ON de.sales_employee_id =
           NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), o.sales_employee_id))), N'')
    CROSS APPLY
    (
        SELECT
            TRY_CONVERT(INT, oi.order_item_id) AS order_item_id,
            TRY_CONVERT(INT, oi.quantity) AS quantity,
            TRY_CONVERT(DECIMAL(18,2), oi.unit_price) AS unit_price,
            COALESCE(TRY_CONVERT(DECIMAL(18,2), oi.discount_amount), 0) AS discount_amount
    ) AS cv
    CROSS APPLY
    (
        SELECT
            CAST(cv.quantity * cv.unit_price AS DECIMAL(18,2)) AS gross_revenue,
            CAST(cv.quantity * COALESCE(dp.cogs, 0) AS DECIMAL(18,2)) AS cogs_amount
    ) AS calc
    WHERE cv.order_item_id IS NOT NULL
      AND cv.quantity IS NOT NULL
      AND cv.unit_price IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.FACT_SALES AS target
          WHERE target.order_item_id = cv.order_item_id
      );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* J. KIEM TRA SO DONG TRONG CAC DIM VA FACT */
SELECT 'DIM_DATE' AS Bang, COUNT_BIG(*) AS SoDong FROM dbo.DIM_DATE
UNION ALL SELECT 'DIM_PRODUCT', COUNT_BIG(*) FROM dbo.DIM_PRODUCT
UNION ALL SELECT 'DIM_CUSTOMER', COUNT_BIG(*) FROM dbo.DIM_CUSTOMER
UNION ALL SELECT 'DIM_GEOGRAPHY', COUNT_BIG(*) FROM dbo.DIM_GEOGRAPHY
UNION ALL SELECT 'DIM_PROMOTION', COUNT_BIG(*) FROM dbo.DIM_PROMOTION
UNION ALL SELECT 'DIM_ORDER', COUNT_BIG(*) FROM dbo.DIM_ORDER
UNION ALL SELECT 'DIM_SALES_EMPLOYEE', COUNT_BIG(*) FROM dbo.DIM_SALES_EMPLOYEE
UNION ALL SELECT 'FACT_SALES', COUNT_BIG(*) FROM dbo.FACT_SALES;
GO

/* K. XEM THU 20 NHAN VIEN VA 20 DONG FACT */
SELECT TOP (20) *
FROM dbo.DIM_SALES_EMPLOYEE
ORDER BY employee_key;

SELECT TOP (20) *
FROM dbo.FACT_SALES
ORDER BY sales_key;
GO

/* L. TONG HOP DOANH THU VA LOI NHUAN */
SELECT
    COUNT_BIG(*) AS SoDongFact,
    SUM(gross_revenue) AS TongDoanhThuGop,
    SUM(net_revenue) AS TongDoanhThuThuan,
    SUM(cogs_amount) AS TongGiaVon,
    SUM(profit_amount) AS TongLoiNhuan
FROM dbo.FACT_SALES;
GO

/* M. DOI CHIEU SO DONG ORDER_ITEMS DA NAP VA CHUA NAP */
SELECT
    COUNT_BIG(*) AS TongDongOrderItems,
    (SELECT COUNT_BIG(*) FROM dbo.FACT_SALES) AS TongDongFact,
    SUM(CASE WHEN f.order_item_id IS NULL THEN 1 ELSE 0 END) AS SoDongChuaNap
FROM dbo.Order_Items_RD AS oi
LEFT JOIN dbo.FACT_SALES AS f
    ON TRY_CONVERT(INT, oi.order_item_id) = f.order_item_id;
GO

/* N. XEM CAC ORDER_ITEM CHUA VAO FACT */
SELECT TOP (50)
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    oi.discount_amount,
    oi.promo_id
FROM dbo.Order_Items_RD AS oi
LEFT JOIN dbo.FACT_SALES AS f
    ON TRY_CONVERT(INT, oi.order_item_id) = f.order_item_id
WHERE f.order_item_id IS NULL
ORDER BY TRY_CONVERT(INT, oi.order_item_id);
GO

/* O. KIEM TRA ZIP KHONG TIM THAY TRONG DIM_GEOGRAPHY.
   Neu so dong lon, doi chieu lai zip trong customer_clean.csv va geography_clean.csv. */
SELECT
    COUNT_BIG(*) AS SoKhachHangKhongTimThayZIP
FROM dbo.customer_clean AS c
LEFT JOIN dbo.DIM_GEOGRAPHY AS g
    ON TRY_CONVERT(INT, c.zip) = g.zip
WHERE TRY_CONVERT(INT, c.zip) IS NOT NULL
  AND g.geography_key IS NULL;
GO

/* P. KIEM TRA product_id TRONG ORDER_ITEMS KHONG TIM THAY TRONG DIM_PRODUCT */
SELECT COUNT_BIG(*) AS SoOrderItemCoProductKhongTimThay
FROM dbo.Order_Items_RD AS oi
LEFT JOIN dbo.DIM_PRODUCT AS p
    ON p.product_id = TRY_CONVERT(INT, oi.product_id)
WHERE TRY_CONVERT(INT, oi.product_id) IS NOT NULL
  AND p.product_key IS NULL;
GO

/* Q. KIEM TRA customer_id TRONG ORDERS KHONG TIM THAY TRONG DIM_CUSTOMER */
SELECT COUNT_BIG(*) AS SoDonHangCoCustomerKhongTimThay
FROM dbo.Orders_cleannew AS o
LEFT JOIN dbo.DIM_CUSTOMER AS c
    ON c.customer_id = TRY_CONVERT(INT, o.customer_id)
WHERE TRY_CONVERT(INT, o.customer_id) IS NOT NULL
  AND c.customer_key IS NULL;
GO

/* R. KIEM TRA order_id TRONG ORDER_ITEMS KHONG TIM THAY TRONG ORDERS */
SELECT COUNT_BIG(*) AS SoOrderItemKhongCoDonHangNguon
FROM dbo.Order_Items_RD AS oi
LEFT JOIN dbo.Orders_cleannew AS o
    ON TRY_CONVERT(INT, oi.order_id) = TRY_CONVERT(INT, o.order_id)
WHERE o.order_id IS NULL;
GO

/* S. KIEM TRA PROMO_ID TRONG ORDER_ITEMS KHONG TIM THAY TRONG DIM_PROMOTION */
SELECT
    COUNT_BIG(*) AS SoOrderItemCoPromoKhongTimThay
FROM dbo.Order_Items_RD AS oi
LEFT JOIN dbo.DIM_PROMOTION AS p
    ON p.promo_id = NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), oi.promo_id))), N'')
WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), oi.promo_id))), N'') IS NOT NULL
  AND p.promotion_key IS NULL;
GO



SELECT TOP 5 *
FROM dbo.geography_clean;
GO