# Multi-stage build to keep the runtime image small & non-root.
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

FROM node:20-alpine AS runtime
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=deps /app/node_modules ./node_modules
COPY src ./src
COPY package.json ./
USER app
EXPOSE 8080
CMD ["node", "src/index.js"]
