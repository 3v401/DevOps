#!/bin/bash

# Start backend
uvicorn main:app --host 0.0.0.0 --port 8000 &

# Start Streamlit UI
streamlit run chat_ui.py --server.port 8501 --server.address 0.0.0.0