local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local graphPanel = grafana.graphPanel;
local pieChartPanel = grafana.pieChartPanel;
local prometheus = grafana.prometheus;
local template = grafana.template;
local row = grafana.row;

// Import panel modules
local gclGplPanels = import 'panels/gcl_gpl_panels.libsonnet';
local rclPanels = import 'panels/rcl_panels.libsonnet';

// Reusable style objects
local styles = {
  // Standard line with no fill
  standardLine: {
    fill: 0,
    linewidth: 1,
  },
  
  // Line with fill (for actual values like CPU Used, Energy Produced)
  filledLine: {
    linewidth: 1,
    fill: 2,
  },
  
  // Dotted average line style
  avgLine: {
    dashes: true,
    dashLength: 10,
    spaceLength: 10,
    fill: 0,
    linewidth: 3,
  },
  
  // Limit/threshold line style
  limitLine: {
    color: 'red',
    fill: 0,
    linewidth: 2,
  },
};

// Calculate Y positions
local cpuY = 0;
local cpuHeight = 12;
local energyRowY = cpuY + cpuHeight;
local energyY = energyRowY + 1;
local energyHeight = 12;
local gclGplRowY = energyY + energyHeight;
local gclGplY = gclGplRowY + 1;
local gclGplObj = gclGplPanels.new(gclGplY);
local rclRowY = gclGplY + gclGplObj.rowHeight;
local rclY = rclRowY + 1;

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
    multi=false,
    includeAll=true,
    allValues='.*',
    sort=1,
  )
)
.addTemplate(
  template.new(
    'room_upgrading',
    'VictoriaMetrics',
    'query_result(screeps_room_rcl_level{shard="$shard"} < 8)',
    label='RCL < 8 Rooms',
    regex='/room="([^"]+)"/',
    refresh='time',
    multi=true,
    includeAll=true,
    allValues='.*',
    sort=1,
    hide=2,  // Hide variable from UI
  )
)
// === CPU PANEL ===
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
    staircase=true,
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
      yaxis: 2,
    }
  )
  .addSeriesOverride({
    alias: 'CPU Used',
  } + styles.standardLine)
  .addSeriesOverride({
    alias: 'CPU Used (10m avg)',
  } + styles.avgLine)
  .addSeriesOverride({
    alias: 'CPU Limit',
  } + styles.limitLine)
  .addSeriesOverride({
    alias: 'CPU Bucket',
    yaxis: 2,
    fill: 0,
  })
  {
    yaxes: [
      {
        format: 'ms',
        label: 'CPU',
        show: true,
        decimals: 0,
      },
      {
        format: 'short',
        label: 'Bucket',
        show: true,
        decimals: 0,
        min: 0,
        max: 10000,
      },
    ],
  },
  gridPos={
    x: 0,
    y: cpuY,
    w: 24,
    h: cpuHeight,
  }
)
// === ENERGY METRICS ROW ===
.addPanel(
  row.new(
    title='Energy Metrics',
  ),
  gridPos={
    x: 0,
    y: energyRowY,
    w: 24,
    h: 1,
  }
)
.addPanel(
  pieChartPanel.new(
    'Energy Consumption Breakdown',
    datasource='VictoriaMetrics',
    description='Average energy consumption by type (excluding mined/production)',
    pieType='pie',
    showLegend=true,
    showLegendPercentage=true,
  )
  .addTarget(
    prometheus.target(
      'sum by (type) (abs(avg_over_time(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined"}[$__range])))',
      legendFormat='{{type}}',
      instant=true,
    )
  ),
  gridPos={
    x: 0,
    y: energyY,
    w: 6,
    h: energyHeight,
  }
)
.addPanel(
  pieChartPanel.new(
    'Production vs Consumption',
    datasource='VictoriaMetrics',
    description='Green = Produced, Blue = Consumed',
    pieType='pie',
    showLegend=true,
    showLegendPercentage=true,
  )
  .addTarget(
    prometheus.target(
      |||
        sum(avg_over_time(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"}[$__range]))
      |||,
      legendFormat='Produced',
      instant=true,
    )
  )
  .addTarget(
    prometheus.target(
      |||
        sum(abs(avg_over_time(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined"}[$__range])))
      |||,
      legendFormat='Consumed',
      instant=true,
    )
  ) + {
    aliasColors: {
      'Produced': 'green',
      'Consumed': 'blue',
    },
  },
  gridPos={
    x: 6,
    y: energyY,
    w: 6,
    h: energyHeight,
  }
)
.addPanel(
  graphPanel.new(
    'Energy Production',
    datasource='VictoriaMetrics',
    description='Energy production over time (mined energy)',
    format='none',
    legend_show=true,
    legend_values=true,
    legend_min=true,
    legend_max=true,
    legend_avg=true,
    legend_current=true,
    legend_alignAsTable=true,
    legend_rightSide=false,
    staircase=true,
  )
  .addTarget(
    prometheus.target(
      'sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})',
      legendFormat='Energy Produced',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})[$__range])',
      legendFormat='Energy Produced (avg)',
    )
  )
  .addSeriesOverride({
    alias: 'Energy Produced',
    color: 'green',
  } + styles.filledLine)
  .addSeriesOverride({
    alias: 'Energy Produced (avg)',
    color: 'blue',
  } + styles.avgLine) + {
    yaxes: [
      {
        format: 'none',
        label: 'Energy/tick',
        show: true,
        decimals: 1,
      },
      {
        show: false,
      },
    ],
  },
  gridPos={
    x: 12,
    y: energyY,
    w: 12,
    h: energyHeight,
  }
)
.addPanel(
  graphPanel.new(
    'Energy Consumption by Type',
    datasource='VictoriaMetrics',
    description='Stacked view of energy consumption by different activities',
    format='none',
    legend_show=true,
    legend_values=true,
    legend_min=false,
    legend_max=false,
    legend_avg=true,
    legend_current=true,
    legend_alignAsTable=true,
    legend_rightSide=false,
    stack=true,
    fill=5,
    linewidth=1,
    staircase=true,
  )
  .addTarget(
    prometheus.target(
      'sum by (type) (abs(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined", type!="spawn"}))',
      legendFormat='{{type}}',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(abs(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="spawn"}))[$__range])',
      legendFormat='spawn',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})[$__range])',
      legendFormat='production (avg)',
    )
  )
  .addSeriesOverride({
    alias: 'spawn',
    color: 'orange',
  })
  .addSeriesOverride({
    alias: 'production (avg)',
    stack: false,
    color: 'green',
  } + styles.avgLine) + {
    yaxes: [
      {
        format: 'none',
        label: 'Energy/tick',
        show: true,
        decimals: 1,
      },
      {
        show: false,
      },
    ],
  },
  gridPos={
    x: 0,
    y: energyY + energyHeight,
    w: 24,
    h: energyHeight,
  }
)
// === GCL & GPL ROW ===
.addPanel(
  row.new(
    title='Global Control Level (GCL) & Global Power Level (GPL)',
  ),
  gridPos={
    x: 0,
    y: gclGplRowY,
    w: 24,
    h: 1,
  }
)
.addPanels(gclGplObj.panels)
// === RCL ROWS (one per room) ===
.addPanels(rclPanels.new(rclRowY).panels)
