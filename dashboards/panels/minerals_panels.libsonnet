local grafonnet = import '../grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafonnet.dashboard;
local row = grafonnet.row;
local graphPanel = grafonnet.graphPanel;
local pieChartPanel = grafonnet.pieChartPanel;
local template = grafonnet.template;
local prometheus = grafonnet.prometheus;

// Mineral boost type mapping - maps human-readable names to mineral variants
local mineralTypeMapping = {
  attack: {
    label: 'Attack',
    base: 'U',
    t1: 'UH',
    t2: 'UH2O',
    t3: 'XUH2O',
  },
  ranged_attack: {
    label: 'Ranged Attack',
    base: 'K',
    t1: 'KO',
    t2: 'KHO2',
    t3: 'XKHO2',
  },
  heal: {
    label: 'Heal',
    base: 'L',
    t1: 'LO',
    t2: 'LHO2',
    t3: 'XLHO2',
  },
  carry: {
    label: 'Carry',
    base: 'K',
    t1: 'KH',
    t2: 'KH2O',
    t3: 'XKH2O',
  },
  move: {
    label: 'Move',
    base: 'Z',
    t1: 'ZO',
    t2: 'ZHO2',
    t3: 'XZHO2',
  },
  tough: {
    label: 'Tough',
    base: 'G',
    t1: 'GO',
    t2: 'GHO2',
    t3: 'XGHO2',
  },
  work: {
    label: 'Work',
    base: 'U',
    t1: 'UO',
    t2: 'UHO2',
    t3: 'XUHO2',
  },
};

// Boost effects mapping - maps effect IDs to their properties across tiers
local boostEffectsMapping = {
  attack: { label: 'Attack', base: ['U', 'H'], t1: 'UH', t1_comp: ['U', 'H'], t2: 'UH2O', t2_comp: ['UH', 'OH'], t3: 'XUH2O', t3_comp: ['UH2O', 'X'] },
  harvest: { label: 'Harvest', base: ['U', 'O'], t1: 'UO', t1_comp: ['U', 'O'], t2: 'UH2O', t2_comp: ['UO', 'OH'], t3: 'XUH2O', t3_comp: ['UH2O', 'X'] },
  capacity: { label: 'Capacity', base: ['K', 'H'], t1: 'KH', t1_comp: ['K', 'H'], t2: 'KH2O', t2_comp: ['KH', 'OH'], t3: 'XKH2O', t3_comp: ['KH2O', 'X'] },
  ranged_attack: { label: 'Ranged Attack', base: ['K', 'O'], t1: 'KO', t1_comp: ['K', 'O'], t2: 'KH2O', t2_comp: ['KO', 'OH'], t3: 'XKH2O', t3_comp: ['KH2O', 'X'] },
  build_repair: { label: 'Build & Repair', base: ['L', 'H'], t1: 'LH', t1_comp: ['L', 'H'], t2: 'LH2O', t2_comp: ['LH', 'OH'], t3: 'XLH2O', t3_comp: ['LH2O', 'X'] },
  heal: { label: 'Heal', base: ['L', 'O'], t1: 'LO', t1_comp: ['L', 'O'], t2: 'LH2O', t2_comp: ['LO', 'OH'], t3: 'XLH2O', t3_comp: ['LH2O', 'X'] },
  dismantle: { label: 'Dismantle', base: ['Z', 'H'], t1: 'ZH', t1_comp: ['Z', 'H'], t2: 'ZH2O', t2_comp: ['ZH', 'OH'], t3: 'XZH2O', t3_comp: ['ZH2O', 'X'] },
  fatigue: { label: 'Fatigue', base: ['Z', 'O'], t1: 'ZO', t1_comp: ['Z', 'O'], t2: 'ZH2O', t2_comp: ['ZO', 'OH'], t3: 'XZH2O', t3_comp: ['ZH2O', 'X'] },
  upgrade_controller: { label: 'Upgrade Controller', base: ['G', 'H'], t1: 'GH', t1_comp: ['G', 'H'], t2: 'GH2O', t2_comp: ['GH', 'OH'], t3: 'XGH2O', t3_comp: ['GH2O', 'X'] },
  damage: { label: 'Tough', base: ['G', 'O'], t1: 'GO', t1_comp: ['G', 'O'], t2: 'GH2O', t2_comp: ['GO', 'OH'], t3: 'XGH2O', t3_comp: ['GH2O', 'X'] },
};

// Helper function to build regex pattern from mineral type
local buildMineralRegex(mineralType) =
  local m = mineralTypeMapping[mineralType];
  '%s|%s|%s|%s' % [m.base, m.t1, m.t2, m.t3];

// Generate template options from mapping
local templateOptions = [
  { text: mineralTypeMapping[key].label, value: key }
  for key in std.objectFields(mineralTypeMapping)
];

{

  // Create panels showing tier breakdown for boost effects
  // Helper function to create panels for a specific effect
  createEffectPanels(effectKey, effectData, rowY):: [
    // Row header
    row.new(
      title=effectData.label + ' Boost Resources',
      collapse=false,
    ) { gridPos: { x: 0, y: rowY, w: 24, h: 1 } },

    // Row 1: T1 Components (base minerals)
    graphPanel.new(
      'T1 - ' + effectData.label + ' - ' + effectData.t1_comp[0],
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
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="' + effectData.t1_comp[0] + '"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: rowY + 1, w: 12, h: 8 } },

    graphPanel.new(
      'T1 - ' + effectData.label + ' - ' + effectData.t1_comp[1],
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
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="' + effectData.t1_comp[1] + '"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: rowY + 1, w: 12, h: 8 } },

    // Row 2: T2 Components (T1 + mineral)
    graphPanel.new(
      'T2 - ' + effectData.label + ' - ' + effectData.t2_comp[0],
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
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="' + effectData.t2_comp[0] + '"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: rowY + 9, w: 12, h: 8 } },

    graphPanel.new(
      'T2 - ' + effectData.label + ' - ' + effectData.t2_comp[1],
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
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="' + effectData.t2_comp[1] + '"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: rowY + 9, w: 12, h: 8 } },

    // Row 3: T3 Components (T2 + X)
    graphPanel.new(
      'T3 - ' + effectData.label + ' - ' + effectData.t3_comp[0],
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
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="' + effectData.t3_comp[0] + '"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: rowY + 17, w: 12, h: 8 } },

    graphPanel.new(
      'T3 - ' + effectData.label + ' - ' + effectData.t3_comp[1],
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
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="' + effectData.t3_comp[1] + '"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 12, y: rowY + 17, w: 12, h: 8 } },

    // Row 4: Final T3 compound
    graphPanel.new(
      'Final T3 - ' + effectData.label + ' - ' + effectData.t3,
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
        'screeps_room_assets{shard=~"$shard",room=~"$room",resource="' + effectData.t3 + '"}',
        legendFormat='{{room}} - {{resource}}',
      )
    ) { gridPos: { x: 0, y: rowY + 25, w: 12, h: 8 } },
  ],

  newTierPanels(startY):: {
    // Define custom sort order
    local effectOrder = ['upgrade_controller', 'ranged_attack', 'heal', 'damage', 'attack', 'harvest', 'capacity', 'build_repair', 'dismantle', 'fatigue'],
    local rowHeight = 34,  // 1 (row header) + 8 + 8 (row 1) + 8 + 8 (row 2) + 8 + 8 (row 3) + 8 (row 4)
    
    panels: 
      std.flattenArrays([
        $.createEffectPanels(effectOrder[i], boostEffectsMapping[effectOrder[i]], startY + (i * rowHeight))
        for i in std.range(0, std.length(effectOrder) - 1)
      ]),
    rowHeight: std.length(effectOrder) * rowHeight,
  },

  // Export mapping and helper functions for use in dashboard
  mineralTypeMapping: mineralTypeMapping,
  boostEffectsMapping: boostEffectsMapping,
  buildMineralRegex: buildMineralRegex,
  templateOptions: templateOptions,
  boostEffectsList: [boostEffectsMapping[key].label for key in std.objectFields(boostEffectsMapping)],
}