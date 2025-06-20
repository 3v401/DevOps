#!/bin/bash

# Start backend
echo "Starting FastAPI..."
uvicorn main:app --host 0.0.0.0 --port 8000 &

# Start Streamlit UI
echo "Starting Streamlit..."
streamlit run chat_ui.py --server.port 8501 --server.address 0.0.0.0