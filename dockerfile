# ====== deps stage：安裝依賴 ======
FROM node:20-slim AS deps
WORKDIR /app
# 安裝一些常見原生模組在編譯/運行期會用到的依賴（例如 sharp/undici/openssl）
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates openssl dumb-init \
  && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN npm ci

# ====== builder stage：建置 Next.js ======
FROM node:20-slim AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# 關閉 Next 遙測
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ====== runner stage：最終運行映像 ======
FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 HOSTNAME=0.0.0.0 PORT=3000

# 安裝 dumb-init（在 runner 階段！）
RUN apt-get update && apt-get install -y --no-install-recommends dumb-init \
    && rm -rf /var/lib/apt/lists/*

# 只帶上運行所需檔案
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=deps    /app/node_modules ./node_modules

RUN useradd -m nextjs
USER nextjs

EXPOSE 3000
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["npm", "run", "start"]
