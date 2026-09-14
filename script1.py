import streamlit as st

gender = st.text_input("Are you male? yes or No :")

if gender == "yes":
    st.write("You are male")
elif gender == "No":
    st.write("You are female")




