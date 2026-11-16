# Screeps Monitoring Agent

This Node.js agent fetches Screeps memory segments and pushes metrics to VictoriaMetrics for monitoring and visualization in Grafana.

## Features

- Fetches memory segments from configured Screeps shards
- Parses JSON data from memory segments and extracts metrics
- Pushes metrics to VictoriaMetrics in time-series format
- Streams Screeps console websocket messages into Loki when `LOKI_URL` is configured
- Labels console logs with `shard`, `server_host`, `username`, and `message_type`
- Runs continuously on a 2-minute schedule
- Ships as a Docker image for local and remote deployments
- Publishes container images to GHCR via GitHub Actions
- Supports env-configured Screeps targets via `SCREEPS_BASE_URL` and `SCREEPS_SHARDS`
- Keeps metrics labeled by `shard` only; console logs also carry `server_host` for cross-environment separation

Backward-compatible defaults remain for the current official-world deployment:

- `SCREEPS_BASE_URL=https://screeps.com`
- `SCREEPS_SHARDS=shardSeason,shardX`

## Published container image

This repository publishes images to:

`ghcr.io/breuerfelix/screeps-agent`

Tag strategy:

- Branch pushes: sanitized branch-name tags such as `main` or `ci-ghcr-publish`
- Every push: `sha-<full-git-sha>`
- Default branch only: `main` and `latest`
- Git tags like `v1.2.3`: `v1.2.3`

Examples:

```bash
docker pull ghcr.io/breuerfelix/screeps-agent:main
docker pull ghcr.io/breuerfelix/screeps-agent:sha-<full-git-sha>
```

The GitHub Actions workflow logs in with `GITHUB_TOKEN` and pushes to the package namespace that matches this repository.

## Configuration

Copy `.env.example` to `.env` and edit values for the deployment you want.

```bash
cp .env.example .env
```

### Environment variables

- `SCREEPS_TOKEN` — API token for the target world
  - official world: create at https://screeps.com/a/#!/account/auth-tokens
  - private server: use a token minted for that private server user
- `SCREEPS_BASE_URL` — base URL for the target Screeps deployment
  - official world example: `https://screeps.com`
  - private server example: `https://screeps.example.internal`
- `SCREEPS_SHARDS` — comma-separated shard names for this deployment
  - official world example: `shardSeason,shardX`
  - private server example: `coolify`
- `VICTORIA_METRICS_URL` — VictoriaMetrics base URL
- `LOKI_URL` — Loki base URL for console log ingestion
  - local compose example: `http://loki:3100`
  - external host example: `http://loki.example.internal:3100`
  - when unset, websocket console capture stays disabled and the agent still exports metrics only
- `SCREEPS_AGENT_IMAGE` — GHCR image tag to deploy, default `ghcr.io/breuerfelix/screeps-agent:main`
- `NODE_ENV` — usually `production`
- `TEST_MODE` — set to `true` for a single collection cycle

When the console websocket payload omits `shard`, the agent falls back to the single configured value from `SCREEPS_SHARDS`. This matters for many private-server deployments where websocket console events do not include shard data even though the deployment is single-shard.

## Deployment model

Run one agent instance per world.

Examples:

- official-world deployment
  - `SCREEPS_BASE_URL=https://screeps.com`
  - `SCREEPS_SHARDS=shardSeason,shardX`
- private-server deployment
  - `SCREEPS_BASE_URL=https://screeps.example.internal`
  - `SCREEPS_SHARDS=coolify`

Do not configure one instance to scrape both official and private worlds at once. Deploy a separate instance for the private server.

### Season 11 stack

For the official Season 11 world, use [`docker-compose.season-11.yml`](docker-compose.season-11.yml) with the existing external monitoring network. It pins the agent to `shardSeason`, sends metrics to VictoriaMetrics, and sends console websocket logs to Loki. See [`docs/season-11-observability.md`](docs/season-11-observability.md) for the required secret and Grafana/Loki queries.

The Season 11 stack is intentionally a separate agent instance. If the existing official-world deployment still scrapes `shardSeason`, remove that shard there before starting the Season 11 instance to avoid duplicate metric ingestion.

The agent normalizes both Screeps response shapes seen in the wild:

- official MMO responses where `/api/user/memory-segment` returns `data` as an array of segment strings
- private-server responses where the same endpoint returns `data` as one JSON string payload even when multiple segment IDs are requested

## Consuming the published image

### Docker Compose

1. Copy the example env file:

```bash
cp .env.example .env
```

2. Edit `.env` with the target world for this deployment.

Official-world example:

```env
SCREEPS_TOKEN=replace-with-official-token
SCREEPS_BASE_URL=https://screeps.com
SCREEPS_SHARDS=shardSeason,shardX
VICTORIA_METRICS_URL=http://victoriametrics:8428
LOKI_URL=http://loki:3100
SCREEPS_AGENT_IMAGE=ghcr.io/breuerfelix/screeps-agent:main
NODE_ENV=production
TEST_MODE=false
```

Private-server example:

```env
SCREEPS_TOKEN=replace-with-private-server-token
SCREEPS_BASE_URL=https://screeps.example.internal
SCREEPS_SHARDS=coolify
VICTORIA_METRICS_URL=http://victoriametrics:8428
LOKI_URL=http://loki:3100
SCREEPS_AGENT_IMAGE=ghcr.io/breuerfelix/screeps-agent:main
NODE_ENV=production
TEST_MODE=false
```

3. Start the stack:

```bash
docker compose up -d
```

The included `docker-compose.yml` consumes the published GHCR image by default and passes the `.env` values through to the agent container.

### Portainer GitOps deployment for the official world

Use `docker-compose.portainer.yml` as the stack file when the official-world scraper is managed by Portainer from this repository.

What this file does:

- runs only the `screeps-agent` service, matching the existing standalone deployment shape
- uses `ghcr.io/breuerfelix/screeps-agent:main` by default so Portainer follows the repository's main image line
- keeps the same environment variable names already used by the container (`SCREEPS_TOKEN`, `VICTORIA_METRICS_URL`, `LOKI_URL`, `NODE_ENV`)
- preserves official-world defaults when `SCREEPS_BASE_URL` and `SCREEPS_SHARDS` are not overridden
- joins the existing `monitoring_monitoring` Docker network by default instead of creating a new monitoring stack
- does not require bind mounts or a generated `config.js` startup workaround

Recommended Portainer environment values:

```env
SCREEPS_TOKEN=replace-with-official-token
VICTORIA_METRICS_URL=http://victoriametrics:8428
NODE_ENV=production
TEST_MODE=false
```

Optional overrides:

```env
SCREEPS_BASE_URL=https://screeps.com
SCREEPS_SHARDS=shardSeason,shardX
LOKI_URL=
SCREEPS_AGENT_IMAGE=ghcr.io/breuerfelix/screeps-agent:main
MONITORING_NETWORK=monitoring_monitoring
SCREEPS_AGENT_CONTAINER_NAME=screeps-agent
```

By default Portainer follows `ghcr.io/breuerfelix/screeps-agent:main`. Override `SCREEPS_AGENT_IMAGE` only when you intentionally need a different tag. Set `LOKI_URL` for private-world deployments that should stream websocket console logs into Loki; leave it empty for metrics-only official-world deployments.

### Downstream deployments outside this repository

If the package remains private, the deployment environment must authenticate to GHCR before pulling:

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u <github-user> --password-stdin
docker pull ghcr.io/breuerfelix/screeps-agent:main
```

Typical token scopes:

- `read:packages` to pull from GHCR
- `write:packages` only for publishing environments

For GitHub-hosted workflows in the same repository, the built-in `GITHUB_TOKEN` is enough for publishing.

## Local development

Node.js 22.4.0 or newer is required. The websocket console capture path uses the built-in `WebSocket` client, which is only stable from Node 22.4.0 onward.

```bash
npm ci
npm start
```

Single-run mode:

```bash
TEST_MODE=true npm start
```

Probe the websocket console path against the configured Screeps target:

```bash
npm run probe:console
```

If `LOKI_URL` is set, the probe also pushes the captured console event into Loki so you can verify end-to-end ingestion.

Run tests:

```bash
npm test
```

Syntax check the main scripts:

```bash
node --check agent.js
node --check console_log_capture.js
node --check loki.js
node --check probe_console_logs.js
node --check fetch_segments.js
node --check one_shot.js
node --check ingest_segment.js
node --check segment_parser.js
```

## Local container build

```bash
docker build -t screeps-agent:dev .
```

## Monitoring stack

The repository also includes a local monitoring stack for development:

- Grafana on `http://localhost:3000`
- VictoriaMetrics on `http://localhost:8428`
- Loki on `http://localhost:3100`

Start it with:

```bash
docker compose up -d
```

Default Grafana credentials in the sample compose file:

- Username: `admin`
- Password: `jamo`

## Development notes

- The official Screeps season endpoint still uses `https://screeps.com/season/api/...` when the base URL is official and shard is `shardSeason`.
- All other targets, including private servers, use `<SCREEPS_BASE_URL>/api/...`.
- Metrics remain distinguished by shard name only.
- Console logs sent to Loki use labels `{source="screeps_console", server_host="...", username="...", shard="...", message_type="log|result|error"}`.
- For single-shard private deployments, console events that omit `payload.shard` inherit the single configured `SCREEPS_SHARDS` value so Loki streams still remain shard-addressable.

## Security notes

- Do not commit real Screeps tokens to the repository.
- Keep deployment credentials in environment variables or secret stores.
- If you want anonymous pulls from GHCR, change the package visibility in GitHub from private to public after the first publish.
- If workflow pushes fail with package permission errors, verify repository Actions settings allow `GITHUB_TOKEN` read and write permissions.
