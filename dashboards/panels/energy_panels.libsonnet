local grafana = import '../grafonnet-lib/grafonnet/grafana.libsonnet';
local graphPanel = grafana.graphPanel;
local pieChartPanel = grafana.pieChartPanel;
local prometheus = grafana.prometheus;

{
  // Create Energy and Battery resource panels (2 rows)
  new(startY):: {
    local panelHeight = 12,
    
    panels: [
      // ===== ROW 1: Energy Metrics =====
      
      // Energy per room - stacked time series
      graphPanel.new(
        'Energy per Room Over Time',
        datasource='VictoriaMetrics',
        description='Energy storage by room over time (stacked)',
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
          'sum by (room) (screeps_room_assets{shard="$shard", room=~"$room", resource="energy"})',
          legendFormat='{{room}}',
        )
      ) + {
        yaxes: [
          {
            format: 'short',
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
      
      // ===== ROW 2: Battery Metrics =====
      
      // Battery per room - stacked time series
      graphPanel.new(
        'Battery per Room Over Time',
        datasource='VictoriaMetrics',
        description='Battery storage by room over time (stacked)',
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
          'sum by (room) (screeps_room_assets{shard="$shard", room=~"$room", resource="battery"})',
          legendFormat='{{room}}',
        )
      ) + {
        yaxes: [
          {
            format: 'short',
            label: 'Battery',
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
      
      // Battery distribution pie chart
      pieChartPanel.new(
        'Battery Distribution by Room',
        datasource='VictoriaMetrics',
        description='Current battery distribution across rooms',
        pieType='pie',
        showLegend=true,
        showLegendPercentage=true,
        legendType='Right side',
      )
      .addTarget(
        prometheus.target(
          'sum by (room) (screeps_room_assets{shard="$shard", room=~"$room", resource="battery"} > 0)',
          legendFormat='{{room}}',
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
