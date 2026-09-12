FROM node:20-alpine

WORKDIR /app

# Copy backend dependencies
COPY backend/package*.json ./

# Install production dependencies
RUN npm install --omit=dev

# Copy backend source code
COPY backend/ ./

ENV PORT=10000
ENV NODE_ENV=production
ENV YOUTUBE_ENABLED=true

EXPOSE 10000

CMD ["node", "src/server.js"]
