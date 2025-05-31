FROM python:3.10-slim

WORKDIR /app
# Copy all files to container
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
# Required for Uvicorn
EXPOSE 8000
# Run API with Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0/0", "--port", "8000"]