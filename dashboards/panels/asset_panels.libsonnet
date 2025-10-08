local grafana = import '../grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local singlestat = grafana.singlestat;
local graph = grafana.graphPanel;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local pieChartPanel = grafana.pieChartPanel;
local pieChartPanel = grafana.pieChartPanel;

{
  new(startY):: {
    local panelHeight = 12,
    local panelWidth = 24,
    
    panels: [
      // Energy per room - stacked time series
      graphPanel.new(
        'Energy per Room Over Time',
        datasource='VictoriaMetrics',
        description='Energy storage by room over time (stacked)',
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
        fill=2,
        linewidth=1,
        staircase=true,
      )
      .addTarget(
        prometheus.target(
          'sum by (room) (screeps_room_assets{shard="$shard", room=~"$room", resource="energy"})',
          legendFormat='{{room}}',
        )
      ) + {
        yaxes: [
          {
            format: 'none',
            label: 'Energy',
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
          y: startY,
          w: 16,
          h: panelHeight,
        },
      },
      
      // Energy distribution pie chart
      pieChartPanel.new(
        'Energy Distribution by Room',
        datasource='VictoriaMetrics',
        description='Current energy distribution across rooms',
        pieType='pie',
        showLegend=true,
        showLegendPercentage=true,
        legendType='Right side',
      )
      .addTarget(
        prometheus.target(
          'sum by (room) (screeps_room_assets{shard="$shard", room=~"$room", resource="energy"} > 0)',
          legendFormat='{{room}}',
          instant=true,
        )
      ) + {
        gridPos: {
          x: 16,
          y: startY,
          w: 8,
          h: panelHeight,
        },
      },
      
      // All resources stacked time series (ALL resources)
      graphPanel.new(
        'All Room Resources Over Time',
        datasource='VictoriaMetrics',
        description='All resources in selected rooms over time (no limit)',
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
        fill=2,
        linewidth=1,
        staircase=true,
      )
      .addTarget(
        prometheus.target(
          'sum by (resource) (screeps_room_assets{shard="$shard", room=~"$room"} > 0)',
          legendFormat='{{resource}}',
        )
      ) + {
        yaxes: [
          {
            format: 'none',
            label: 'Quantity',
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
          w: 16,
          h: panelHeight,
        },
      },
      
      // Resource distribution pie chart
      pieChartPanel.new(
        'Resource Distribution',
        datasource='VictoriaMetrics',
        description='Current distribution of all resources',
        pieType='pie',
        showLegend=true,
        showLegendPercentage=true,
        legendType='Right side',
      )
      .addTarget(
        prometheus.target(
          'sum by (resource) (screeps_room_assets{shard="$shard", room=~"$room"} > 0)',
          legendFormat='{{resource}}',
          instant=true,
        )
      ) + {
        gridPos: {
          x: 16,
          y: startY + panelHeight,
          w: 8,
          h: panelHeight,
        },
      },
    ],
    
    rowHeight: panelHeight * 2,  // Two rows of panels
  },
}