# Shekatel Coffee — sync API server
# Deploy on ArvanCloud Cloud Container (or any Docker host).

FROM node:20-alpine

WORKDIR /app

# Install dependencies first (better layer caching)
COPY package.json package-lock.json ./
RUN npm install --omit=dev

# Copy the server source + an example config
COPY config.example.json config.example.json
COPY server.js config.js db.js schema.js ./

# The database key comes from environment variables (set in the ArvanCloud
# container settings) or from config.json — never baked into the image.
ENV PORT=3000
EXPOSE 3000

CMD ["node", "server.js"]
