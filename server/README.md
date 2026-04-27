docker build -t flux .
docker run -p 9000:9000 flux

ngrok http 9000