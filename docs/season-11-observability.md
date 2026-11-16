# Season 11 observability stack

`docker-compose.season-11.yml` is a Portainer/Docker Compose deployment for the official Screeps Season 11 world. It runs only the agent and attaches to the existing external monitoring network; it does not create a second Grafana, Loki, or VictoriaMetrics instance.

## Configuration

Set these stack environment values in Portainer or an equivalent secret store:

```env
SCREEPS_SEASON11_TOKEN=replace-with-season-11-token
VICTORIA_METRICS_URL=http://victoriametrics:8428
LOKI_URL=http://loki:3100
MONITORING_NETWORK=monitoring_monitoring
SCREEPS_AGENT_IMAGE=ghcr.io/breuerfelix/screeps-agent:main
```

The stack hard-codes the target to:

- base URL: `https://screeps.com`
- shard: `shardSeason`
- memory-segment metrics: VictoriaMetrics
- console websocket logs: Loki

The token is intentionally supplied through `SCREEPS_SEASON11_TOKEN` and is never stored in this repository.

## Separation from the official-world agent

Run this as a separate agent instance. The current agent's metric schema uses `shard` as its primary label and the console stream also includes `server_host`. Before enabling this stack, ensure the existing official-world agent is not also scraping `shardSeason`; configure that agent for its actual production shards (for example, `shardX`) to avoid duplicate Season 11 writes.

## Grafana queries

The agent's memory-segment metrics are stored with the existing bot metric names and `shard="shardSeason"`. Season 11 progress written by the bot is exposed as metrics such as:

```promql
screeps_persistent_season11_visibleReactors{shard="shardSeason"}
screeps_persistent_season11_availableReactors{shard="shardSeason"}
screeps_persistent_season11_activeReactors{shard="shardSeason"}
screeps_persistent_season11_thoriumStored{shard="shardSeason"}
screeps_persistent_season11_thoriumInTarget{shard="shardSeason"}
screeps_persistent_season11_deliveries{shard="shardSeason"}
```

Console logs can be queried in Loki with:

```logql
{source="screeps_console", server_host="screeps.com", shard="shardSeason"}
```

The agent and stack are prepared only. Do not start them until the Season 11 token, the monitoring network names, and the deployment target have been confirmed.
