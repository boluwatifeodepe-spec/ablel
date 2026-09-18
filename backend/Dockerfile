FROM node:20-alpine

WORKDIR /app

# Install Python3, pip, ffmpeg, and yt-dlp for media extraction
RUN apk add --no-cache python3 py3-pip ffmpeg && \
    pip3 install --no-cache-dir yt-dlp --break-system-packages

COPY package*.json ./

RUN npm install --omit=dev

COPY . .

ENV PORT=10000
ENV NODE_ENV=production
ENV YOUTUBE_ENABLED=true

EXPOSE 10000

CMD ["node", "src/server.js"]
