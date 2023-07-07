import cv2
import numpy as np
import streamlit as st
import requests
from PIL import Image
from pyzbar.pyzbar import decode

## Functions: Start
@st.cache_data
def check_string_contains_domains(string):
    url = "https://hole.cert.pl/domains/domains.txt"
    response = requests.get(url)
    
    if response.status_code == 200:
        domains = response.text.splitlines()
        
        for domain in domains:
            if domain in string:
                return True
    
    return False

def check_string_contains_approved_list(string, file):
    for link in file:        
        if link.decode().strip() == string:
            return True    
    return False

## Functions: End

## Header
st.header("Welcome to My QRCode Scan Web App")

file = st.sidebar.file_uploader("Upload Approved List", type = ['csv','txt'])
image = st.camera_input("Snap a photo of QRCode to Check for Unsecure Links")

## Decode QRCode
if image:

    pil_image = Image.open(image)
    cv2_img = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
    
    try:
        data = decode(cv2_img)[0].data.decode()
        if data and file:        
            if check_string_contains_domains(data):
                st.write("Link is malicious")
            elif data.startswith(r"http://"):
                st.write("Link is not secure")
                st.write(f"Decoded data is {data}")
            elif file:
                if check_string_contains_approved_list(data, file):
                    st.write("Link is in Approved List")
                    st.write(f"Decoded data is {data}")
                    st.write("")
                else:
                    st.write(f"Decoded data is {data}")
            else:
                st.write(f"Decoded data is {data}")
        elif data:
            if check_string_contains_domains(data):
                st.write("Link is malicious")
            elif data.startswith(r"http://"):
                st.write("Link is not secure")
                st.write(f"Decoded data is {data}")
            else:
                st.write(f"Decoded data is {data}")
        else:
            st.write("QR code not found..")  
    except:
        st.write("QR code not found..")
    
