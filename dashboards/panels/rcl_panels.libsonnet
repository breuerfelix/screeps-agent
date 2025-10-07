local grafana = import '../grafonnet-lib/grafonnet/grafana.libsonnet';
local singlestat = grafana.singlestat;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;
local row = grafana.row;

{
  // Reusable avgLine style
  local avgLine = {
    dashes: true,
    dashLength: 10,
    spaceLength: 10,
    fill: 0,
    linewidth: 3,
  },

  // Create RCL panels - one row per room (only shows rooms with RCL < 8)
  // Each room gets its own row with 4 panels side by side
  // Note: When all rooms are RCL 8, an "All" row with "No data" panels will appear
  // This is standard Grafana behavior for repeating panels with empty variables
  new(startY):: {
    panels: [
      // Row for each room (repeats only for rooms with RCL < 8)
      row.new(
        title='$room_upgrading',
        repeat='room_upgrading',
        collapse=false,
      ) + {
        gridPos: {
          x: 0,
          y: startY,
          w: 24,
          h: 1,
        },
      },

      // RCL Level
      singlestat.new(
        'RCL',
        datasource='VictoriaMetrics',
        format='none',
        valueName='current',
        valueFontSize='120%',
        decimals=0,
      )
      .addTarget(
        prometheus.target(
          'screeps_room_rcl_level{shard="$shard", room="$room_upgrading"}',
        )
      ) + {
        gridPos: {
          x: 0,
          y: startY + 1,
          w: 6,
          h: 6,
        },
      },

      // RCL Progress
      singlestat.new(
        'RCL Progress',
        datasource='VictoriaMetrics',
        format='percent',
        valueName='current',
        valueFontSize='80%',
        decimals=2,
        gaugeShow=true,
        gaugeMinValue=0,
        gaugeMaxValue=100,
        gaugeThresholdMarkers=true,
        thresholds='50,80',
      )
      .addTarget(
        prometheus.target(
          '(screeps_room_rcl_progress{shard="$shard", room="$room_upgrading"} / screeps_room_rcl_progressTotal{shard="$shard", room="$room_upgrading"}) * 100',
        )
      ) + {
        gridPos: {
          x: 6,
          y: startY + 1,
          w: 6,
          h: 6,
        },
      },

      // Time to Next RCL
      singlestat.new(
        'Time to Next RCL (weeks)',
        datasource='VictoriaMetrics',
        format='none',
        valueName='current',
        valueFontSize='80%',
        decimals=3,
      )
      .addTarget(
        prometheus.target(
          '(screeps_room_rcl_progressTotal{shard="$shard", room="$room_upgrading"} - screeps_room_rcl_progress{shard="$shard", room="$room_upgrading"}) / (deriv(screeps_room_rcl_progress{shard="$shard", room="$room_upgrading"}[1h]) * 3600 * 24 * 7)',
        )
      ) + {
        gridPos: {
          x: 12,
          y: startY + 1,
          w: 6,
          h: 6,
        },
      },

      // RCL Upgrade Rate
      graphPanel.new(
        'RCL Upgrade',
        datasource='VictoriaMetrics',
        format='short',
        legend_show=true,
        legend_values=true,
        legend_min=true,
        legend_max=true,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
        staircase=true,
      )
      .addTarget(
        prometheus.target(
          'screeps_room_rcl_progress{shard="$shard", room="$room_upgrading"}',
          legendFormat='RCL per tick',
        )
      )
      .addTarget(
        prometheus.target(
          'avg_over_time(screeps_room_rcl_progress{shard="$shard", room="$room_upgrading"}[1h])',
          legendFormat='1hr Moving Average',
        )
      )
      .addSeriesOverride({
        alias: '1hr Moving Average',
      } + avgLine) + {
        gridPos: {
          x: 18,
          y: startY + 1,
          w: 6,
          h: 6,
        },
      },
    ],
    
    rowHeight: 7,  // 1 for row header + 6 for panels (repeats per room)
  },
}
