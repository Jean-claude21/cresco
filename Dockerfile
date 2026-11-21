# Cresco — une image pour tous les environnements (Coolify). L'adresse publique, la base et les
# secrets arrivent par variables d'environnement au démarrage, jamais dans l'image.
FROM node:22-slim AS build
WORKDIR /app
RUN corepack enable
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY packages/engine-ts/package.json packages/engine-ts/
COPY apps/server/package.json apps/server/
RUN pnpm install --frozen-lockfile
COPY packages/engine-ts packages/engine-ts
COPY apps/server apps/server
RUN pnpm --filter @cresco/server build

FROM node:22-slim AS runtime
WORKDIR /app
ARG APP_VERSION=dev
ENV NODE_ENV=production APP_VERSION=$APP_VERSION PORT=3000 APP_ROOT=/app \
    MIGRATIONS_DIR=/app/migrations SOURCES_PATH=/app/SOURCES.md
# curl : Coolify vérifie la santé du conteneur avec avant de basculer sur une nouvelle version.
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/apps/server/dist/server.mjs ./server.mjs
COPY apps/server/db/migrations ./migrations
COPY docs/science/SOURCES.md ./SOURCES.md
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD curl -fsS http://127.0.0.1:3000/api/health || exit 1
CMD ["node", "server.mjs"]
