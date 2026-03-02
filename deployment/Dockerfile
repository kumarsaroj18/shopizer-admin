# ─────────────────────────────────────────────────────────────────────────────
# Shopizer Admin UI – artifact-based Dockerfile (Angular → Nginx)
#
# Build context : shopizer-admin/deployment/
# Required at build time: deployment/dist/    (the extracted Angular dist/)
#
# The CD workflow downloads the CI-produced dist.tar.gz, extracts it into
# deployment/dist/, then runs: docker build -f deployment/Dockerfile deployment/
#
# Why not build Angular here?
#   • Angular builds need node_modules, take 2–5 min, and depend on CI environment
#   • The CI-produced dist/ is the exact artefact that was tested
#   • Rebuilding in CD risks environment drift and breaks the tested = deployed guarantee
# ─────────────────────────────────────────────────────────────────────────────
FROM nginx:1.25-alpine

ARG APP_VERSION=unknown
ARG BUILD_DATE=unknown
ARG GIT_SHA=unknown

LABEL org.opencontainers.image.title="shopizer-admin"
LABEL org.opencontainers.image.description="Shopizer Angular Admin UI"
LABEL org.opencontainers.image.version="${APP_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_SHA}"

# Remove the default nginx placeholder page
RUN rm -rf /usr/share/nginx/html/*

# ── Angular dist (pre-built by CI) ───────────────────────────────────────────
COPY dist/ /usr/share/nginx/html/

# ── nginx: SPA routing + gzip + caching headers ──────────────────────────────
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO/dev/null http://localhost/ || exit 1

# Substitute runtime env vars into env.js then start nginx
CMD ["/bin/sh", "-c", \
  "envsubst < /usr/share/nginx/html/assets/env.template.js \
             > /usr/share/nginx/html/assets/env.js \
  && exec nginx -g 'daemon off;'"]
