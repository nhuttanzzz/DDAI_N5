
import pandas as pd
import pyodbc
from pathlib import Path

# =========================================
# 1. CẤU HÌNH
# =========================================

BASE_DIR = Path(r"E:\NĂM 3\PTDLVAI_26\student_data\silverdata")

PROMOTION_FILE = BASE_DIR / "promotions_clean.csv"
ORDER_FILE = BASE_DIR / "orders_enriched_clean.csv"

# Thay bằng đúng tên Server trong SSMS.
SERVER = r"localhost\SQLEXPRESS"

DATABASE = "SalesDataWarehouse"

# Windows Authentication.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

# =========================================
# 2. HÀM KẾT NỐI
# =========================================

def connect_sql_server():
    return pyodbc.connect(CONNECTION_STRING)


# =========================================
# 3. HÀM CHUẨN HÓA GIÁ TRỊ
# =========================================

def clean_value(value):
    """Chuyển giá trị pandas thành giá trị Python/SQL."""
    if pd.isna(value):
        return None

    if isinstance(value, pd.Timestamp):
        return value.date()

    if hasattr(value, "item"):
        value = value.item()

    return value


def normalize_text(series):
    """Chuẩn hóa chuỗi, giữ nguyên giá trị thiếu."""
    return series.map(
        lambda x: None if pd.isna(x)
        else str(x).strip() or None
    )


def normalize_date(series):
    """Chuyển ngày tháng thành date."""
    return pd.to_datetime(
        series,
        errors="coerce",
        dayfirst=True
    ).dt.date


def normalize_bit(series):
    """Chuyển các dạng yes/no, true/false, 1/0 thành BIT."""
    def convert(value):
        if pd.isna(value):
            return None

        if isinstance(value, bool):
            return int(value)

        text = str(value).strip().lower()

        if text in ("1", "true", "yes", "y"):
            return 1
        if text in ("0", "false", "no", "n"):
            return 0

        raise ValueError(
            f"Giá trị stackable_flag không hợp lệ: {value}"
        )

    return series.map(convert)


# =========================================
# 4. ĐỌC VÀ CHUẨN BỊ DIM_PROMOTION
# =========================================

def prepare_promotions():
    print("\nĐang đọc promotions_clean.csv...")

    df = pd.read_csv(
        PROMOTION_FILE,
        encoding="utf-8-sig"
    )

    df.columns = df.columns.str.strip().str.lower()

    print("Các cột nguồn Promotion:")
    print(df.columns.tolist())

    # Các cột đích theo lược đồ nhóm.
    # Chỉ promo_id là bắt buộc.
    columns = [
        "promo_id",
        "promo_name",
        "promo_type",
        "discount_value",
        "start_date",
        "end_date",
        "applicable_category",
        "promo_channel",
        "stackable_flag",
        "min_order_value"
    ]

    if "promo_id" not in df.columns:
        raise ValueError(
            "Không tìm thấy cột promo_id trong promotions_clean.csv. "
            "Hãy kiểm tra header thực tế."
        )

    # Chỉ giữ các cột có trong file nguồn.
    # Thuộc tính không có sẽ được đặt thành NULL.
    for col in columns:
        if col not in df.columns:
            df[col] = None

    df = df[columns].copy()

    # Chuẩn hóa mã khuyến mãi.
    df["promo_id"] = normalize_text(df["promo_id"])

    # Loại bỏ bản ghi không có khóa tự nhiên.
    df = df.dropna(subset=["promo_id"])

    # Một mã khuyến mãi chỉ có một dòng trong dimension.
    df = df.drop_duplicates(
        subset=["promo_id"],
        keep="last"
    )

    # Chuẩn hóa các cột dạng chuỗi.
    text_columns = [
        "promo_name",
        "promo_type",
        "applicable_category",
        "promo_channel"
    ]

    for col in text_columns:
        df[col] = normalize_text(df[col])

    # Chuẩn hóa số.
    for col in ["discount_value", "min_order_value"]:
        df[col] = pd.to_numeric(
            df[col],
            errors="coerce"
        )

    # Chuẩn hóa ngày.
    for col in ["start_date", "end_date"]:
        df[col] = normalize_date(df[col])

    # Chuẩn hóa cờ BIT.
    df["stackable_flag"] = normalize_bit(
        df["stackable_flag"]
    )

    print("Số dòng Promotion sau xử lý:", len(df))

    return df


# =========================================
# 5. ĐỌC VÀ CHUẨN BỊ DIM_ORDER
# =========================================

def prepare_orders():
    print("\nĐang đọc orders_enriched_clean.csv...")

    df = pd.read_csv(
        ORDER_FILE,
        encoding="utf-8-sig"
    )

    df.columns = df.columns.str.strip().str.lower()

    print("Các cột nguồn Order:")
    print(df.columns.tolist())

    columns = [
        "order_id",
        "order_status",
        "payment_method",
        "device_type",
        "order_source",
        "comment"
    ]

    if "order_id" not in df.columns:
        raise ValueError(
            "Không tìm thấy cột order_id trong file đơn hàng."
        )

    for col in columns:
        if col not in df.columns:
            df[col] = None

    df = df[columns].copy()

    # Chuẩn hóa khóa tự nhiên.
    df["order_id"] = pd.to_numeric(
        df["order_id"],
        errors="coerce"
    )

    df = df.dropna(subset=["order_id"])

    df["order_id"] = df["order_id"].astype("int64")

    # Mỗi order_id có một bản ghi trong DIM_ORDER.
    df = df.drop_duplicates(
        subset=["order_id"],
        keep="last"
    )

    # Chuẩn hóa các cột chuỗi.
    text_columns = [
        "order_status",
        "payment_method",
        "device_type",
        "order_source",
        "comment"
    ]

    for col in text_columns:
        df[col] = normalize_text(df[col])

    print("Số dòng Order sau xử lý:", len(df))

    return df


# =========================================
# 6. NẠP DIM_PROMOTION
# =========================================

def load_promotions(cursor, df):
    print("\nĐang nạp DIM_PROMOTION...")

    # Lấy các mã đã tồn tại để tránh nạp trùng.
    cursor.execute(
        "SELECT promo_id FROM dbo.DIM_PROMOTION"
    )

    existing_ids = {
        str(row[0]).strip()
        for row in cursor.fetchall()
    }

    new_df = df[
        ~df["promo_id"].isin(existing_ids)
    ].copy()

    if new_df.empty:
        print("Không có Promotion mới cần nạp.")
        return 0

    sql = """
        INSERT INTO dbo.DIM_PROMOTION (
            promo_id,
            promo_name,
            promo_type,
            discount_value,
            start_date,
            end_date,
            applicable_category,
            promo_channel,
            stackable_flag,
            min_order_value
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """

    records = [
        tuple(clean_value(v) for v in row)
        for row in new_df.itertuples(
            index=False,
            name=None
        )
    ]

    cursor.executemany(sql, records)

    print("Số Promotion mới đã nạp:", len(records))

    return len(records)


# =========================================
# 7. NẠP DIM_ORDER
# =========================================

def load_orders(cursor, df):
    print("\nĐang nạp DIM_ORDER...")

    cursor.execute(
        "SELECT order_id FROM dbo.DIM_ORDER"
    )

    existing_ids = {
        int(row[0])
        for row in cursor.fetchall()
    }

    new_df = df[
        ~df["order_id"].isin(existing_ids)
    ].copy()

    if new_df.empty:
        print("Không có Order mới cần nạp.")
        return 0

    sql = """
        INSERT INTO dbo.DIM_ORDER (
            order_id,
            order_status,
            payment_method,
            device_type,
            order_source,
            comment
        )
        VALUES (?, ?, ?, ?, ?, ?)
    """

    records = [
        tuple(clean_value(v) for v in row)
        for row in new_df.itertuples(
            index=False,
            name=None
        )
    ]

    cursor.executemany(sql, records)

    print("Số Order mới đã nạp:", len(records))

    return len(records)


# =========================================
# 8. CHẠY TOÀN BỘ QUY TRÌNH
# =========================================

def main():
    # Kiểm tra file nguồn.
    for file in [PROMOTION_FILE, ORDER_FILE]:
        if not file.exists():
            raise FileNotFoundError(
                f"Không tìm thấy file: {file}"
            )

    # Đọc và xử lý dữ liệu trước khi kết nối.
    promotions = prepare_promotions()
    orders = prepare_orders()

    # Kết nối SQL Server và nạp dữ liệu.
    conn = connect_sql_server()

    try:
        cursor = conn.cursor()

        promotion_count = load_promotions(
            cursor,
            promotions
        )

        order_count = load_orders(
            cursor,
            orders
        )

        # Lưu cả hai lần nạp trong một transaction.
        conn.commit()

        print("\n================================")
        print("HOÀN TẤT NẠP DỮ LIỆU")
        print("================================")
        print(
            "Promotion mới:",
            promotion_count
        )
        print(
            "Order mới:",
            order_count
        )

    except Exception:
        conn.rollback()
        print(
            "\nCó lỗi xảy ra. "
            "Đã rollback giao dịch."
        )
        raise

    finally:
        conn.close()


if __name__ == "__main__":
    main()