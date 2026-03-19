# Screeps Monitoring Agent

This Node.js agent fetches memory segments from the Screeps API and pushes metrics to VictoriaMetrics for monitoring and visualization in Grafana.

## Features

- Fetches memory segments from all Screeps shards (shard1, shard3, shardSeason)
- Parses JSON data from memory segments and extracts metrics
- Pushes metrics to VictoriaMetrics in proper time-series format
- Runs continuously with 3-minute intervals using cron scheduling
- Handles different types of data: stats, rooms, market, military, economy
- Dockerized for easy deployment
- Built with Node.js 18+ for optimal performance

## Quick Start

1. **Configure your Screeps token**:

   - Update the `SCREEPS_TOKEN` in `docker-compose.yml` with your actual Screeps API token
   - Get your token from: https://screeps.com/a/#!/account/auth-tokens

2. **Start the monitoring stack**:

   ```bash
   docker-compose up -d
   ```

3. **Access Grafana**:

   - URL: http://localhost:3000
   - Username: admin
   - Password: jamo

4. **VictoriaMetrics**:
   - API: http://localhost:8428
   - Query interface: http://localhost:8428/vmui

## Development & Testing

### Local Development

```bash
# Install dependencies
npm install

# Run the agent locally
npm start

# Run in test mode (single execution)
TEST_MODE=true npm start

# Run tests
npm test
```

### Testing with Sample Data

```bash
# Run the test script to verify the agent works with sample data
node test-agent.js
```

## Quick Start

### Prerequisites

- Docker and Docker Compose installed on your system

### Running Grafana and Victoria Metrics

1. Start the services:

```bash
docker-compose up -d
```

2. Access Grafana:

   - URL: http://localhost:3000
   - Username: `admin`
   - Password: `adminadmin`

3. Access Victoria Metrics:
   - URL: http://localhost:8428
   - Web interface for queries and debugging

### Services Included

- **Grafana** (port 3000): Visualization and dashboards
- **Victoria Metrics** (port 8428): High-performance time-series database

### Configuration

#### Victoria Metrics Setup

Victoria Metrics is configured with:

- Data retention: 30 days
- Storage path: `./data/metrics`
- Prometheus-compatible API on port 8428

#### Grafana Setup

Grafana comes pre-configured with:

- Victoria Metrics datasource (both native plugin and Prometheus-compatible)
- Sample Screeps dashboard with PromQL queries
- Dashboard auto-discovery from the `grafana/dashboards/` directory

### Sample Dashboards

Two sample Screeps dashboards are included:

1. `screeps-dashboard.json` - Original InfluxDB version (for reference)
2. `screeps-dashboard-vm.json` - Victoria Metrics version with PromQL queries

Panels include:

- Energy levels over time
- GCL (Global Control Level) gauge
- Creep count by room

### Data Ingestion

Victoria Metrics accepts data in multiple formats:

#### Prometheus Format (Recommended)

Send metrics to: `http://localhost:8428/api/v1/import/prometheus`

Example metrics:

```
screeps_energy{room="W1N1"} 1000
screeps_gcl_level 5
screeps_creeps_count{room="W1N1",role="harvester"} 2
```

#### InfluxDB Line Protocol

Send metrics to: `http://localhost:8428/api/v1/import/influx`

Example metrics:

```
energy,room=W1N1 value=1000
gcl level=5
creeps,room=W1N1,role=harvester count=2
```

### Stopping the Services

```bash
docker-compose down
```

To also remove the data (metrics will be lost):

```bash
docker-compose down && rm -rf data/
```

### Why Victoria Metrics?

Victoria Metrics offers several advantages:

- **High performance**: Much faster than InfluxDB for single-node setups
- **Low resource usage**: Perfect for low-performance servers
- **Prometheus compatibility**: Easy migration and familiar PromQL
- **Multiple ingestion formats**: Supports both Prometheus and InfluxDB protocols
- **Built-in deduplication**: Handles duplicate metrics automatically

### Security Notes

⚠️ **Important**: This setup is for local development only. For production use:

- Change the default passwords
- Use proper authentication and authorization
- Consider using environment variables for sensitive configuration
- Set up proper network security

### Customizing Dashboards

1. Place your custom dashboard JSON files in `grafana/dashboards/`
2. Restart Grafana: `docker-compose restart grafana`
3. Dashboards will be automatically loaded

### Adding More Datasources

Add datasource configuration files in `grafana/datasources/` following the same YAML format.
