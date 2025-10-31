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

  // Create GCL and GPL panels in one row (2 rows of panels, same visualization group)
  new(startY):: {
    panels: [
      // GCL Level
      singlestat.new(
        'GCL',
        datasource='VictoriaMetrics',
        format='none',
        valueName='current',
        valueFontSize='120%',
        decimals=0,
      )
      .addTarget(
        prometheus.target(
          'screeps_gcl_level{shard="$shard"}',
        )
      ) + {
        gridPos: {
          x: 0,
          y: startY,
          w: 6,
          h: 6,
        },
      },

      // GCL Progress
      singlestat.new(
        'GCL Progress',
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
          '(screeps_gcl_progress{shard="$shard"} / screeps_gcl_progressTotal{shard="$shard"}) * 100',
        )
      ) + {
        gridPos: {
          x: 6,
          y: startY,
          w: 6,
          h: 6,
        },
      },

      // Time to Next GCL
      singlestat.new(
        'Time to Next GCL (weeks)',
        datasource='VictoriaMetrics',
        format='none',
        valueName='current',
        valueFontSize='80%',
        decimals=3,
      )
      .addTarget(
        prometheus.target(
          '(screeps_gcl_progressTotal{shard="$shard"} - screeps_gcl_progress{shard="$shard"}) / (deriv(screeps_gcl_progress{shard="$shard"}[1h]) * 3600 * 24 * 7)',
        )
      ) + {
        gridPos: {
          x: 12,
          y: startY,
          w: 6,
          h: 6,
        },
      },

      // GCL Upgrade Rate
      graphPanel.new(
        'GCL Upgrade',
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
          'screeps_gcl_progress{shard="$shard"}',
          legendFormat='GCL per tick',
        )
      )
      .addTarget(
        prometheus.target(
          'avg_over_time(screeps_gcl_progress{shard="$shard"}[1h])',
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

      // GPL Level (second row)
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
          y: startY + 6,
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
          y: startY + 6,
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
          y: startY + 6,
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
          y: startY + 6,
          w: 6,
          h: 6,
        },
      },
    ],
    
    rowHeight: 12,  // Total height for both GCL and GPL rows
  },
}
