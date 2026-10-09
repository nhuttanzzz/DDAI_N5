from pathlib import Path

import pandas as pd
import streamlit as st
import plotly.express as px


# ============================================================
# 1. CẤU HÌNH DASHBOARD
# ============================================================

st.set_page_config(
    page_title="PS3 - Báo cáo quản trị",
    page_icon="📊",
    layout="wide"
)


# ============================================================
# 2. CSS - GIAO DIỆN BÁO CÁO QUẢN TRỊ
# ============================================================

st.markdown("""
<style>

    /* Toàn bộ trang */
    .block-container {
        padding-top: 25px;
        padding-left: 45px;
        padding-right: 45px;
        padding-bottom: 30px;
    }

    /* Tiêu đề */
    .report-title {
        font-size: 30px;
        font-weight: 700;
        margin-bottom: 2px;
    }

    .report-subtitle {
        font-size: 15px;
        color: #666666;
        margin-bottom: 20px;
    }

    /* Đường phân cách */
    .line {
        border-top: 1px solid #D9D9D9;
        margin: 15px 0 20px 0;
    }

    /* KPI */
    .kpi-box {
        border: 1px solid #DDDDDD;
        border-radius: 6px;
        padding: 18px 20px;
        background: #FFFFFF;
        min-height: 105px;
    }

    .kpi-title {
        font-size: 14px;
        color: #666666;
        margin-bottom: 8px;
    }

    .kpi-value {
        font-size: 27px;
        font-weight: 700;
        color: #222222;
    }

    /* Tiêu đề section */
    .section-title {
        font-size: 19px;
        font-weight: 650;
        margin-top: 15px;
        margin-bottom: 8px;
    }

    /* Footer */
    .footer {
        text-align: center;
        color: #888888;
        font-size: 12px;
        margin-top: 25px;
        border-top: 1px solid #DDDDDD;
        padding-top: 12px;
    }

</style>
""", unsafe_allow_html=True)


# ============================================================
# 3. ĐỌC DỮ LIỆU
# ============================================================

BASE_DIR = Path(__file__).resolve().parent

orders_file = BASE_DIR / "orders_enriched_clean.csv"
items_file = BASE_DIR / "order_items_clean.csv"


if not orders_file.exists():
    st.error(f"Không tìm thấy file: {orders_file.name}")
    st.stop()

if not items_file.exists():
    st.error(f"Không tìm thấy file: {items_file.name}")
    st.stop()


orders = pd.read_csv(orders_file)
items = pd.read_csv(items_file)


# Chuẩn hóa tên cột
orders.columns = orders.columns.str.strip().str.lower()
items.columns = items.columns.str.strip().str.lower()


# ============================================================
# 4. TÍNH DOANH THU
# ============================================================

# Doanh thu từng dòng sản phẩm
items["quantity"] = pd.to_numeric(
    items["quantity"],
    errors="coerce"
).fillna(0)

items["unit_price"] = pd.to_numeric(
    items["unit_price"],
    errors="coerce"
).fillna(0)

items["discount_amount"] = pd.to_numeric(
    items["discount_amount"],
    errors="coerce"
).fillna(0)


items["revenue"] = (
    items["quantity"] * items["unit_price"]
    - items["discount_amount"]
)


# Tổng hợp doanh thu theo đơn hàng
order_sales = (
    items
    .groupby("order_id", as_index=False)
    .agg(
        revenue=("revenue", "sum"),
        quantity=("quantity", "sum")
    )
)


# ============================================================
# 5. GHÉP THÔNG TIN ĐƠN HÀNG
# ============================================================

needed_columns = [
    "order_id",
    "customer_id",
    "city",
    "region"
]

orders = orders[needed_columns].drop_duplicates(
    subset=["order_id"]
)


data = orders.merge(
    order_sales,
    on="order_id",
    how="inner"
)


# ============================================================
# 6. TIÊU ĐỀ BÁO CÁO
# ============================================================

st.markdown(
    '<div class="report-title">'
    'BÁO CÁO QUẢN TRỊ HIỆU QUẢ PHÁT TRIỂN THỊ TRƯỜNG'
    '</div>',
    unsafe_allow_html=True
)

st.markdown(
    '<div class="report-subtitle">'
    'Problem Statement 3 – Phân tích theo khu vực địa lý'
    '</div>',
    unsafe_allow_html=True
)

st.markdown('<div class="line"></div>', unsafe_allow_html=True)


# ============================================================
# 7. BỘ LỌC NHỎ - CHỈ GIỮ 2 BỘ LỌC
# ============================================================

filter_col1, filter_col2 = st.columns([1, 1])

with filter_col1:

    regions = ["Tất cả"] + sorted(
        data["region"]
        .dropna()
        .astype(str)
        .unique()
        .tolist()
    )

    selected_region = st.selectbox(
        "Khu vực",
        regions
    )


with filter_col2:

    if selected_region == "Tất cả":

        cities = ["Tất cả"] + sorted(
            data["city"]
            .dropna()
            .astype(str)
            .unique()
            .tolist()
        )

    else:

        cities = ["Tất cả"] + sorted(
            data.loc[
                data["region"].astype(str) == selected_region,
                "city"
            ]
            .dropna()
            .astype(str)
            .unique()
            .tolist()
        )

    selected_city = st.selectbox(
        "Thành phố",
        cities
    )


# Áp dụng bộ lọc
filtered = data.copy()


if selected_region != "Tất cả":

    filtered = filtered[
        filtered["region"].astype(str) == selected_region
    ]


if selected_city != "Tất cả":

    filtered = filtered[
        filtered["city"].astype(str) == selected_city
    ]


# ============================================================
# 8. KPI
# ============================================================

total_revenue = filtered["revenue"].sum()

total_orders = filtered["order_id"].nunique()

total_customers = filtered["customer_id"].nunique()

if total_orders > 0:
    aov = total_revenue / total_orders
else:
    aov = 0


kpi1, kpi2, kpi3, kpi4 = st.columns(4)


with kpi1:
    st.markdown(
        f"""
        <div class="kpi-box">
            <div class="kpi-title">TỔNG DOANH THU</div>
            <div class="kpi-value">
                {total_revenue:,.0f}
            </div>
        </div>
        """,
        unsafe_allow_html=True
    )


with kpi2:
    st.markdown(
        f"""
        <div class="kpi-box">
            <div class="kpi-title">TỔNG ĐƠN HÀNG</div>
            <div class="kpi-value">
                {total_orders:,}
            </div>
        </div>
        """,
        unsafe_allow_html=True
    )


with kpi3:
    st.markdown(
        f"""
        <div class="kpi-box">
            <div class="kpi-title">KHÁCH HÀNG</div>
            <div class="kpi-value">
                {total_customers:,}
            </div>
        </div>
        """,
        unsafe_allow_html=True
    )


with kpi4:
    st.markdown(
        f"""
        <div class="kpi-box">
            <div class="kpi-title">GIÁ TRỊ ĐƠN HÀNG TB</div>
            <div class="kpi-value">
                {aov:,.0f}
            </div>
        </div>
        """,
        unsafe_allow_html=True
    )


# ============================================================
# 9. BIỂU ĐỒ 1 - DOANH THU THEO KHU VỰC
# ============================================================

st.markdown(
    '<div class="section-title">1. Doanh thu theo khu vực</div>',
    unsafe_allow_html=True
)


region_summary = (
    filtered
    .groupby("region", as_index=False)
    .agg(
        revenue=("revenue", "sum")
    )
    .sort_values("revenue", ascending=False)
)


fig_region = px.bar(
    region_summary,
    x="region",
    y="revenue",
    text_auto=".3s"
)

fig_region.update_layout(
    height=330,
    margin=dict(l=10, r=10, t=10, b=10),
    xaxis_title="Khu vực",
    yaxis_title="Doanh thu",
    showlegend=False
)

st.plotly_chart(
    fig_region,
    use_container_width=True
)


# ============================================================
# 10. HAI BIỂU ĐỒ NHỎ
# ============================================================

left, right = st.columns(2)


# ------------------------------------------------------------
# 10.1 TOP THÀNH PHỐ
# ------------------------------------------------------------

with left:

    st.markdown(
        '<div class="section-title">'
        '2. Top 10 thành phố theo doanh thu'
        '</div>',
        unsafe_allow_html=True
    )

    city_summary = (
        filtered
        .groupby("city", as_index=False)
        .agg(
            revenue=("revenue", "sum")
        )
        .sort_values(
            "revenue",
            ascending=False
        )
        .head(10)
        .sort_values("revenue")
    )

    fig_city = px.bar(
        city_summary,
        x="revenue",
        y="city",
        orientation="h",
        text_auto=".3s"
    )

    fig_city.update_layout(
        height=350,
        margin=dict(l=10, r=10, t=10, b=10),
        xaxis_title="Doanh thu",
        yaxis_title="",
        showlegend=False
    )

    st.plotly_chart(
        fig_city,
        use_container_width=True
    )


# ------------------------------------------------------------
# 10.2 TỶ TRỌNG DOANH THU
# ------------------------------------------------------------

with right:

    st.markdown(
        '<div class="section-title">'
        '3. Cơ cấu doanh thu theo khu vực'
        '</div>',
        unsafe_allow_html=True
    )

    fig_pie = px.pie(
        region_summary,
        names="region",
        values="revenue",
        hole=0.45
    )

    fig_pie.update_layout(
        height=350,
        margin=dict(l=10, r=10, t=10, b=10),
        showlegend=True
    )

    st.plotly_chart(
        fig_pie,
        use_container_width=True
    )


# ============================================================
# 11. BẢNG TỔNG HỢP QUẢN TRỊ
# ============================================================

st.markdown(
    '<div class="section-title">'
    '4. Bảng tổng hợp hiệu quả theo khu vực'
    '</div>',
    unsafe_allow_html=True
)


management_table = (
    filtered
    .groupby("region", as_index=False)
    .agg(
        Doanh_thu=("revenue", "sum"),
        Don_hang=("order_id", "nunique"),
        Khach_hang=("customer_id", "nunique"),
        So_luong_SP=("quantity", "sum"),
        So_thanh_pho=("city", "nunique")
    )
)


management_table["AOV"] = (
    management_table["Doanh_thu"]
    / management_table["Don_hang"]
)


total = management_table["Doanh_thu"].sum()

if total > 0:
    management_table["Ty_trong"] = (
        management_table["Doanh_thu"] / total * 100
    )
else:
    management_table["Ty_trong"] = 0


management_table = management_table.sort_values(
    "Doanh_thu",
    ascending=False
)


# Format để hiển thị đẹp
display_table = management_table.copy()

display_table["Doanh_thu"] = display_table[
    "Doanh_thu"
].map(lambda x: f"{x:,.0f}")

display_table["AOV"] = display_table[
    "AOV"
].map(lambda x: f"{x:,.0f}")

display_table["Ty_trong"] = display_table[
    "Ty_trong"
].map(lambda x: f"{x:.1f}%")


display_table.columns = [
    "Khu vực",
    "Doanh thu",
    "Đơn hàng",
    "Khách hàng",
    "Số lượng SP",
    "Số thành phố",
    "AOV",
    "Tỷ trọng"
]


st.dataframe(
    display_table,
    use_container_width=True,
    hide_index=True
)


# ============================================================
# 12. FOOTER
# ============================================================

st.markdown(
    """
    <div class="footer">
        Báo cáo quản trị – Problem Statement 3
        | Dữ liệu được tổng hợp từ Silver Data
    </div>
    """,
    unsafe_allow_html=True
)