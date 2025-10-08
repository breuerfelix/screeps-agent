local grafana = import '../grafonnet-lib/grafonnet/grafana.libsonnet';
local graphPanel = grafana.graphPanel;
local pieChartPanel = grafana.pieChartPanel;
local prometheus = grafana.prometheus;

{
  // Create Creep panels for a visualization row
  new(startY):: {
    local panelHeight = 12,
    
    panels: [
      // Total creeps by role (pie chart)
      pieChartPanel.new(
        'Current Creeps by Role',
        datasource='VictoriaMetrics',
        description='Distribution of current creeps across roles',
        pieType='pie',
        showLegend=true,
        showLegendPercentage=true,
      )
      .addTarget(
        prometheus.target(
          'sum by (role) (screeps_room_creeps_current{shard="$shard", room=~"$room"})',
          legendFormat='{{role}}',
          instant=true,
        )
      ) + {
        gridPos: {
          x: 0,
          y: startY,
          w: 8,
          h: panelHeight,
        },
      },
    
      // Creeps over time by role (stacked graph)
      graphPanel.new(
        'Creeps Over Time by Role',
        datasource='VictoriaMetrics',
        description='Number of creeps per role over time',
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
          'sum by (role) (screeps_room_creeps_current{shard="$shard", room=~"$room"})',
          legendFormat='{{role}}',
        )
      )
      .addTarget(
        prometheus.target(
          'avg_over_time(sum(screeps_room_creeps_current{shard="$shard", room=~"$room"})[$__range])',
          legendFormat='Total (avg)',
        )
      )
      .addSeriesOverride({
        alias: 'Total (avg)',
        stack: false,
        fill: 0,
        linewidth: 3,
        color: 'yellow',
        dashes: true,
        dashLength: 10,
        spaceLength: 10,
      }) + {
        yaxes: [
          {
            format: 'none',
            label: 'Creeps',
            show: true,
            decimals: 0,
          },
          {
            show: false,
          },
        ],
        gridPos: {
          x: 8,
          y: startY,
          w: 16,
          h: panelHeight,
        },
      },
    
      // Creep deficit by role - shows missing creeps (needed > current)
      graphPanel.new(
        'Creep Deficit by Role',
        datasource='VictoriaMetrics',
        description='Shows how many more creeps are needed per role (only shows deficits)',
        format='none',
        legend_show=true,
        legend_values=true,
        legend_min=false,
        legend_max=true,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
        legend_rightSide=true,
        bars=false,
        lines=true,
        staircase=true,
        fill=2,
        linewidth=1,
      )
      .addTarget(
        prometheus.target(
          'clamp_min(sum by (role) (screeps_room_creeps_needed{shard="$shard", room=~"$room"}) - sum by (role) (screeps_room_creeps_current{shard="$shard", room=~"$room"}), 0)',
          legendFormat='{{role}}',
        )
      ) + {
        yaxes: [
          {
            format: 'none',
            label: 'Missing Creeps',
            show: true,
            decimals: 0,
            min: 0,
          },
          {
            show: false,
          },
        ],
        gridPos: {
          x: 0,
          y: startY + panelHeight,
          w: 24,
          h: panelHeight,
        },
        nullPointMode: 'null as zero',
      },
    ],
    
    rowHeight: panelHeight * 2,  // Two rows of panels
  },
}
