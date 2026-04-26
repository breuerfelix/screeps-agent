local grafana = import '../grafonnet-lib/grafonnet/grafana.libsonnet';
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;

{
  // Create Subsystem Health panels (transport network downtime, hatchery uptime/overload)
  new(startY):: {
    local panelHeight = 12,

    panels: [
      // Transport Network Downtime
      graphPanel.new(
        'Transport Network Downtime',
        datasource='VictoriaMetrics',
        description='Transport network downtime by room (fraction of time network is down)',
        format='percentunit',
        legend_show=true,
        legend_values=true,
        legend_min=false,
        legend_max=true,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
        legend_rightSide=false,
        stack=false,
        fill=2,
        linewidth=1,
        staircase=true,
      )
      .addTarget(
        prometheus.target(
          'screeps_room_transportNetwork_downtime{shard="$shard", room=~"$room"}',
          legendFormat='{{room}}',
        )
      ) + {
        yaxes: [
          {
            format: 'percentunit',
            label: 'Downtime',
            show: true,
            decimals: 1,
            min: 0,
            max: 1,
          },
          {
            show: false,
          },
        ],
        gridPos: {
          x: 0,
          y: startY,
          w: 12,
          h: panelHeight,
        },
        nullPointMode: 'connected',
      },

      // Hatchery Uptime & Overload
      graphPanel.new(
        'Hatchery Uptime & Overload',
        datasource='VictoriaMetrics',
        description='Hatchery uptime and overload by room (fractions)',
        format='percentunit',
        legend_show=true,
        legend_values=true,
        legend_min=false,
        legend_max=true,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
        legend_rightSide=false,
        stack=false,
        fill=2,
        linewidth=1,
        staircase=true,
      )
      .addTarget(
        prometheus.target(
          'screeps_room_hatchery_uptime{shard="$shard", room=~"$room"}',
          legendFormat='{{room}} uptime',
        )
      )
      .addTarget(
        prometheus.target(
          'screeps_room_hatchery_overload{shard="$shard", room=~"$room"}',
          legendFormat='{{room}} overload',
        )
      )
      .addSeriesOverride({
        alias: '/.* uptime/',
        color: 'green',
      })
      .addSeriesOverride({
        alias: '/.* overload/',
        color: 'orange',
      }) + {
        yaxes: [
          {
            format: 'percentunit',
            label: 'Fraction',
            show: true,
            decimals: 1,
            min: 0,
            max: 1,
          },
          {
            show: false,
          },
        ],
        gridPos: {
          x: 12,
          y: startY,
          w: 12,
          h: panelHeight,
        },
      },
    ],

    rowHeight: panelHeight,  // Single row of panels
  },
}
