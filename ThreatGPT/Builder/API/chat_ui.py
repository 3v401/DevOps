import streamlit as st
import requests # For calls to FastAPI backend

# Page title, app title and description
st.set_page_config(page_title="ThreatGpt Chatbot", layout = "centered")
st.title("ThreatGpt")
st.write("Analyze inputs for cybersecurity risks.")

# Sidebar for setting input type
st.sidebar.title("Input Settings")
input_type = st.sidebar.selectbox("Select input type", ["code", "log", "config", "other"])

# Store chat history
if "history" not in st.session_state:
    st.session_state.history = []

uploaded_text = st.text_area("Paste your input here: ", height=150)
uploaded_file = st.file_uploader("Upload file if necessary", type = ["txt", "py", "log", "conf", "json"])

# Button to start the analysis
if st.button("Analyze"):
    if not uploaded_text.strip() and not uploaded_file:
        st.warning("Enter something to analyze.")
    else:
        with st.spinner("Analyzing..."):
            try:
                files = {}
                data = {"input_type": input_type}

                if uploaded_file:
                    files["file"] = (uploaded_file.name, uploaded_file.getvalue())
                else:
                    files["content"] = (None, uploaded_text)

                # Send content + input_type to backend
                response = requests.post(
                    "http://localhost:8000/analyze",
                    files = files, # Here goes either content or file
                    data = data    # Input type
                )

                # If API returns success:
                if response.status_code == 200:
                    result = response.json()

                    # If it was text/file -> add to history text/file
                    if uploaded_text.strip():
                        input_display = uploaded_text
                    elif uploaded_file:
                        input_display = f"Uploaded file: {uploaded_file.name}"
                    # Add user input and result to history
                    st.session_state.history.append({
                        "input": input_display,
                        "response": result
                    })
                else:
                    st.error(f"API Error {response.status_code}: {response.text}")
            
            except Exception as e:
                st.error(f"Request failed: {e}")

# Display history
for entry in reversed(st.session_state.history):
    st.markdown("## Input")
    st.code(entry["input"], language= input_type)

    result = entry ["response"]
    st.markdown(f"**Threat Level:** {result['threat_level']}")
    st.markdown(f"**Explanation:** {result['explanation']}")
    st.markdown(f"**Prediction:** {result['prediction']}")
    st.markdown(f"**Patch**:")
    st.code(result['patch_suggestion']['snippet'], language=input_type)