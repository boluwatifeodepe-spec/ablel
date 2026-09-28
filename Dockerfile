FROM python:3.11-slim

WORKDIR /app

# Copy python dependencies
COPY backend_py/requirements.txt ./

# Install production dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source code
COPY backend_py/ ./

ENV PORT=10000

EXPOSE 10000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]
