from pathlib import Path

import pandas as pd
import streamlit as st
import plotly.express as px


# ============================================================
# 1. CẤU HÌNH DASHBOARD
# ============================================================

st.set_page_config(
    page_title="PS1 - Báo cáo quản trị",
    page_icon="📊",
    layout="wide"
)


# ============================================================
# 2. CSS - GIAO DIỆN BÁO CÁO QUẢN TRỊ (giữ nguyên mẫu PS3)
# ============================================================

st.markdown("""
<style>

    .block-container {
        padding-top: 25px;
        padding-left: 45px;
        padding-right: 45px;
        padding-bottom: 30px;
    }

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

    .line {
        border-top: 1px solid #D9D9D9;
        margin: 15px 0 20px 0;
    }

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

    .section-title {
        font-size: 19px;
        font-weight: 650;
        margin-top: 15px;
        margin-bottom: 8px;
    }

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
# 3. ĐỌC DỮ LIỆU (file tổng hợp theo địa lý của PS1)
# ============================================================

BASE_DIR = Path(__file__).resolve().parent
data_file = BASE_DIR / "PS1_revenue_by_geography.xlsx"

if not data_file.exists():
    st.error(f"Không tìm thấy file: {data_file.name}")
    st.stop()

district = pd.read_excel(data_file, sheet_name="By_District")
district.columns = district.columns.str.strip().str.lower()

district = district.rename(
    columns={
        "total_revenue": "revenue",
        "total_quantity": "quantity",
        "n_orders": "orders",
    }
)

# Mã quận bị trùng giữa các thành phố (vd: District #23)
# nên dùng cặp (city, district) làm khóa
district["district_full"] = district["city"] + " - " + district["district"]


# ============================================================
# 4. TIÊU ĐỀ BÁO CÁO
# ============================================================

st.markdown(
    '<div class="report-title">'
    'BÁO CÁO QUẢN TRỊ DOANH THU THEO ĐỊA LÝ'
    '</div>',
    unsafe_allow_html=True
)

st.markdown(
    '<div class="report-subtitle">'
    'Problem Statement 1 – Ánh xạ doanh thu phân cấp Region › City › District '
    'để khoanh vùng thị trường phát triển mạnh nhất'
    '</div>',
    unsafe_allow_html=True
)

st.markdown('<div class="line"></div>', unsafe_allow_html=True)


# ============================================================
# 5. BỘ LỌC - 2 BỘ LỌC (giống PS3)
# ============================================================

filter_col1, filter_col2 = st.columns([1, 1])

with filter_col1:
    regions = ["Tất cả"] + sorted(district["region"].dropna().unique().tolist())
    selected_region = st.selectbox("Khu vực", regions)

with filter_col2:
    if selected_region == "Tất cả":
        cities = ["Tất cả"] + sorted(district["city"].unique().tolist())
    else:
        cities = ["Tất cả"] + sorted(
            district.loc[district["region"] == selected_region, "city"]
            .unique()
            .tolist()
        )
    selected_city = st.selectbox("Thành phố", cities)


filtered = district.copy()

if selected_region != "Tất cả":
    filtered = filtered[filtered["region"] == selected_region]

if selected_city != "Tất cả":
    filtered = filtered[filtered["city"] == selected_city]


# Mức trung bình toàn hệ thống (không phụ thuộc bộ lọc) để tính chênh lệch
sys_avg_district = district["revenue"].mean()
city_all = district.groupby("city", as_index=False).agg(revenue=("revenue", "sum"))
sys_avg_city = city_all["revenue"].mean()
region_all = district.groupby("region", as_index=False).agg(revenue=("revenue", "sum"))
sys_avg_region = region_all["revenue"].mean()


# ============================================================
# 6. KPI
# ============================================================

total_revenue = filtered["revenue"].sum()
total_orders = filtered["orders"].sum()
total_districts = len(filtered)
avg_district = total_revenue / total_districts if total_districts else 0
gap_avg = (avg_district / sys_avg_district - 1) * 100 if total_districts else 0

kpi1, kpi2, kpi3, kpi4 = st.columns(4)

kpis = [
    (kpi1, "TỔNG DOANH THU", f"{total_revenue:,.0f}"),
    (kpi2, "TỔNG ĐƠN HÀNG", f"{total_orders:,}"),
    (kpi3, "SỐ QUẬN", f"{total_districts:,}"),
    (kpi4, "CHÊNH LỆCH DT/QUẬN SO VỚI TB HỆ THỐNG", f"{gap_avg:+.1f}%"),
]

for col, title, value in kpis:
    with col:
        st.markdown(
            f"""
            <div class="kpi-box">
                <div class="kpi-title">{title}</div>
                <div class="kpi-value">{value}</div>
            </div>
            """,
            unsafe_allow_html=True
        )


# ============================================================
# 7. BIỂU ĐỒ 1 - DOANH THU THEO KHU VỰC
# ============================================================

st.markdown(
    '<div class="section-title">1. Doanh thu theo khu vực</div>',
    unsafe_allow_html=True
)

region_summary = (
    filtered
    .groupby("region", as_index=False)
    .agg(revenue=("revenue", "sum"))
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

st.plotly_chart(fig_region, use_container_width=True)


# ============================================================
# 8. HAI BIỂU ĐỒ NHỎ: TOP THÀNH PHỐ + CƠ CẤU
# ============================================================

left, right = st.columns(2)

with left:
    st.markdown(
        '<div class="section-title">2. Top 10 thành phố theo doanh thu</div>',
        unsafe_allow_html=True
    )

    city_summary = (
        filtered
        .groupby("city", as_index=False)
        .agg(revenue=("revenue", "sum"))
        .sort_values("revenue", ascending=False)
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

    st.plotly_chart(fig_city, use_container_width=True)

with right:
    st.markdown(
        '<div class="section-title">3. Cơ cấu doanh thu theo khu vực</div>',
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

    st.plotly_chart(fig_pie, use_container_width=True)


# ============================================================
# 9. BẢN ĐỒ PHÂN CẤP REGION › CITY › DISTRICT (đặc thù PS1)
# ============================================================

st.markdown(
    '<div class="section-title">'
    '4. Bản đồ doanh thu phân cấp Khu vực › Thành phố › Quận'
    '</div>',
    unsafe_allow_html=True
)

fig_tree = px.treemap(
    filtered,
    path=["region", "city", "district"],
    values="revenue",
    color="gap_pct_vs_avg",
    color_continuous_scale="RdYlGn",
    color_continuous_midpoint=0
)

fig_tree.update_layout(
    height=480,
    margin=dict(l=10, r=10, t=10, b=10),
    coloraxis_colorbar=dict(title="Chênh lệch % so với TB quận")
)

st.plotly_chart(fig_tree, use_container_width=True)


# ============================================================
# 10. TOP 10 QUẬN MẠNH NHẤT
# ============================================================

st.markdown(
    '<div class="section-title">5. Top 10 quận có doanh thu cao nhất</div>',
    unsafe_allow_html=True
)

top_district = (
    filtered
    .sort_values("revenue", ascending=False)
    .head(10)
    .sort_values("revenue")
)

fig_dist = px.bar(
    top_district,
    x="revenue",
    y="district_full",
    color="region",
    orientation="h",
    text_auto=".3s"
)

fig_dist.update_layout(
    height=380,
    margin=dict(l=10, r=10, t=10, b=10),
    xaxis_title="Doanh thu",
    yaxis_title="",
    legend_title="Khu vực"
)

st.plotly_chart(fig_dist, use_container_width=True)


# ============================================================
# 11. BẢNG TỔNG HỢP QUẢN TRỊ
# ============================================================

st.markdown(
    '<div class="section-title">'
    '6. Bảng tổng hợp thị trường theo thành phố'
    '</div>',
    unsafe_allow_html=True
)

table = (
    filtered
    .groupby(["region", "city"], as_index=False)
    .agg(
        Doanh_thu=("revenue", "sum"),
        Don_hang=("orders", "sum"),
        So_luong_SP=("quantity", "sum"),
        So_quan=("district", "count")
    )
)

table["AOV"] = table["Doanh_thu"] / table["Don_hang"]
table["Ty_trong"] = table["Doanh_thu"] / table["Doanh_thu"].sum() * 100
table["Chenh_lech"] = (table["Doanh_thu"] / sys_avg_city - 1) * 100


def classify(gap):
    if gap >= 20:
        return "Mạnh"
    if gap >= -20:
        return "Trung bình"
    return "Yếu"


table["Danh_gia"] = table["Chenh_lech"].map(classify)
table = table.sort_values("Doanh_thu", ascending=False)
table.insert(0, "Hang", range(1, len(table) + 1))

display_table = table.copy()
display_table["Doanh_thu"] = display_table["Doanh_thu"].map(lambda x: f"{x:,.0f}")
display_table["AOV"] = display_table["AOV"].map(lambda x: f"{x:,.0f}")
display_table["Ty_trong"] = display_table["Ty_trong"].map(lambda x: f"{x:.1f}%")
display_table["Chenh_lech"] = display_table["Chenh_lech"].map(lambda x: f"{x:+.1f}%")

display_table = display_table[
    ["Hang", "region", "city", "Doanh_thu", "Don_hang", "So_luong_SP",
     "So_quan", "AOV", "Ty_trong", "Chenh_lech", "Danh_gia"]
]

display_table.columns = [
    "Hạng", "Khu vực", "Thành phố", "Doanh thu", "Đơn hàng",
    "Số lượng SP", "Số quận", "AOV", "Tỷ trọng",
    "Chênh lệch so với TB thành phố", "Đánh giá"
]

st.dataframe(display_table, use_container_width=True, hide_index=True)

st.caption(
    "Đánh giá: Mạnh nếu doanh thu ≥ +20% so với trung bình thành phố; "
    "Yếu nếu ≤ −20%; còn lại là Trung bình."
)


# ============================================================
# 12. FOOTER
# ============================================================

st.markdown(
    """
    <div class="footer">
        Báo cáo quản trị – Problem Statement 1
        | Dữ liệu được tổng hợp từ PS1_revenue_by_geography.xlsx
    </div>
    """,
    unsafe_allow_html=True
)
