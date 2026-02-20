local grafana = import 'grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local template = grafana.template;
local row = grafana.row;

// Import panel modules
local assetPanels = import 'panels/asset_panels.libsonnet';

// Calculate Y positions
local assetsRowY = 0;
local assetsY = assetsRowY + 1;
local assetsObj = assetPanels.new(assetsY);

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
