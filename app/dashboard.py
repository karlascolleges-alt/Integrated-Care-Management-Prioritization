"""Interactive view of the care-management priority queue."""

from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ROOT / "sample_output" / "patient_priority_queue.csv"

st.set_page_config(page_title="Care Management Review Queue", layout="wide")
st.title("Care Management Review Queue")
st.caption("Synthetic demonstration data only. Priorities support human review and are not clinical recommendations.")

uploaded = st.sidebar.file_uploader("Use another generated queue", type="csv")
df = pd.read_csv(uploaded if uploaded is not None else DEFAULT_DATA)
selected_priorities = st.sidebar.multiselect("Priority", ["High", "Medium", "Low"], default=["High", "Medium", "Low"])
filtered = df[df["priority_level"].isin(selected_priorities)].copy()

col1, col2, col3, col4 = st.columns(4)
col1.metric("Patients", len(df))
col2.metric("High priority", int((df["priority_level"] == "High").sum()))
col3.metric("Medium priority", int((df["priority_level"] == "Medium").sum()))
col4.metric("Total 365-day cost", f"${df['total_cost_365d'].sum():,.0f}")

chart_col, reason_col = st.columns(2)
priority_order = ["High", "Medium", "Low"]
priority_counts = df["priority_level"].value_counts().reindex(priority_order, fill_value=0).rename_axis("priority").reset_index(name="patients")
chart_col.plotly_chart(px.bar(priority_counts, x="priority", y="patients", color="priority", category_orders={"priority": priority_order}, title="Patients by review priority"), width="stretch")
reason_counts = df["priority_reason"].value_counts().rename_axis("priority_reason").reset_index(name="patients")
reason_col.plotly_chart(px.bar(reason_counts, x="patients", y="priority_reason", orientation="h", title="Why records were prioritized"), width="stretch")

st.subheader("Filterable patient queue")
st.dataframe(filtered, width="stretch", hide_index=True)
st.subheader("Patient-level explanation")
if not filtered.empty:
    patient_id = st.selectbox("Patient ID", filtered["patient_id"].tolist())
    row = filtered.loc[filtered["patient_id"] == patient_id].iloc[0]
    st.info(f"Patient {patient_id} is {row['priority_level']} priority because: {row['priority_reason']}.")
else:
    st.warning("Select at least one priority to view patient records.")
