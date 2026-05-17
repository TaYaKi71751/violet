# Stage 1: Build
FROM node:20-alpine AS builder

ARG PNPM_VERSION=9.15.9

# Install build dependencies for better-sqlite3
RUN apk add --no-cache python3 make g++ p7zip

# Install pnpm
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

WORKDIR /app

# Copy workspace config and lockfile first for better caching
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY packages/shared/package.json packages/shared/
COPY packages/backend/package.json packages/backend/
COPY packages/frontend/package.json packages/frontend/

RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build all packages (shared -> backend + frontend)
RUN pnpm build

# Create standalone backend deployment
RUN pnpm --filter @violet-web/backend deploy --prod /prod

# Stage 2: Runtime
FROM node:20-alpine

WORKDIR /app

# Install runtime dependency for extracting synced .7z databases
RUN apk add --no-cache p7zip

# Copy standalone backend from builder
COPY --from=builder /prod /app

# Copy frontend build output
COPY --from=builder /app/packages/frontend/dist /app/public

# Create data directory for SQLite databases
RUN mkdir -p /app/data

ENV FRONTEND_DIST=/app/public
ENV NODE_ENV=production

EXPOSE 3001

CMD ["node", "dist/index.js"]
