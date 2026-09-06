FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production

COPY . .

ENV PORT=3000
ENV NODE_ENV=production
ENV YOUTUBE_ENABLED=true

EXPOSE 3000

CMD ["node", "src/server.js"]
