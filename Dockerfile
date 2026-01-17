# syntax=docker/dockerfile:1

# ============================================
# Stage 1: Prune monorepo for web app only
# ============================================
FROM node:20-alpine AS pruner

# Setup pnpm
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

# Install turbo globally
RUN pnpm add -g turbo

WORKDIR /app
COPY . .
RUN turbo prune web --docker

# ============================================
# Stage 2: Install dependencies
# ============================================
FROM node:20-alpine AS installer

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

# Install dependencies based on pruned lockfile
COPY --from=pruner /app/out/json/ .
RUN pnpm install --frozen-lockfile

# ============================================
# Stage 3: Build the application
# ============================================
FROM node:20-alpine AS builder

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate
RUN pnpm add -g turbo

WORKDIR /app

# Copy installed dependencies
COPY --from=installer /app/ .

# Copy source code
COPY --from=pruner /app/out/full/ .

# Build the web app (this also builds dependent packages)
RUN pnpm turbo build --filter=web

# ============================================
# Stage 4: Production runner
# ============================================
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV HOSTNAME="0.0.0.0"
ENV PORT=3000

# Don't run as root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy built standalone app
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public ./apps/web/public

USER nextjs

EXPOSE 3000

CMD ["node", "apps/web/server.js"]
