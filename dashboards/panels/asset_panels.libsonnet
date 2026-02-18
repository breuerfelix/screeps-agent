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
      // All resources stacked time series (ALL resources)
      graphPanel.new(
        'All Room Resources Over Time',
        datasource='VictoriaMetrics',
        description='All resources in selected rooms over time (no limit)',
        format='short',
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
            format: 'short',
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
          y: startY,
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
          y: startY,
          w: 8,
          h: panelHeight,
        },
      },
    ],
    
    rowHeight: panelHeight,  // One row of panels
  },
}