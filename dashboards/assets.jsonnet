local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local template = grafana.template;
local row = grafana.row;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;

// Import panel modules
local assetPanels = import 'panels/asset_panels.libsonnet';
local mineralPanels = import 'panels/minerals_panels.libsonnet';

// Calculate Y positions
local assetsRowY = 0;
local assetsY = assetsRowY + 1;
local assetsObj = assetPanels.new(assetsY);
local baseResourcesRowY = assetsY + assetsObj.rowHeight;
local baseResourcesObj = {
  local panelHeight = 8,
  local rowHeight = 1 + (6 * panelHeight),

  panels: [
    row.new(
      title='Base Resources',
    ) { gridPos: { x: 0, y: baseResourcesRowY, w: 24, h: 1 } },

    graphPanel.new(
      'Base - O',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="O"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: baseResourcesRowY + 1, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - H',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="H"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: baseResourcesRowY + 1, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - OH',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="OH"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: baseResourcesRowY + 9, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - X',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="X"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: baseResourcesRowY + 9, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - Z',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="Z"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: baseResourcesRowY + 17, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - K',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="K"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: baseResourcesRowY + 17, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - U',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="U"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: baseResourcesRowY + 25, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - L',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="L"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: baseResourcesRowY + 25, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - ZK',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="ZK"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: baseResourcesRowY + 33, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - UL',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="UL"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: baseResourcesRowY + 33, w: 12, h: panelHeight } },

    graphPanel.new(
      'Base - G',
      datasource='VictoriaMetrics',
      legend_show=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_values=true,
      legend_current=true,
      legend_sort='current',
      legend_sortDesc=true,
      stack=true,
      fill=1,
    ).addTarget(
      prometheus.target(
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="G"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: baseResourcesRowY + 41, w: 24, h: panelHeight } },
  ],

  rowHeight: rowHeight,
};
local tierPanelsY = baseResourcesRowY + baseResourcesObj.rowHeight;
local tierPanelsObj = mineralPanels.newTierPanels(tierPanelsY);

dashboard.new(
  'Assets',
  description='Room assets and resources monitoring',
  time_from='now-2d',
  refresh='30s',
  tags=['screeps', 'assets'],
  editable=true,
  uid='assets',
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
.addPanels(baseResourcesObj.panels)
.addPanels(tierPanelsObj.panels)
