local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;
local template = grafana.template;

dashboard.new(
  'Screeps CPU Metrics',
  description='CPU usage, limits, and bucket monitoring',
  time_from='now-6h',
  refresh='30s',
  tags=['screeps', 'cpu'],
  editable=true,
  uid='screeps-cpu-metrics',
)
.addTemplate(
  template.new(
    'shard',
    'VictoriaMetrics',
    'label_values(screeps_cpu_getUsed, shard)',
    label='Shard',
    refresh='time',
    multi=false,
    includeAll=false,
    sort=1,
  )
)
.addTemplate(
  template.new(
    'room',
    'VictoriaMetrics',
    'label_values(screeps_room_rcl_level{shard="$shard"}, room)',
    label='Room',
    refresh='time',
    multi=true,
    includeAll=true,
    sort=1,
  )
)
.addPanel(
  graphPanel.new(
    'CPU Usage & Bucket',
    datasource='VictoriaMetrics',
    description='CPU getUsed and limit on left axis, CPU bucket on right axis',
    format='none',
    legend_show=true,
    legend_values=true,
    legend_min=true,
    legend_max=true,
    legend_avg=true,
    legend_current=false,
    legend_alignAsTable=true,
    legend_rightSide=false,
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_getUsed{shard="$shard"}',
      legendFormat='CPU Used',
    )
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_limit{shard="$shard"}',
      legendFormat='CPU Limit',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(screeps_cpu_getUsed{shard="$shard"}[10m])',
      legendFormat='CPU Used (10m avg)',
    )
    {
      // Make this a dotted line
      dashes: true,
      dashLength: 10,
      spaceLength: 10,
    }
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_bucket{shard="$shard"}',
      legendFormat='CPU Bucket',
    )
    {
      // This target uses the right Y-axis
      yaxis: 2,
    }
  )
  .addSeriesOverride({
    alias: 'CPU Used (10m avg)',
    dashes: true,
    dashLength: 10,
    spaceLength: 10,
    fill: 0,
    linewidth: 2,
  })
  .addSeriesOverride({
    alias: 'CPU Limit',
    color: 'red',
    fill: 0,
    linewidth: 2,
  })
  .addSeriesOverride({
    alias: 'CPU Bucket',
    yaxis: 2,
    fill: 0,
  })
  {
    // Configure the Y-axes
    yaxes: [
      {
        format: 'none',
        label: 'CPU',
        show: true,
        decimals: 2,
      },
      {
        format: 'none',
        label: 'Bucket',
        show: true,
        decimals: 0,
      },
    ],
  },
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 12,
  }
)
