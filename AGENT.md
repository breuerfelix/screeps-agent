# Dashboard Build & Deployment Guide

## Overview

The Screeps monitoring dashboard is built using **Jsonnet** and **Grafonnet** (a Grafana dashboard library). The dashboard is defined in code and compiled to JSON, then pushed to Grafana via its API.

## Architecture

### Components

1. **Jsonnet Files** - Dashboard definition as code
   - `cpu_dashboard.jsonnet` - Main dashboard definition
   - `panels/*.libsonnet` - Reusable panel modules
     - `gcl_gpl_panels.libsonnet` - GCL/GPL level panels
     - `rcl_panels.libsonnet` - Room Control Level panels
     - `creep_panels.libsonnet` - Creep metrics panels
     - `asset_panels.libsonnet` - Asset tracking panels

2. **Grafonnet Library** - Located in `grafonnet-lib/`
   - Provides Jsonnet functions for creating Grafana objects
   - Includes dashboard, panel, target, and template builders

3. **Build Scripts**
   - `build_and_update.sh` - Builds and deploys the dashboard
   - `update_dashboard.sh` - Uploads the compiled JSON to Grafana

4. **Compiled Output**
   - `cpu_dashboard.json` - The final JSON dashboard (77 KB)

## Build Process

### Prerequisites

- **jsonnet** must be installed (currently available at `/opt/homebrew/bin/jsonnet`)
- **jq** for JSON processing
- **curl** for API calls
- Access to Grafana instance

### Building the Dashboard

The build process is automated by `build_and_update.sh`:

```bash
cd dashboards
./build_and_update.sh
```

This script does two things:

1. **Compiles Jsonnet to JSON**:
   ```bash
   jsonnet -J grafonnet-lib cpu_dashboard.jsonnet -o cpu_dashboard.json
   ```
   - `-J grafonnet-lib` adds the library to the import path
   - Outputs to `cpu_dashboard.json`

2. **Uploads to Grafana** (via `update_dashboard.sh`)

### Deployment to Grafana

The `update_dashboard.sh` script:

**Configuration**:
- Grafana URL: `http://192.168.178.13:3001`
- Authentication: `admin:jamo`
- Dashboard file: `cpu_dashboard.json`

**Upload Process**:
```bash
curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -u admin:jamo \
  -H "Content-Type: application/json" \
  -d @<(cat "$DASHBOARD_FILE" | jq '{dashboard: ., overwrite: true}')
```

The API call:
- Uses Grafana's `/api/dashboards/db` endpoint
- Sets `overwrite: true` to update existing dashboards by UID
- Returns dashboard UID, version, and URL on success

### Current Status

✅ **Working** - Last successful deployment:
- Dashboard UID: `screeps-metrics`
- Version: 55
- URL: http://192.168.178.13:3001/d/screeps-metrics/screeps-metrics

## Development Workflow

### Making Changes

1. **Edit the Jsonnet files**:
   - Main dashboard: `cpu_dashboard.jsonnet`
   - Panel modules: `panels/*.libsonnet`

2. **Build and deploy**:
   ```bash
   cd dashboards
   ./build_and_update.sh
   ```

3. **Verify in Grafana**:
   - Open: http://192.168.178.13:3001/d/screeps-metrics/screeps-metrics
   - Check that your changes appear correctly

### Development Tips

- **Compile only** (without uploading):
  ```bash
  jsonnet -J grafonnet-lib cpu_dashboard.jsonnet -o cpu_dashboard.json
  ```

- **Upload only** (without recompiling):
  ```bash
  ./update_dashboard.sh
  ```

- **View compiled JSON** to debug:
  ```bash
  cat cpu_dashboard.json | jq '.'
  ```

### Panel Structure

Panels are organized in modular files for maintainability:

```
dashboards/
├── cpu_dashboard.jsonnet      # Main dashboard (imports panels)
├── panels/
│   ├── gcl_gpl_panels.libsonnet  # GCL/GPL level displays
│   ├── rcl_panels.libsonnet      # Room control level metrics
│   ├── creep_panels.libsonnet    # Creep statistics
│   └── asset_panels.libsonnet    # Asset tracking
└── grafonnet-lib/              # Grafana dashboard library
```

Each panel module exports a `new(startY)` function that:
- Takes a Y position for layout
- Returns panel definitions with proper positioning
- Uses VictoriaMetrics as the data source

### Common Panel Patterns

**Graph Panel**:
```jsonnet
graphPanel.new(
  'Panel Title',
  datasource='VictoriaMetrics',
  ...
)
.addTarget(
  prometheus.target('your_metric_query')
)
```

**Singlestat Panel**:
```jsonnet
singlestat.new(
  'Stat Name',
  datasource='VictoriaMetrics',
  format='none',
  ...
)
.addTarget(
  prometheus.target('scalar_metric')
)
```

## Troubleshooting

### Build Errors

**"jsonnet: command not found"**
- Install jsonnet: `brew install jsonnet`

**"jq: command not found"**
- Install jq: `brew install jq`

**Import errors**:
- Ensure you're in the `dashboards/` directory
- Check that `grafonnet-lib/` exists and is complete

### Deployment Errors

**Connection refused**:
- Verify Grafana is running: `docker-compose ps`
- Check URL is correct: `http://192.168.178.13:3001`

**Authentication failed**:
- Verify credentials in `update_dashboard.sh`
- Current credentials: `admin:jamo`

**Dashboard not updating**:
- Check the dashboard UID matches: `screeps-metrics`
- Ensure `overwrite: true` is set in the API call

## Data Source

The dashboard uses **VictoriaMetrics** as the Prometheus-compatible data source:
- API endpoint: http://localhost:8428
- Metrics are pushed by the Node.js agent from Screeps memory segments
- 30-day retention period

## Future Improvements

Potential enhancements:
- [ ] Add version control for dashboard changes
- [ ] Create CI/CD pipeline for automatic deployment
- [ ] Add dashboard backup/export functionality
- [ ] Create more modular panel libraries
- [ ] Add dashboard tests/validation
- [ ] Document metric naming conventions
