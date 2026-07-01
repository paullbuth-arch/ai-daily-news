import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../components/index.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import '../services/device_export_service.dart';
import 'detail_page.dart';
import 'scan_page.dart';

enum _StockSortKey {
  createdDesc,
  ageDesc,
  costDesc,
  priceDesc,
  profitDesc,
  modelAsc,
}

class StockPage extends StatefulWidget {
  const StockPage({Key? key}) : super(key: key);

  @override
  State<StockPage> createState() => StockPageState();
}

class StockPageState extends State<StockPage> {
  int chipIndex = 0;
  String searchKw = '';
  final searchCtrl = TextEditingController();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _minBatteryCtrl = TextEditingController();
  final chips = ['全部', 'iPad Pro', 'iPad Air', '数字系列', 'iPad mini'];
  String? downloadingDeviceId;
  String? _conditionFilter;
  String? _networkFilter;
  String? _capacityFilter;
  String? _statusFilter;
  _StockSortKey _sortKey = _StockSortKey.createdDesc;
  bool selectionMode = false;
  bool batchBusy = false;
  final selectedDeviceIds = <String>{};

  void refresh() => setState(() {});

  Future<void> _downloadDevice(
    Device device, {
    required bool openXianyu,
  }) async {
    if (downloadingDeviceId != null) return;
    setState(() => downloadingDeviceId = device.id);
    try {
      final result = await DeviceExportService.downloadListing(
        device: device,
        docDir: gDocDir,
        openXianyu: openXianyu,
      );
      if (!mounted) return;
      toast(context, result.message);
    } catch (e) {
      if (!mounted) return;
      toast(context, '下载失败：$e');
    } finally {
      if (mounted) setState(() => downloadingDeviceId = null);
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _minBatteryCtrl.dispose();
    super.dispose();
  }

  List<Device> get filtered {
    var list =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    if (chipIndex > 0) {
      final kw = chips[chipIndex];
      list =
          list
              .where(
                (d) =>
                    d.model.contains(kw.replaceAll('iPad ', '')) ||
                    d.model.contains(kw),
              )
              .toList();
    }
    if (searchKw.trim().isNotEmpty) {
      final kw = searchKw.toLowerCase();
      list =
          list.where((d) {
            return d.model.toLowerCase().contains(kw) ||
                d.serial.toLowerCase().contains(kw) ||
                d.capacity.toLowerCase().contains(kw) ||
                d.color.toLowerCase().contains(kw) ||
                d.network.toLowerCase().contains(kw) ||
                d.condition.toLowerCase().contains(kw);
          }).toList();
    }
    if (_conditionFilter != null) {
      list = list.where((d) => d.condition == _conditionFilter).toList();
    }
    if (_networkFilter != null) {
      list = list.where((d) => d.network == _networkFilter).toList();
    }
    if (_capacityFilter != null) {
      list = list.where((d) => d.capacity == _capacityFilter).toList();
    }
    if (_statusFilter != null) {
      list = list.where((d) => d.status == _statusFilter).toList();
    }

    final minPrice = _moneyFilter(_minPriceCtrl.text);
    final maxPrice = _moneyFilter(_maxPriceCtrl.text);
    if (minPrice != null) {
      list = list.where((d) => d.sellPrice >= minPrice).toList();
    }
    if (maxPrice != null) {
      list =
          list
              .where((d) => d.sellPrice > 0 && d.sellPrice <= maxPrice)
              .toList();
    }
    final minBattery = int.tryParse(_minBatteryCtrl.text.trim());
    if (minBattery != null) {
      list = list.where((d) => d.batteryHealth >= minBattery).toList();
    }

    list.sort(_sortDevices);
    return list;
  }

  int? _moneyFilter(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  int _sortDevices(Device a, Device b) {
    switch (_sortKey) {
      case _StockSortKey.createdDesc:
        return b.createdAt.compareTo(a.createdAt);
      case _StockSortKey.ageDesc:
        return b.stockDays.compareTo(a.stockDays);
      case _StockSortKey.costDesc:
        return b.purchaseCost.compareTo(a.purchaseCost);
      case _StockSortKey.priceDesc:
        return b.sellPrice.compareTo(a.sellPrice);
      case _StockSortKey.profitDesc:
        return _expectedProfit(b).compareTo(_expectedProfit(a));
      case _StockSortKey.modelAsc:
        return a.model.compareTo(b.model);
    }
  }

  int _expectedProfit(Device d) =>
      d.sellPrice > 0 ? d.sellPrice - d.purchaseCost : -d.purchaseCost;

  int get _activeFilterCount {
    var count = 0;
    if (_conditionFilter != null) count++;
    if (_networkFilter != null) count++;
    if (_capacityFilter != null) count++;
    if (_statusFilter != null) count++;
    if (_moneyFilter(_minPriceCtrl.text) != null) count++;
    if (_moneyFilter(_maxPriceCtrl.text) != null) count++;
    if (int.tryParse(_minBatteryCtrl.text.trim()) != null) count++;
    return count;
  }

  void _clearAdvancedFilters() {
    setState(() {
      _conditionFilter = null;
      _networkFilter = null;
      _capacityFilter = null;
      _statusFilter = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _minBatteryCtrl.clear();
    });
  }

  List<Device> get _selectedDevices {
    final selected = selectedDeviceIds;
    return gStorage.getDevices().where((d) => selected.contains(d.id)).toList();
  }

  void _enterSelection(Device device) {
    setState(() {
      selectionMode = true;
      selectedDeviceIds.add(device.id);
    });
  }

  void _toggleSelection(Device device) {
    if (!selectionMode) return;
    setState(() {
      if (selectedDeviceIds.contains(device.id)) {
        selectedDeviceIds.remove(device.id);
      } else {
        selectedDeviceIds.add(device.id);
      }
      if (selectedDeviceIds.isEmpty) selectionMode = false;
    });
  }

  void _clearSelection() {
    setState(() {
      selectionMode = false;
      selectedDeviceIds.clear();
    });
  }

  Future<void> _batchSetStatus(String status) async {
    final devices = _selectedDevices;
    if (devices.isEmpty || batchBusy) return;
    final label = status == 'listed' ? '上架' : '下架';
    final ok = await confirmAction(
      context,
      title: '确认批量$label',
      message: '将 ${devices.length} 台设备标记为${status == 'listed' ? '在售' : '库存'}。',
      confirmText: '批量$label',
      confirmColor: status == 'listed' ? C.cyan : C.orange,
    );
    if (!ok) return;
    setState(() => batchBusy = true);
    for (final d in devices) {
      d.status = status;
      await gStorage.updateDevice(d);
    }
    if (!mounted) return;
    setState(() => batchBusy = false);
    _clearSelection();
    toast(context, '已批量$label ${devices.length} 台');
  }

  Future<void> _batchDownloadSelected() async {
    final devices = _selectedDevices;
    if (devices.isEmpty || batchBusy) return;
    setState(() => batchBusy = true);
    var done = 0;
    try {
      for (final d in devices) {
        await DeviceExportService.downloadListing(
          device: d,
          docDir: gDocDir,
          openXianyu: false,
        );
        done++;
      }
      if (!mounted) return;
      toast(context, '已下载 $done 台素材');
    } catch (e) {
      if (mounted) toast(context, '批量下载失败：$e');
    } finally {
      if (mounted) setState(() => batchBusy = false);
    }
  }

  Future<void> _batchExportCsv() async {
    final devices = _selectedDevices;
    if (devices.isEmpty || batchBusy) return;
    setState(() => batchBusy = true);
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final path = '$gDocDir/stock_export_$stamp.csv';
      await File(path).writeAsString(_devicesToCsv(devices), encoding: utf8);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null
              ? const Rect.fromLTWH(0, 0, 1, 1)
              : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: '货脉库存导出',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) toast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => batchBusy = false);
    }
  }

  String _devicesToCsv(List<Device> devices) {
    final b = StringBuffer('\uFEFF型号,容量,颜色,网络,成色,序列号,状态,库龄,成本,售价,预估毛利\n');
    for (final d in devices) {
      final profit = d.sellPrice > 0 ? d.sellPrice - d.purchaseCost : 0;
      b.writeln(
        [
          d.model,
          d.capacity,
          d.color,
          d.network,
          d.condition,
          d.serial,
          _stockStatusLabel(d.status),
          '${d.stockDays}',
          '${(d.purchaseCost / 100).round()}',
          d.sellPrice > 0 ? '${(d.sellPrice / 100).round()}' : '',
          d.sellPrice > 0 ? '${(profit / 100).round()}' : '',
        ].map(_csvCell).join(','),
      );
    }
    return b.toString();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('，') ||
        escaped.contains('\n') ||
        escaped.contains('"')) {
      return '"$escaped"';
    }
    return escaped;
  }

  List<String> get _capacityOptions {
    final values =
        gStorage
            .getDevices()
            .map((d) => d.capacity.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values.isEmpty
        ? const ['64G', '128G', '256G', '512G', '1TB', '2TB']
        : values;
  }

  Future<void> _openFilters() async {
    await showAppFormSheet<void>(
      context: context,
      title: '库存筛选',
      subtitle: '按成色、容量、网络、状态和价格快速缩小范围',
      initialChildSize: 0.64,
      child: StatefulBuilder(
        builder:
            (context, setSheetState) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDropdownField<String>(
                  value: _conditionFilter,
                  hint: '全部成色',
                  options: iPadConditions,
                  labelBuilder: (value) => value,
                  onChanged: (value) {
                    setState(() => _conditionFilter = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 10),
                AppDropdownField<String>(
                  value: _networkFilter,
                  hint: '全部网络',
                  options: iPadNetworks,
                  labelBuilder: (value) => value,
                  onChanged: (value) {
                    setState(() => _networkFilter = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 10),
                AppDropdownField<String>(
                  value: _capacityFilter,
                  hint: '全部容量',
                  options: _capacityOptions,
                  labelBuilder: (value) => value,
                  onChanged: (value) {
                    setState(() => _capacityFilter = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 10),
                AppDropdownField<String>(
                  value: _statusFilter,
                  hint: '全部状态',
                  options: const ['in_stock', 'listed'],
                  labelBuilder: _stockStatusLabel,
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 12),
                _fieldRow(
                  AppFormField(
                    controller: _minPriceCtrl,
                    label: '最低售价(元)',
                    icon: Icons.price_change_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {});
                      setSheetState(() {});
                    },
                  ),
                  AppFormField(
                    controller: _maxPriceCtrl,
                    label: '最高售价(元)',
                    icon: Icons.sell_outlined,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() {});
                      setSheetState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 12),
                AppFormField(
                  controller: _minBatteryCtrl,
                  label: '最低电池健康(%)',
                  icon: Icons.battery_5_bar_rounded,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    setState(() {});
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 18),
                AppSheetActions(
                  primaryLabel: '完成',
                  onPrimary: () => Navigator.pop(context),
                  secondaryLabel: '重置筛选',
                  onSecondary: () {
                    _clearAdvancedFilters();
                    setSheetState(() {});
                  },
                ),
              ],
            ),
      ),
    );
  }

  Widget _fieldRow(Widget left, Widget right) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 320) {
        return Column(children: [left, const SizedBox(height: 12), right]);
      }
      return Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      );
    },
  );

  String _stockStatusLabel(String value) =>
      {'in_stock': '库存', 'listed': '在售'}[value] ?? value;

  String _sortLabel(_StockSortKey key) =>
      {
        _StockSortKey.createdDesc: '入库最新',
        _StockSortKey.ageDesc: '库龄最长',
        _StockSortKey.costDesc: '采购价高',
        _StockSortKey.priceDesc: '售价高',
        _StockSortKey.profitDesc: '毛利高',
        _StockSortKey.modelAsc: '型号排序',
      }[key]!;

  @override
  Widget build(BuildContext context) {
    final devices = filtered;
    final all =
        gStorage
            .getDevices()
            .where((d) => d.status == 'in_stock' || d.status == 'listed')
            .toList();
    final cost = all.fold<int>(0, (s, d) => s + d.purchaseCost);
    final stagnant = all.where((d) => d.isStagnant).length;
    final horizontal = AppLayout.pageHorizontal(context);
    final bottomPadding = AppLayout.scrollBottomPadding(context);

    return Stack(
      children: [
        const AppBackdrop(),
        SafeArea(
          child: CustomScrollView(
            cacheExtent: 600,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '库存项目',
                                  style: TextStyle(
                                    fontSize: AppLayout.titleSize(context),
                                    fontWeight: FontWeight.w900,
                                    color: C.t1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '在售 ${all.length} 台 · 成本占用 ${yuan(cost)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: C.t2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RoundIconButton(
                            icon: Icons.add_rounded,
                            color: Colors.black,
                            background: Colors.white,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ScanPage(),
                                  ),
                                ).then((_) => refresh()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StockStat(
                              label: '在售',
                              value:
                                  '${all.where((d) => d.status == 'listed').length}',
                              color: C.cyan,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StockStat(
                              label: '未定价',
                              value:
                                  '${all.where((d) => d.sellPrice <= 0).length}',
                              color: C.mint,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StockStat(
                              label: '滞销',
                              value: '$stagnant',
                              color: C.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SearchField(
                        controller: searchCtrl,
                        value: searchKw,
                        onChanged: (v) => setState(() => searchKw = v),
                        onClear:
                            () => setState(() {
                              searchCtrl.clear();
                              searchKw = '';
                            }),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: chips.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder:
                              (_, i) => _FilterPill(
                                label: chips[i],
                                selected: chipIndex == i,
                                onTap: () => setState(() => chipIndex = i),
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AppDropdownField<_StockSortKey>(
                              value: _sortKey,
                              hint: '排序',
                              options: _StockSortKey.values,
                              labelBuilder: _sortLabel,
                              fontSize: 13,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _sortKey = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StockToolButton(
                            icon: Icons.tune_rounded,
                            label:
                                _activeFilterCount == 0
                                    ? '筛选'
                                    : '筛选($_activeFilterCount)',
                            selected: _activeFilterCount > 0,
                            onTap: _openFilters,
                          ),
                          if (_activeFilterCount > 0) ...[
                            const SizedBox(width: 8),
                            RoundIconButton(
                              icon: Icons.close_rounded,
                              onTap: _clearAdvancedFilters,
                              size: 42,
                              color: C.t2,
                            ),
                          ],
                        ],
                      ),
                      if (selectionMode) ...[
                        const SizedBox(height: 10),
                        _BatchActionBar(
                          count: selectedDeviceIds.length,
                          busy: batchBusy,
                          onCancel: _clearSelection,
                          onList: () => _batchSetStatus('listed'),
                          onUnlist: () => _batchSetStatus('in_stock'),
                          onDownload: _batchDownloadSelected,
                          onExport: _batchExportCsv,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (devices.isEmpty) ...[
                        _EmptyStock(
                          onScan: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScanPage(),
                              ),
                            ).then((_) => refresh());
                          },
                        ),
                        SizedBox(height: bottomPadding),
                      ],
                    ],
                  ),
                ),
              ),
              if (devices.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    0,
                    horizontal,
                    bottomPadding,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.crossAxisExtent >= 720 ? 2 : 1;
                      final phoneTile =
                          columns == 1 && constraints.crossAxisExtent <= 430;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio:
                              columns == 1 ? (phoneTile ? 1.08 : 1.12) : 0.96,
                        ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final device = devices[i];
                          return RepaintBoundary(
                            child: _DeviceProjectCard(
                              device: device,
                              busy: downloadingDeviceId == device.id,
                              selected: selectedDeviceIds.contains(device.id),
                              selectionMode: selectionMode,
                              onDownload:
                                  () => _downloadDevice(
                                    device,
                                    openXianyu: false,
                                  ),
                              onDownloadAndOpen:
                                  () =>
                                      _downloadDevice(device, openXianyu: true),
                              onLongPress: () => _enterSelection(device),
                              onTap:
                                  selectionMode
                                      ? () => _toggleSelection(device)
                                      : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => DetailPage(device: device),
                                        ),
                                      ).then((_) => refresh()),
                            ),
                          );
                        }, childCount: devices.length),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StockStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(13),
    radius: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: C.t2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 23,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
    radius: 10,
    color: C.bgDeep,
    borderColor: C.border,
    child: Row(
      children: [
        const Icon(Icons.search_rounded, color: C.t2, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(
              color: C.t1,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
              hintText: '搜索型号、序列号、容量',
              hintStyle: TextStyle(color: C.t3, fontSize: 13),
            ),
          ),
        ),
        if (value.isNotEmpty)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: C.t3, size: 18),
          ),
      ],
    ),
  );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: C.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.cyan : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.black : C.t2,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _StockToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StockToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? C.cyan : C.t2,
        backgroundColor: selected ? C.cyan.withValues(alpha: 0.10) : C.bgDeep,
        side: BorderSide(color: selected ? C.cyan : C.border),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _BatchActionBar extends StatelessWidget {
  final int count;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onList;
  final VoidCallback onUnlist;
  final VoidCallback onDownload;
  final VoidCallback onExport;

  const _BatchActionBar({
    required this.count,
    required this.busy,
    required this.onCancel,
    required this.onList,
    required this.onUnlist,
    required this.onDownload,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(10),
    radius: 14,
    color: const Color(0xEA0B0F16),
    borderColor: C.cyan.withValues(alpha: 0.28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '已选 $count 台',
                style: const TextStyle(
                  color: C.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: C.cyan),
              )
            else
              GestureDetector(
                onTap: onCancel,
                child: const Icon(Icons.close_rounded, color: C.t3, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BatchActionButton(
              label: '上架',
              icon: Icons.storefront_outlined,
              onTap: busy ? null : onList,
            ),
            _BatchActionButton(
              label: '下架',
              icon: Icons.inventory_2_outlined,
              onTap: busy ? null : onUnlist,
            ),
            _BatchActionButton(
              label: '下载素材',
              icon: Icons.download_rounded,
              onTap: busy ? null : onDownload,
            ),
            _BatchActionButton(
              label: '导出CSV',
              icon: Icons.ios_share_rounded,
              onTap: busy ? null : onExport,
            ),
          ],
        ),
      ],
    ),
  );
}

class _BatchActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _BatchActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: C.t1,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _DeviceProjectCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDownload;
  final VoidCallback onDownloadAndOpen;
  final bool busy;
  final bool selected;
  final bool selectionMode;

  const _DeviceProjectCard({
    required this.device,
    required this.onTap,
    required this.onLongPress,
    required this.onDownload,
    required this.onDownloadAndOpen,
    required this.busy,
    required this.selected,
    required this.selectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final image = _firstImage(device);
    final expectedProfit =
        device.sellPrice > 0 ? device.sellPrice - device.purchaseCost : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xF00D1017),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: C.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LayoutBuilder(
              builder: (context, box) {
                final dpr = MediaQuery.of(context).devicePixelRatio;
                final cacheWidth =
                    (box.maxWidth * dpr).round().clamp(480, 1400).toInt();
                final cacheHeight =
                    (box.maxHeight * dpr).round().clamp(360, 1200).toInt();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      Image.file(
                        image,
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        cacheHeight: cacheHeight,
                        filterQuality: FilterQuality.low,
                        errorBuilder:
                            (_, __, ___) => CustomPaint(
                              painter: _DeviceBackdropPainter(device.model),
                            ),
                      )
                    else
                      CustomPaint(
                        painter: _DeviceBackdropPainter(device.model),
                      ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.18),
                              Colors.black.withOpacity(0.78),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 13,
                      right: 13,
                      child:
                          selectionMode
                              ? Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? C.cyan
                                          : Colors.black.withValues(
                                            alpha: 0.42,
                                          ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        selected
                                            ? C.cyan
                                            : Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                  ),
                                ),
                                child: Icon(
                                  selected
                                      ? Icons.check_rounded
                                      : Icons.circle_outlined,
                                  color: selected ? Colors.black : Colors.white,
                                  size: 20,
                                ),
                              )
                              : Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.42),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.36),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${device.model} ${device.capacity}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: C.t1,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                StatusChip(
                                  _statusText(device),
                                  _statusColor(device),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${device.condition} · ${device.color} · ${device.stockDays}天',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: C.t2,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  device.sellPrice > 0
                                      ? yuan(device.sellPrice)
                                      : '待定价',
                                  style: const TextStyle(
                                    color: C.cyan,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniMetric(
                                    label: '成本',
                                    value: yuan(device.purchaseCost),
                                    color: C.t2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MiniMetric(
                                    label: '毛利',
                                    value:
                                        expectedProfit == null
                                            ? '待定'
                                            : yuan(expectedProfit),
                                    color:
                                        expectedProfit == null
                                            ? C.orange
                                            : expectedProfit >= 0
                                            ? C.mint
                                            : C.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            if (selectionMode)
                              _SelectionHint(selected: selected)
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: _CardActionButton(
                                      label: '仅下载',
                                      icon: Icons.download_rounded,
                                      onTap: onDownload,
                                      busy: busy,
                                      filled: false,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _CardActionButton(
                                      label: '下载并去闲鱼',
                                      icon: Icons.open_in_new_rounded,
                                      onTap: onDownloadAndOpen,
                                      busy: busy,
                                      filled: true,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  File? _firstImage(Device d) {
    final raw = d.imagePath;
    if (raw == null || raw.isEmpty) return null;
    final paths = raw.split(';').where((p) => p.trim().isNotEmpty).toList();
    if (paths.isEmpty) return null;
    final path = paths.first;
    return File(path);
  }

  String _statusText(Device d) {
    if (d.isStagnant) return '滞销';
    if (d.sellPrice <= 0) return '未定价';
    return d.status == 'listed' ? '在售' : '库存';
  }

  Color _statusColor(Device d) {
    if (d.isStagnant) return C.red;
    if (d.sellPrice <= 0) return C.orange;
    return d.status == 'listed' ? C.cyan : C.mint;
  }
}

class _SelectionHint extends StatelessWidget {
  final bool selected;

  const _SelectionHint({required this.selected});

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color:
          selected
              ? C.cyan.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: selected ? C.cyan : Colors.white.withValues(alpha: 0.12),
      ),
    ),
    child: Text(
      selected ? '已选择' : '点按选择',
      style: TextStyle(
        color: selected ? C.cyan : C.t2,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: C.t3,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;
  final bool filled;

  const _CardActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.busy,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? C.cyan : Colors.white.withOpacity(0.09);
    final fg = filled ? Colors.black : C.t1;
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: busy ? null : onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withOpacity(0.55),
          foregroundColor: fg,
          disabledForegroundColor: fg.withOpacity(0.55),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: const StadiumBorder(),
          side:
              filled
                  ? BorderSide.none
                  : BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        child:
            busy
                ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
                : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _DeviceBackdropPainter extends CustomPainter {
  final String seed;
  const _DeviceBackdropPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final hue = seed.hashCode.isEven ? C.cyan : C.purple;
    final bg =
        Paint()
          ..shader = LinearGradient(
            colors: [hue.withOpacity(0.36), C.bgCard, C.bgDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final tabletPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8;
    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.52, size.height * 0.38),
      width: size.width * 0.52,
      height: size.height * 0.46,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      tabletPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DeviceBackdropPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

class _EmptyStock extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyStock({required this.onScan});

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(22),
    radius: 24,
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: C.cyan,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.black,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '暂无库存设备',
          style: TextStyle(
            color: C.t1,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '先收一台设备，库存卡片会出现在这里',
          style: TextStyle(color: C.t2, fontSize: 12),
        ),
        const SizedBox(height: 16),
        primaryBtn('扫码收货', onScan, icon: Icons.add_rounded),
      ],
    ),
  );
}
