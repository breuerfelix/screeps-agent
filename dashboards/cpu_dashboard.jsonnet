local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local graphPanel = grafana.graphPanel;
local pieChartPanel = grafana.pieChartPanel;
local prometheus = grafana.prometheus;
local template = grafana.template;
local row = grafana.row;

// Import panel modules
local gclPanels = import 'panels/gcl_panels.libsonnet';
local gplPanels = import 'panels/gpl_panels.libsonnet';
local rclPanels = import 'panels/rcl_panels.libsonnet';
local creepPanels = import 'panels/creep_panels.libsonnet';
local assetPanels = import 'panels/asset_panels.libsonnet';

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
local cpuRowY = 0;
local cpuY = cpuRowY + 1;
local cpuHeight = 12;
local cpuPerCreepY = cpuY + cpuHeight;
local cpuPerCreepHeight = 12;
local cpuMemoryY = cpuPerCreepY + cpuPerCreepHeight;
local cpuMemoryHeight = 12;
local energyRowY = cpuMemoryY + cpuMemoryHeight;
local energyY = energyRowY + 1;
local energyHeight = 12;
local energyTotalHeight = energyHeight * 4;  // Energy section now has 4 rows
local creepsRowY = energyY + energyTotalHeight;
local creepsY = creepsRowY + 1;
local creepsObj = creepPanels.new(creepsY);
local assetsRowY = creepsY + creepsObj.rowHeight;
local assetsY = assetsRowY + 1;
local assetsObj = assetPanels.new(assetsY);
local gplRowY = assetsY + assetsObj.rowHeight;
local gplY = gplRowY + 1;
local gplObj = gplPanels.new(gplY);
local gclRowY = gplY + gplObj.rowHeight;
local gclY = gclRowY + 1;
local gclObj = gclPanels.new(gclY);
local rclRowY = gclY + gclObj.rowHeight;
local rclY = rclRowY + 1;

dashboard.new(
  'Screeps Metrics',
  description='CPU, Energy, GCL, GPL, and RCL monitoring',
  time_from='now-6h',
  refresh='30s',
  tags=['screeps', 'cpu'],
  editable=true,
  uid='screeps-metrics',
  graphTooltip='shared_crosshair',
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
// === CPU METRICS ROW ===
.addPanel(
  row.new(
    title='CPU Metrics',
  ),
  gridPos={
    x: 0,
    y: cpuRowY,
    w: 24,
    h: 1,
  }
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
      'avg_over_time(screeps_cpu_getUsed{shard="$shard"}[$__range])',
      legendFormat='CPU Used (avg)',
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
    alias: 'CPU Used (avg)',
    color: 'yellow',
  } + styles.avgLine)
  .addSeriesOverride({
    alias: 'CPU Limit',
  } + styles.limitLine)
  .addSeriesOverride({
    alias: 'CPU Bucket',
    yaxis: 2,
    fill: 0,
    fillBelowTo: null,
    linewidth: 1,
    color: 'rgba(255, 152, 48, 0.3)',
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
// === CPU PER CREEP PANEL ===
.addPanel(
  graphPanel.new(
    'CPU Usage per Creep',
    datasource='VictoriaMetrics',
    description='Average CPU usage per creep (Total CPU / Total Creeps)',
    format='ms',
    legend_show=true,
    legend_values=true,
    legend_min=false,
    legend_max=false,
    legend_avg=true,
    legend_current=true,
    legend_alignAsTable=true,
    legend_rightSide=false,
    stack=false,
    fill=1,
    linewidth=1,
    staircase=true,
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_getUsed{shard="$shard"} / sum(screeps_room_creeps_current{shard="$shard", room=~"$room"})',
      legendFormat='CPU per Creep',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time((screeps_cpu_getUsed{shard="$shard"} / sum(screeps_room_creeps_current{shard="$shard", room=~"$room"}))[$__range])',
      legendFormat='CPU per Creep (avg)',
    )
  )
  .addTarget(
    prometheus.target(
      'sum(screeps_room_creeps_current{shard="$shard", room=~"$room"})',
      legendFormat='Total Creeps',
    )
  )
  .addSeriesOverride({
    alias: 'CPU per Creep',
    color: 'green',
    linewidth: 1,
    fill: 2,
  })
  .addSeriesOverride({
    alias: 'CPU per Creep (avg)',
  } + styles.avgLine)
  .addSeriesOverride({
    alias: 'Total Creeps',
    yaxis: 2,
    color: 'orange',
    fill: 0,
  }) + {
    yaxes: [
      {
        format: 'ms',
        label: 'CPU per Creep',
        show: true,
        decimals: 2,
      },
      {
        format: 'short',
        label: 'Total Creeps',
        show: true,
        decimals: 0,
      },
    ],
  },
  gridPos={
    x: 0,
    y: cpuPerCreepY,
    w: 12,
    h: cpuPerCreepHeight,
  }
)
// === CPU PER ROOM PANEL ===
.addPanel(
  graphPanel.new(
    'CPU Usage per Room',
    datasource='VictoriaMetrics',
    description='Average CPU usage per room (Total CPU / Number of Rooms)',
    format='ms',
    legend_show=true,
    legend_values=true,
    legend_min=false,
    legend_max=false,
    legend_avg=true,
    legend_current=true,
    legend_alignAsTable=true,
    legend_rightSide=false,
    stack=false,
    fill=1,
    linewidth=1,
    staircase=true,
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_getUsed{shard="$shard"} / count(screeps_room_rcl_level{shard="$shard", room=~"$room"})',
      legendFormat='CPU per Room',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time((screeps_cpu_getUsed{shard="$shard"} / count(screeps_room_rcl_level{shard="$shard", room=~"$room"}))[$__range])',
      legendFormat='CPU per Room (avg)',
    )
  )
  .addTarget(
    prometheus.target(
      'count(screeps_room_rcl_level{shard="$shard", room=~"$room"})',
      legendFormat='Room Count',
    )
  )
  .addSeriesOverride({
    alias: 'CPU per Room',
    color: 'green',
    linewidth: 1,
    fill: 2,
  })
  .addSeriesOverride({
    alias: 'CPU per Room (avg)',
  } + styles.avgLine)
  .addSeriesOverride({
    alias: 'Room Count',
    yaxis: 2,
    color: 'orange',
    fill: 0,
  }) + {
    yaxes: [
      {
        format: 'ms',
        label: 'CPU per Room',
        show: true,
        decimals: 2,
      },
      {
        format: 'short',
        label: 'Room Count',
        show: true,
        decimals: 0,
      },
    ],
  },
  gridPos={
    x: 12,
    y: cpuPerCreepY,
    w: 12,
    h: cpuPerCreepHeight,
  }
)
// === MEMORY USAGE PANEL ===
.addPanel(
  graphPanel.new(
    'Memory Usage',
    datasource='VictoriaMetrics',
    description='Memory usage over time',
    format='bytes',
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
      'screeps_memory_used{shard="$shard"}',
      legendFormat='Memory Used',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(screeps_memory_used{shard="$shard"}[$__range])',
      legendFormat='Memory Used (avg)',
    )
  )
  .addSeriesOverride({
    alias: 'Memory Used',
    color: 'blue',
    fill: 1,
    linewidth: 1,
  })
  .addSeriesOverride({
    alias: 'Memory Used (avg)',
    color: 'yellow',
  } + styles.avgLine) + {
    yaxes: [
      {
        format: 'bytes',
        label: 'Memory',
        show: true,
        decimals: 0,
        min: 0,
      },
      {
        show: false,
      },
    ],
  },
  gridPos={
    x: 0,
    y: cpuMemoryY,
    w: 12,
    h: cpuMemoryHeight,
  }
)
// === CPU HEAP PANEL ===
.addPanel(
  graphPanel.new(
    'CPU Heap',
    datasource='VictoriaMetrics',
    description='CPU heap memory statistics',
    format='bytes',
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
      'screeps_cpu_heapStatistics_total_heap_size{shard="$shard"}',
      legendFormat='Total Heap Size',
    )
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_heapStatistics_used_heap_size{shard="$shard"}',
      legendFormat='Used Heap Size',
    )
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_heapStatistics_heap_size_limit{shard="$shard"}',
      legendFormat='Heap Size Limit',
    )
  )
  .addTarget(
    prometheus.target(
      'screeps_cpu_heapStatistics_externally_allocated_size{shard="$shard"}',
      legendFormat='Externally Allocated',
    )
  )
  .addSeriesOverride({
    alias: 'Used Heap Size',
    color: 'red',
    fill: 1,
    linewidth: 1,
  })
  .addSeriesOverride({
    alias: 'Total Heap Size',
    color: 'orange',
    fill: 0,
    linewidth: 1,
  })
  .addSeriesOverride({
    alias: 'Heap Size Limit',
    color: 'blue',
    fill: 0,
    linewidth: 2,
  })
  .addSeriesOverride({
    alias: 'Externally Allocated',
    color: 'green',
    fill: 0,
    linewidth: 1,
  }) + {
    yaxes: [
      {
        format: 'bytes',
        label: 'Heap Size',
        show: true,
        decimals: 0,
        min: 0,
      },
      {
        show: false,
      },
    ],
  },
  gridPos={
    x: 12,
    y: cpuMemoryY,
    w: 12,
    h: cpuMemoryHeight,
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
    'Production vs Consumption',
    datasource='VictoriaMetrics',
    description='Green = Produced, Blue = Consumed',
    pieType='pie',
    showLegend=true,
    showLegendPercentage=true,
    legendType='Under graph',
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
    x: 0,
    y: energyY,
    w: 6,
    h: energyHeight,
  }
)
.addPanel(
  graphPanel.new(
    'Production vs Consumption Balance',
    datasource='VictoriaMetrics',
    description='Averaged balance over selected time range. Green above zero = surplus production, Red below zero = deficit (consuming more than producing)',
    format='none',
    legend_show=true,
    legend_values=true,
    legend_min=false,
    legend_max=false,
    legend_avg=true,
    legend_current=true,
    legend_alignAsTable=true,
    legend_rightSide=false,
    stack=false,
    fill=5,
    linewidth=2,
    staircase=false,
  )
  .addTarget(
    prometheus.target(
      'clamp_min(avg_over_time(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})[$__range]) + avg_over_time(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined"})[$__range]), 0)',
      legendFormat='Surplus (Production > Consumption)',
    )
  )
  .addTarget(
    prometheus.target(
      'clamp_max(avg_over_time(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})[$__range]) + avg_over_time(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined"})[$__range]), 0)',
      legendFormat='Deficit (Consumption > Production)',
    )
  )
  .addSeriesOverride({
    alias: 'Surplus (Production > Consumption)',
    color: '#73BF69',  // Green
    linewidth: 2,
    fill: 5,
  })
  .addSeriesOverride({
    alias: 'Deficit (Consumption > Production)',
    color: '#F2495C',  // Red
    linewidth: 2,
    fill: 5,
  }) + {
    yaxes: [
      {
        format: 'none',
        label: 'Energy/tick',
        show: true,
        decimals: 2,
      },
      {
        show: false,
      },
    ],
    grid: {
      threshold1: 0,
      threshold1Color: 'rgba(216, 200, 27, 0.7)',
    },
  },
  gridPos={
    x: 6,
    y: energyY,
    w: 18,
    h: energyHeight,
  }
)
.addPanel(
  pieChartPanel.new(
    'Energy Production by Room',
    datasource='VictoriaMetrics',
    description='Distribution of energy production across rooms',
    pieType='pie',
    showLegend=true,
    showLegendPercentage=true,
  )
  .addTarget(
    prometheus.target(
      'sum by (room) (avg_over_time(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"}[$__range]))',
      legendFormat='{{room}}',
      instant=true,
    )
  ),
  gridPos={
    x: 0,
    y: energyY + energyHeight,
    w: 6,
    h: energyHeight,
  }
)
.addPanel(
  graphPanel.new(
    'Energy Production',
    datasource='VictoriaMetrics',
    description='Energy production over time by room (stacked)',
    format='none',
    legend_show=true,
    legend_values=true,
    legend_min=false,
    legend_max=false,
    legend_avg=true,
    legend_current=true,
    legend_alignAsTable=true,
    legend_rightSide=true,
    stack=true,
    fill=5,
    linewidth=1,
    staircase=true,
  )
  .addTarget(
    prometheus.target(
      'sum by (room) (screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})',
      legendFormat='{{room}}',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})[$__range])',
      legendFormat='Total (avg)',
    )
  )
  .addSeriesOverride({
    alias: 'Total (avg)',
    stack: false,
    fill: 0,
    linewidth: 3,
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
    x: 6,
    y: energyY + energyHeight,
    w: 18,
    h: energyHeight,
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
    y: energyY + (energyHeight * 2),
    w: 6,
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
    legend_rightSide=true,
    stack=true,
    fill=5,
    linewidth=1,
    staircase=true,
  )
  .addTarget(
    prometheus.target(
      'sum by (type) (abs(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined", type!="spawn", type!="factory"}))',
      legendFormat='{{type}}',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(abs(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="spawn"}))[$__range])',
      legendFormat='spawn (avg)',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(abs(sum(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="factory"}))[$__range])',
      legendFormat='factory (avg)',
    )
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(sum(abs(screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined"}))[$__range])',
      legendFormat='consumption (avg)',
    )
  )
  .addSeriesOverride({
    alias: 'spawn (avg)',
    color: 'orange',
  })
  .addSeriesOverride({
    alias: 'factory (avg)',
    color: 'purple',
  })
  .addSeriesOverride({
    alias: 'consumption (avg)',
    stack: false,
    color: 'yellow',
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
    x: 6,
    y: energyY + (energyHeight * 2),
    w: 18,
    h: energyHeight,
  }
)
.addPanel(
  pieChartPanel.new(
    'Spawn to Mine Ratio by Room',
    datasource='VictoriaMetrics',
    description='Ratio of mined energy to spawn energy cost per room (higher = more efficient)',
    pieType='pie',
    showLegend=true,
    showLegendPercentage=true,
    legendType='Right side',
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(sum by (room) (screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})[$__range]) / abs(avg_over_time(sum by (room) (screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="spawn"})[$__range]))',
      legendFormat='{{room}}',
      instant=true,
    )
  ),
  gridPos={
    x: 0,
    y: energyY + (energyHeight * 3),
    w: 6,
    h: energyHeight,
  }
)
.addPanel(
  graphPanel.new(
    'Energy Balance by Room',
    datasource='VictoriaMetrics',
    description='Energy balance per room (averaged over time). Green above zero = room produces surplus, Red below zero = room consumes more than it produces',
    format='none',
    legend_show=true,
    legend_values=true,
    legend_min=false,
    legend_max=false,
    legend_avg=true,
    legend_current=true,
    legend_alignAsTable=true,
    legend_rightSide=true,
    stack=false,
    fill=3,
    linewidth=1,
    staircase=false,
  )
  .addTarget(
    prometheus.target(
      'avg_over_time(sum by (room) (screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type="mined"})[$__range]) + avg_over_time(sum by (room) (screeps_room_instantEnergyUsage{shard="$shard", room=~"$room", type!="mined"})[$__range])',
      legendFormat='{{room}}',
    )
  )
  .addSeriesOverride({
    alias: '/.+/',
    color: '#73BF69',  // Default green for positive
  }) + {
    yaxes: [
      {
        format: 'none',
        label: 'Energy/tick',
        show: true,
        decimals: 2,
      },
      {
        show: false,
      },
    ],
    grid: {
      threshold1: 0,
      threshold1Color: 'rgba(216, 200, 27, 0.7)',
    },
  },
  gridPos={
    x: 6,
    y: energyY + (energyHeight * 3),
    w: 18,
    h: energyHeight,
  }
)
// === CREEPS ROW ===
.addPanel(
  row.new(
    title='Creeps',
  ),
  gridPos={
    x: 0,
    y: creepsRowY,
    w: 24,
    h: 1,
  }
)
.addPanels(creepsObj.panels)
// === ASSETS ROW ===
.addPanel(
  row.new(
    title='Room Assets',
  ),
  gridPos={
    x: 0,
    y: assetsRowY,
    w: 24,
    h: 1,
  }
)
.addPanels(assetsObj.panels)
// === GPL ROW ===
.addPanel(
  row.new(
    title='Global Power Level (GPL) & Power Resources',
  ),
  gridPos={
    x: 0,
    y: gplRowY,
    w: 24,
    h: 1,
  }
)
.addPanels(gplObj.panels)
// === GCL ROW ===
.addPanel(
  row.new(
    title='Global Control Level (GCL)',
  ),
  gridPos={
    x: 0,
    y: gclRowY,
    w: 24,
    h: 1,
  }
)
.addPanels(gclObj.panels)
// === RCL ROWS (one per room) ===
.addPanels(rclPanels.new(rclRowY).panels)
