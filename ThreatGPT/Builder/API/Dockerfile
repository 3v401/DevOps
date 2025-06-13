FROM python:3.10-slim

WORKDIR /app
# Copy all files to container
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
# Required for Uvicorn
EXPOSE 8501
# By default Streamlit always runs on port 8501
RUN chmod +x start-threatgpt.sh
CMD ["./start-threatgpt.sh"]
