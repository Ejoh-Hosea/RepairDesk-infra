# ── Build stage ───────────────────────────────────────────────────────────────
# Build context = server/ folder from the app repo (repair-dashboard)
# GitHub Actions clones the app repo and passes server/ as the build context
FROM node:20-alpine AS base

WORKDIR /app

# Copy package files first — layer cache skips npm install if unchanged
COPY package.json package-lock.json* ./
RUN npm ci --only=production && npm cache clean --force

# ── Production image ──────────────────────────────────────────────────────────
FROM node:20-alpine AS production

# Security: never run as root
RUN addgroup -g 1001 -S nodejs && \
    adduser  -S nodeapp -u 1001

WORKDIR /app

COPY --from=base --chown=nodeapp:nodejs /app/node_modules ./node_modules
COPY --chown=nodeapp:nodejs src/        ./src/
COPY --chown=nodeapp:nodejs package.json ./

USER nodeapp

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/api/health', r => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "src/index.js"]