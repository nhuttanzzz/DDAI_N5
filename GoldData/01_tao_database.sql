/* BƯỚC 1: Chạy trong SSMS. Tạo database mới cho Gold Data. */
USE master;
GO
IF DB_ID(N'DW_Sales_Gold') IS NULL
BEGIN
    CREATE DATABASE DW_Sales_Gold;
END;
GO
USE DW_Sales_Gold;
GO
SELECT DB_NAME() AS DatabaseDangSuDung;
GO
