# Use a lightweight Python Linux base
FROM python:3.12-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file first (optimizes build caching)
COPY requirements.txt .

# Install dependencies inside the container's global space
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your server code
COPY . .

# Expose the port your Flask app runs on (e.g., 5000)
EXPOSE 5000

# Run the server
CMD ["python", "server.py"]