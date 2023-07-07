import streamlit as st

st.header("Demo of How It Works")

video_file = open('QRCodeSecureScan_Demo.mp4', 'rb')
video_bytes = video_file.read()

st.video(video_bytes)
