local grafana = import '../grafonnet-lib/grafonnet/grafana.libsonnet';
local singlestat = grafana.singlestat;
local graphPanel = grafana.graphPanel;
local pieChartPanel = grafana.pieChartPanel;
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

  // Create GPL panels (2 rows: GPL stats + Power metrics)
  new(startY):: {
    panels: [
      // ===== ROW 1: GPL Stats =====
      
      // GPL Level
      singlestat.new(
        'GPL',
        datasource='VictoriaMetrics',
        format='none',
        valueName='current',
        valueFontSize='120%',
        decimals=0,
      )
      .addTarget(
        prometheus.target(
          'screeps_gpl_level{shard="$shard"}',
        )
      ) + {
        gridPos: {
          x: 0,
          y: startY,
          w: 6,
          h: 6,
        },
      },

      // GPL Progress
      singlestat.new(
        'GPL Progress',
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
          '(screeps_gpl_progress{shard="$shard"} / screeps_gpl_progressTotal{shard="$shard"}) * 100',
        )
      ) + {
        gridPos: {
          x: 6,
          y: startY,
          w: 6,
          h: 6,
        },
      },

      // Time to Next GPL
      singlestat.new(
        'Time to Next GPL (days)',
        datasource='VictoriaMetrics',
        format='none',
        valueName='current',
        valueFontSize='80%',
        decimals=3,
      )
      .addTarget(
        prometheus.target(
          '(screeps_gpl_progressTotal{shard="$shard"} - screeps_gpl_progress{shard="$shard"}) / (deriv(screeps_gpl_progress{shard="$shard"}[1h]) * 3600 * 24)',
        )
      ) + {
        gridPos: {
          x: 12,
          y: startY,
          w: 6,
          h: 6,
        },
      },

      // GPL Upgrade Rate
      graphPanel.new(
        'GPL Upgrade',
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
          'screeps_gpl_progress{shard="$shard"}',
          legendFormat='GPL per tick',
        )
      )
      .addTarget(
        prometheus.target(
          'avg_over_time(screeps_gpl_progress{shard="$shard"}[1h])',
          legendFormat='1hr Moving Average',
        )
      )
      .addSeriesOverride({
        alias: '1hr Moving Average',
      } + avgLine) + {
        gridPos: {
          x: 18,
          y: startY,
          w: 6,
          h: 6,
        },
      },
      
      // ===== ROW 2: Power Metrics =====
      
      // Power Over Time by Room
      graphPanel.new(
        'Power by Room',
        datasource='VictoriaMetrics',
        format='short',
        legend_show=true,
        legend_values=true,
        legend_min=false,
        legend_max=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
        legend_rightSide=false,
        staircase=false,
        stack=true,
      )
      .addTarget(
        prometheus.target(
          'screeps_room_assets{shard="$shard", resource="power", room=~"$room"}',
          legendFormat='{{room}}',
        )
      ) + {
        gridPos: {
          x: 0,
          y: startY + 6,
          w: 12,
          h: 8,
        },
      },

      // Power Distribution Pie Chart
      pieChartPanel.new(
        'Power Distribution',
        datasource='VictoriaMetrics',
        pieType='pie',
      )
      .addTarget(
        prometheus.target(
          'sum by (room) (screeps_room_assets{shard="$shard", resource="power", room=~"$room"})',
          legendFormat='{{room}}',
          instant=true,
        )
      ) + {
        gridPos: {
          x: 12,
          y: startY + 6,
          w: 12,
          h: 8,
        },
      },
    ],
    
    rowHeight: 14,  // Total height for GPL row (6) + Power row (8)
  },
}
