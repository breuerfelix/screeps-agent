# Screeps Monitoring Agent

This Node.js agent fetches Screeps memory segments and pushes metrics to VictoriaMetrics for monitoring and visualization in Grafana.

## Features

- Fetches memory segments from configured Screeps shards
- Parses JSON data from memory segments and extracts metrics
- Pushes metrics to VictoriaMetrics in time-series format
- Runs continuously on a 2-minute schedule
- Ships as a Docker image for local and remote deployments
- Publishes container images to GHCR via GitHub Actions
- Supports env-configured Screeps targets via `SCREEPS_BASE_URL` and `SCREEPS_SHARDS`
- Keeps metrics labeled by `shard` only; no world/server label was added

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
- `SCREEPS_AGENT_IMAGE` — GHCR image tag to deploy, default `ghcr.io/breuerfelix/screeps-agent:main`
- `NODE_ENV` — usually `production`
- `TEST_MODE` — set to `true` for a single collection cycle

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
SCREEPS_AGENT_IMAGE=ghcr.io/breuerfelix/screeps-agent:main
NODE_ENV=production
TEST_MODE=false
```

3. Start the stack:

```bash
docker compose up -d
```

The included `docker-compose.yml` consumes the published GHCR image by default and passes the `.env` values through to the agent container.

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

```bash
npm ci
npm start
```

Single-run mode:

```bash
TEST_MODE=true npm start
```

Run tests:

```bash
npm test
```

Syntax check the main scripts:

```bash
node --check agent.js
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

## Security notes

- Do not commit real Screeps tokens to the repository.
- Keep deployment credentials in environment variables or secret stores.
- If you want anonymous pulls from GHCR, change the package visibility in GitHub from private to public after the first publish.
- If workflow pushes fail with package permission errors, verify repository Actions settings allow `GITHUB_TOKEN` read and write permissions.
