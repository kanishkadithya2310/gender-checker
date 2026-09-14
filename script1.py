import streamlit as st

st.title("Quick Quiz")

gender = st.radio("Are you male?", ["Yes", "No"])

if gender == "Yes":
    st.success("You are male")
else:
    st.success("You are female")




