import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../models.dart';
import '../main.dart';
import 'scan_page.dart';
import 'detail_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({Key? key}) : super(key: key);
  @override
  State<StockPage> createState() => StockPageState();
}

class StockPageState extends State<StockPage> {
  int chipIndex = 0;
  final chips = ['全部', 'iPad Pro', 'iPad Air', '数字系列', 'iPad mini'];
  String searchKw = '';

  void refresh() => setState(() {});

  List<Device> get filtered {
    var list = gStorage
        .getDevices()
        .where((d) => d.status == 'in_stock' || d.status == 'listed')
        .toList();
    if (chipIndex > 0) {
      final kw = chips[chipIndex];
      list = list.where((d) =>
          d.model.contains(kw.replaceAll('iPad ', '')) || d.model.contains(kw)
      ).toList();
    }
    if (searchKw.isNotEmpty) {
      list = list.where((d) =>
          d.model.toLowerCase().contains(searchKw.toLowerCase()) ||
          d.serial.toLowerCase().contains(searchKw.toLowerCase()) ||
          d.capacity.toLowerCase().contains(searchKw.toLowerCase())
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final devices = filtered;
    final allInStock = gStorage
        .getDevices()
        .where((d) => d.status == 'in_stock' || d.status == 'listed')
        .toList();
    final totalCost = allInStock.fold(0, (s, d) => s + d.purchaseCost);

    return PageScaffold(
      title: Text(
        '库存管理',
        style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900, color: C.t1, letterSpacing: 0.5,
        ),
      ),
      subtitle: Text(
        '在售${allInStock.length}台 · 成本占用${yuan(totalCost)}',
        style: TextStyle(fontSize: 12, color: C.t2, fontWeight: FontWeight.w500),
      ),
      action: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ScanPage()),
          ).then((_) => refresh()),
          borderRadius: BorderRadius.circular(C.radiusMd),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: C.cyanGradient,
              borderRadius: BorderRadius.circular(C.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: C.cyan.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black, size: 20),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 顶部指标 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
            child: Row(
              children: [
                Expanded(child: _metricCard(
                  '在售', '${allInStock.where((d) => d.status == 'listed').length}',
                  C.cyan, Icons.sell_outlined,
                )),
                const SizedBox(width: 8),
                Expanded(child: _metricCard(
                  '未定价', '${allInStock.where((d) => d.sellPrice <= 0).length}',
                  C.neonOrange, Icons.price_change_outlined,
                )),
                const SizedBox(width: 8),
                Expanded(child: _metricCard(
                  '滞销', '${allInStock.where((d) => d.isStagnant).length}',
                  C.neonRed, Icons.warning_amber_rounded,
                )),
              ],
            ),
          ),

          // ─── 搜索栏 ───
          Padding(
            padding: const EdgeInsets.fromLTRB(C.sp16, 0, C.sp16, C.sp12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: C.bgCard,
                borderRadius: BorderRadius.circular(C.radiusMd),
                border: Border.all(color: C.border, width: 0.8),
                boxShadow: C.elevationSm,
              ),
              child: TextField(
                onChanged: (v) => setState(() => searchKw = v),
                style: TextStyle(color: C.t1, fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: C.t3, size: 19),
                  prefixIconConstraints: const BoxConstraints(minWidth: 28),
                  suffixIcon: searchKw.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => searchKw = ''),
                          child: Icon(Icons.close_rounded, color: C.t3, size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  hintText: '搜索型号、序列号、容量',
                  hintStyle: TextStyle(color: C.t3, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // ─── 筛选标签 ───
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: C.sp16),
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final on = chipIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => chipIndex = i),
                  child: AnimatedContainer(
                    duration: C.fast,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? C.cyan.withOpacity(0.1) : C.bgCard,
                      borderRadius: BorderRadius.circular(C.radiusMd),
                      border: Border.all(
                        color: on ? C.cyan.withOpacity(0.3) : C.border,
                        width: on ? 1.2 : 0.8,
                      ),
                      boxShadow: on ? [
                        BoxShadow(
                          color: C.cyan.withOpacity(0.1),
                          blurRadius: 8, offset: const Offset(0, 2),
                        ),
                      ] : C.elevationSm,
                    ),
                    child: Text(
                      chips[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: on ? C.cyan : C.t2,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // ─── 设备列表 ───
          if (devices.isEmpty)
            _emptyStock()
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: C.sp16),
              child: Column(
                children: devices.map((d) => _deviceListItem(d)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: C.bgCard,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.border, width: 0.8),
      boxShadow: C.elevationSm,
    ),
    child: Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: C.t2, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _emptyStock() => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: C.cyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.cyan.withOpacity(0.15)),
            ),
            child: Icon(Icons.inventory_2_outlined, color: C.t3, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            '暂无库存',
            style: TextStyle(color: C.t1, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '扫码收货后会出现在这里',
            style: TextStyle(color: C.t2, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ScanPage()),
              ).then((_) => refresh()),
              borderRadius: BorderRadius.circular(C.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: C.cyanGradient,
                  borderRadius: BorderRadius.circular(C.radiusMd),
                  boxShadow: [
                    BoxShadow(color: C.cyan.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Text(
                  '立即扫码收货',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _deviceListItem(Device d) {
    final hasImg = d.imagePath != null && d.imagePath!.isNotEmpty;
    final firstImg = hasImg ? d.imagePath!.split(';').first : null;
    final goodCond = d.condition.contains('99') || d.condition.contains('95') || d.condition.contains('全新');
    final statusColor = d.isStagnant ? C.neonRed : C.cyan;
    return GestureDetector(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailPage(device: d)),
      ).then((_) => refresh()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.bgCard,
          borderRadius: BorderRadius.circular(C.radiusMd),
          border: Border.all(color: C.border, width: 0.8),
          boxShadow: C.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧图片
            ClipRRect(
              borderRadius: BorderRadius.circular(C.radiusSm),
              child: SizedBox(
                width: 120,
                height: 120,
                child: firstImg != null
                    ? Image.file(
                        File(firstImg), fit: BoxFit.cover,
                        width: 120, height: 120,
                      )
                    : Container(
                        color: C.bgCardMuted,
                        child: Center(
                          child: Icon(Icons.tablet_mac_rounded, color: C.t3, size: 40),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 右侧信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 型号
                  Text(
                    d.model,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.t1),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 配置信息
                  Text(
                    '${d.capacity} · ${d.color} · ${d.network}',
                    style: TextStyle(fontSize: 12, color: C.t2),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 电池健康度
                  Text(
                    '电池健康 ${d.batteryHealth}% · 库龄${d.stockDays}天',
                    style: TextStyle(fontSize: 11, color: C.t3),
                  ),
                  const Spacer(),
                  // 价格和标签行
                  Row(
                    children: [
                      Text(
                        d.sellPrice > 0 ? yuan(d.sellPrice) : '未定价',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: d.sellPrice > 0 ? C.cyan : C.neonOrange,
                        ),
                      ),
                      const Spacer(),
                      StatusChip(d.condition, goodCond ? C.neonGreen : C.neonOrange),
                      const SizedBox(width: 6),
                      StatusChip(
                        d.isStagnant ? '滞销' : '在售',
                        d.isStagnant ? C.neonRed : C.neonGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
