# Screeps Monitoring Agent

This Node.js agent fetches Screeps memory segments and pushes metrics to VictoriaMetrics for monitoring and visualization in Grafana.

## Features

- Fetches memory segments from Screeps shards such as `shardSeason` and `shardX`
- Parses JSON data from memory segments and extracts metrics
- Pushes metrics to VictoriaMetrics in time-series format
- Runs continuously on a 2-minute schedule
- Ships as a Docker image for local and remote deployments
- Publishes container images to GHCR via GitHub Actions

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

## Consuming the published image

### Docker Compose

1. Copy the example env file and set your Screeps token:

```bash
cp .env.example .env
```

2. Edit `.env` and set at least:

```dotenv
SCREEPS_TOKEN=your-screeps-token
VICTORIA_METRICS_URL=http://victoriametrics:8428
SCREEPS_AGENT_IMAGE=ghcr.io/breuerfelix/screeps-agent:main
```

3. Start the stack:

```bash
docker compose up -d
```

The included `docker-compose.yml` consumes the published GHCR image by default instead of rebuilding locally.

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

## Security notes

- Do not commit real Screeps tokens to the repository.
- Keep deployment credentials in environment variables or secret stores.
- If you want anonymous pulls from GHCR, change the package visibility in GitHub from private to public after the first publish.
- If workflow pushes fail with package permission errors, verify repository Actions settings allow `GITHUB_TOKEN` read and write permissions.
