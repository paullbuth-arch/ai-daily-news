import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';

// ====== 售出页 ======
class _DeviceSeriesGroup {
  final String key;
  final String label;
  final List<Device> devices;

  const _DeviceSeriesGroup({
    required this.key,
    required this.label,
    required this.devices,
  });
}

class SellPage extends StatefulWidget {
  const SellPage({Key? key}) : super(key: key);
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  Device? selected;
  String? selectedSeriesKey;
  final _priceCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _repairCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _logisticsCtrl = TextEditingController(text: '15');
  String channel = '闲鱼';
  int? computedProfit;

  List<Device> get sellable =>
      gStorage
          .getDevices()
          .where((d) => d.status == 'in_stock' || d.status == 'listed')
          .toList();

  bool get _isXianyu => channel == '闲鱼';

  int _deviceSortPrice(Device device) =>
      device.sellPrice > 0 ? device.sellPrice : device.purchaseCost;

  List<_DeviceSeriesGroup> get _seriesGroups {
    final grouped = <String, List<Device>>{};
    final labels = <String, String>{};
    for (final device in sellable) {
      final label = _seriesLabel(device);
      grouped.putIfAbsent(label, () => <Device>[]).add(device);
      labels[label] = label;
    }

    final groups =
        grouped.entries.map((entry) {
          final devices =
              entry.value.toList()..sort((a, b) {
                final price = _deviceSortPrice(
                  a,
                ).compareTo(_deviceSortPrice(b));
                if (price != 0) return price;
                return a.stockDays.compareTo(b.stockDays);
              });
          return _DeviceSeriesGroup(
            key: entry.key,
            label: labels[entry.key] ?? entry.key,
            devices: devices,
          );
        }).toList();

    groups.sort((a, b) {
      final rank = _seriesRank(a.label).compareTo(_seriesRank(b.label));
      if (rank != 0) return rank;
      final price = _groupMinPrice(a).compareTo(_groupMinPrice(b));
      if (price != 0) return price;
      return a.label.compareTo(b.label);
    });
    return groups;
  }

  String _seriesLabel(Device device) {
    final raw = device.model.trim();
    if (raw.isEmpty || raw == '未知') return '其他型号';
    final normalized =
        raw
            .replaceAll('（', '(')
            .replaceAll('）', ')')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    final compact = normalized.toLowerCase().replaceAll(' ', '');
    final generation = RegExp(r'第\s*(\d+)\s*代').firstMatch(normalized);
    final generationNumber = generation?.group(1);

    if (compact.contains('mini')) {
      final match = RegExp(r'mini\s*(\d+)').firstMatch(normalized);
      final number = match?.group(1) ?? generationNumber;
      return number == null ? 'iPad mini' : 'iPad mini $number';
    }

    if (compact.contains('pro')) {
      final size =
          compact.contains('12.9') || compact.contains('129英寸')
              ? '12.9'
              : compact.contains('13') && compact.contains('2024')
              ? '13'
              : compact.contains('11') || compact.contains('11英寸')
              ? '11'
              : '';
      final year = RegExp(r'(20\d{2})').firstMatch(normalized)?.group(1);
      final suffix =
          year != null
              ? year
              : generationNumber != null
              ? '第$generationNumber代'
              : '';
      return ['iPad Pro', size, suffix].where((s) => s.isNotEmpty).join(' ');
    }

    if (compact.contains('air')) {
      final match = RegExp(
        r'Air\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(normalized);
      final number = match?.group(1) ?? generationNumber;
      if (number != null) return 'iPad Air $number';
      final year = RegExp(r'(20\d{2})').firstMatch(normalized)?.group(1);
      return year == null ? 'iPad Air' : 'iPad Air $year';
    }

    final base = RegExp(r'^iPad\s*(\d+)').firstMatch(normalized);
    if (base != null) return 'iPad ${base.group(1)}';
    return '其他型号';
  }

  int _seriesRank(String label) {
    if (label.startsWith('iPad mini')) return 10;
    if (label.startsWith('iPad Pro')) return 20;
    if (label.startsWith('iPad Air')) return 30;
    if (label.startsWith('iPad ')) return 40;
    return 90;
  }

  int _groupMinPrice(_DeviceSeriesGroup group) =>
      group.devices.map(_deviceSortPrice).reduce((a, b) => a < b ? a : b);

  String _seriesPriceRange(_DeviceSeriesGroup group) {
    final prices = group.devices.map(_deviceSortPrice).toList()..sort();
    if (prices.isEmpty) return '无价格';
    if (prices.first == prices.last) return yuan(prices.first);
    return '${yuan(prices.first)}-${yuan(prices.last)}';
  }

  _DeviceSeriesGroup? _activeSeriesGroup(List<_DeviceSeriesGroup> groups) {
    final key = selectedSeriesKey;
    if (key == null) return null;
    for (final group in groups) {
      if (group.key == key) return group;
    }
    return null;
  }

  String _serialText(Device device) {
    final serial = device.serial.trim();
    if (serial.isEmpty || serial == '未填写' || serial == '未知') {
      return '序列号未填';
    }
    return '序列号 $serial';
  }

  String _moneyInput(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  void _syncPlatformFee() {
    if (!_isXianyu) return;
    final priceValue = double.tryParse(_priceCtrl.text);
    final text =
        priceValue == null || priceValue <= 0
            ? ''
            : _moneyInput(priceValue * 0.016);
    if (_feeCtrl.text == text) return;
    _feeCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onPriceChanged(String _) {
    _syncPlatformFee();
    _computeProfit();
  }

  void _selectChannel(String value) {
    setState(() => channel = value);
    _syncPlatformFee();
    _computeProfit();
  }

  void _computeProfit() {
    final price = (double.tryParse(_priceCtrl.text) ?? 0) * 100;
    final repair = (double.tryParse(_repairCtrl.text) ?? 0) * 100;
    final fee = (double.tryParse(_feeCtrl.text) ?? 0) * 100;
    final logi = (double.tryParse(_logisticsCtrl.text) ?? 0) * 100;
    if (selected != null) {
      setState(() {
        computedProfit =
            price.toInt() -
            selected!.purchaseCost -
            repair.toInt() -
            fee.toInt() -
            logi.toInt();
      });
    }
  }

  Future<void> _confirm() async {
    if (selected == null) {
      toast(context, '请选择设备');
      return;
    }
    final priceValue = double.tryParse(_priceCtrl.text);
    if (priceValue == null || priceValue <= 0) {
      toast(context, '请输入售价');
      return;
    }
    final repairValue = double.tryParse(_repairCtrl.text) ?? 0;
    final feeValue = double.tryParse(_feeCtrl.text) ?? 0;
    final logisticsValue = double.tryParse(_logisticsCtrl.text) ?? 0;
    if (repairValue < 0 || feeValue < 0 || logisticsValue < 0) {
      toast(context, '成本费用不能为负数');
      return;
    }
    final now = DateTime.now();
    final price = (priceValue * 100).round();
    final repair = (repairValue * 100).round();
    final fee = (feeValue * 100).round();
    final logi = (logisticsValue * 100).round();
    final profit = price - selected!.purchaseCost - repair - fee - logi;
    if (profit < 0) {
      final ok = await confirmAction(
        context,
        title: '确认亏损出售',
        message: '这单预计亏损 ${yuan(profit.abs())}。确认继续记录出售吗？',
        confirmText: '继续出售',
        confirmColor: C.red,
      );
      if (!ok) return;
    }
    final d = selected!;
    d.status = 'sold';
    d.sellPrice = price;
    d.sellChannel = channel;
    d.sellDate = fmtDate(now);
    d.repairCost = repair;
    d.platformFee = fee;
    d.logisticsCost = logi;
    d.buyerContact = _buyerCtrl.text.trim();
    await gStorage.updateDevice(d);
    await gStorage.addOrder(
      Order(
        id: 'o${now.millisecondsSinceEpoch}',
        deviceId: d.id,
        deviceName: '${d.model} ${d.capacity}',
        buyer: _buyerCtrl.text.trim().isEmpty ? '未知' : _buyerCtrl.text.trim(),
        channel: channel,
        amount: price,
        profit: profit,
        status: 'shipped',
        createdAt:
            fmtDate(now) +
            ' ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
    );
    toast(context, '✅ 已售出，毛利${yuan(profit)}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => appScaffold(
    context,
    '售出设备',
    ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _deviceSelectorCard(),
        if (selected != null)
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: _onPriceChanged,
                  label: '售价(元)',
                  icon: Icons.sell_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppFormField(
                        controller: _repairCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        label: '维修成本',
                        icon: Icons.build_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppFormField(
                        controller: _feeCtrl,
                        keyboardType: TextInputType.number,
                        readOnly: _isXianyu,
                        onChanged: (_) => _computeProfit(),
                        label: '平台手续费',
                        hint: _isXianyu ? '闲鱼自动按售价 1.6%' : null,
                        icon: Icons.percent_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppFormField(
                        controller: _logisticsCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _computeProfit(),
                        label: '物流',
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppFormField(
                  controller: _buyerCtrl,
                  label: '买家',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('渠道', style: TextStyle(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 6),
                    AppDropdownField<String>(
                      value: channel,
                      hint: '选择销售渠道',
                      options: const ['闲鱼', '抖音', '转转', '私域', '同行'],
                      labelBuilder: (value) => value,
                      onChanged: (value) {
                        if (value != null) _selectChannel(value);
                      },
                    ),
                  ],
                ),
                if (computedProfit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (computedProfit! >= 0 ? C.green : C.red)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Text(
                            computedProfit! >= 0 ? '💰' : '📉',
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '预计毛利：${yuan(computedProfit!)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: computedProfit! >= 0 ? C.green : C.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                primaryBtn('✅ 确认售出', _confirm),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _deviceSelectorCard() {
    final groups = _seriesGroups;
    final activeGroup = _activeSeriesGroup(groups);
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeGroup == null)
            _seriesSelector(groups)
          else
            _deviceListForSeries(activeGroup),
        ],
      ),
    );
  }

  Widget _seriesSelector(List<_DeviceSeriesGroup> groups) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('选择型号系列', style: TextStyle(fontSize: 12, color: C.t2)),
          const Spacer(),
          Text(
            '${sellable.length}台',
            style: TextStyle(fontSize: 11, color: C.t3),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (groups.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: C.bgDeep,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.border),
          ),
          child: Text('暂无可售库存', style: TextStyle(color: C.t2, fontSize: 12)),
        )
      else
        ...groups.map(_seriesTile),
    ],
  );

  Widget _seriesTile(_DeviceSeriesGroup group) {
    final isSelected =
        selected != null && group.devices.any((d) => d.id == selected!.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => selectedSeriesKey = group.key),
          child: Ink(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isSelected ? C.cyan.withValues(alpha: 0.12) : C.bgDeep,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? C.cyan : C.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: C.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.border),
                  ),
                  child: Icon(Icons.folder_outlined, color: C.t2, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: C.t1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${group.devices.length}台 · ${_seriesPriceRange(group)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: C.t3),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: C.t3, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deviceListForSeries(_DeviceSeriesGroup group) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => selectedSeriesKey = null),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Icon(Icons.arrow_back_rounded, color: C.t2, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              group.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: C.t1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text('按价格低到高', style: TextStyle(fontSize: 10.5, color: C.t3)),
        ],
      ),
      const SizedBox(height: 8),
      ...group.devices.map(_deviceTile),
    ],
  );

  Widget _deviceTile(Device d) {
    final isSelected = selected?.id == d.id;
    final priceLabel =
        d.sellPrice > 0
            ? '标价${yuan(d.sellPrice)}'
            : '采购${yuan(d.purchaseCost)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap:
              () => setState(() {
                selected = d;
                _computeProfit();
              }),
          child: Ink(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isSelected ? C.cyan.withValues(alpha: 0.15) : C.bgDeep,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? C.cyan : C.border),
            ),
            child: Row(
              children: [
                Icon(Icons.tablet_mac_rounded, color: C.t2, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.model} ${d.capacity} ${d.color}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: C.t1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_serialText(d)} · 采购${yuan(d.purchaseCost)} · 库${d.stockDays}天',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: C.t2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? C.cyan : C.t2,
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: C.cyan, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
