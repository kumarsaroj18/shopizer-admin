# Shopizer Administration — Angular Admin UI

Tested with **Node v12.22.7** · Requires `@angular/cli@13.3.x`

## Quick start

### Dev server (no Docker)

```bash
npm install --legacy-peer-deps
ng serve -o            # opens http://localhost:4200
```

### Production build

```bash
npm install --legacy-peer-deps
npm run build          # output: dist/
```

---

## Docker — build & run

Three ways to get a running Docker image. See [DOCKER_BUILD_GUIDE.md](docs/DOCKER_BUILD_GUIDE.md) for full details and examples.

### 1. From CI artifact (fastest)

Downloads the Angular dist from the latest successful GitHub Actions run — no Node.js required locally.

```bash
chmod +x build-image-from-ci.sh
./build-image-from-ci.sh <github-owner> shopizer-admin [branch] [image-tag]

# Example
./build-image-from-ci.sh kumarsaroj18 shopizer-admin main shopizer-admin:ci-latest

docker run -p 4200:80 \
  -e APP_BASE_URL=http://localhost:8080/api/v1 \
  shopizer-admin:ci-latest
```

### 2. From local source (Dockerfile.local)

```bash
npm install --legacy-peer-deps && npm run build
docker build -f Dockerfile.local -t shopizer-admin:local .
docker run -p 4200:80 \
  -e APP_BASE_URL=http://localhost:8080/api/v1 \
  shopizer-admin:local
```

### 3. run-local.sh — one-command launcher

```bash
chmod +x run-local.sh

./run-local.sh                          # pull from ghcr.io (docker mode)
./run-local.sh --mode dist              # download CI artifact and serve
./run-local.sh --mode local             # build from source and run
./run-local.sh --backend http://host:8080   # custom backend URL
```

---

## Default credentials

| Field | Value |
|---|---|
| URL | http://localhost:4200 |
| Username | `admin@shopizer.com` |
| Password | `password` |

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `APP_BASE_URL` | `http://localhost:8080/api/v1` | Backend API URL |
| `APP_SHIPPING_URL` | `http://localhost:8080` | Shipping service URL |
| `APP_MAP_API_KEY` | _(empty)_ | Google Maps API key |
| `APP_DEFAULT_LANGUAGE` | `en` | UI language |

→ See [DOCKER_BUILD_GUIDE.md](docs/DOCKER_BUILD_GUIDE.md) for advanced usage.
