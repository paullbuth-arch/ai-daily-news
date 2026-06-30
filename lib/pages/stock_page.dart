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
              gradient: C.metricGradient,
              borderRadius: BorderRadius.circular(C.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: C.primary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
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
                  C.primary, Icons.sell_outlined,
                )),
                const SizedBox(width: 8),
                Expanded(child: _metricCard(
                  '未定价', '${allInStock.where((d) => d.sellPrice <= 0).length}',
                  C.orange, Icons.price_change_outlined,
                )),
                const SizedBox(width: 8),
                Expanded(child: _metricCard(
                  '滞销', '${allInStock.where((d) => d.isStagnant).length}',
                  C.red, Icons.warning_amber_rounded,
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
                color: C.card,
                borderRadius: BorderRadius.circular(C.radiusMd),
                border: Border.all(color: C.line, width: 0.8),
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
                      color: on ? C.selected : C.card,
                      borderRadius: BorderRadius.circular(C.radiusMd),
                      border: Border.all(
                        color: on ? C.primary.withOpacity(0.3) : C.line,
                        width: on ? 1.2 : 0.8,
                      ),
                      boxShadow: on ? null : C.elevationSm,
                    ),
                    child: Text(
                      chips[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: on ? C.selectedText : C.t2,
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
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 900 ? 4 : (box.maxWidth >= 620 ? 3 : 2);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: C.sp16),
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns >= 3 ? 0.84 : 0.78,
                  children: devices.map(_deviceCard).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(C.radiusMd),
      border: Border.all(color: C.line, width: 0.8),
      boxShadow: C.elevationSm,
    ),
    child: Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
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
              color: C.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.primary.withOpacity(0.15)),
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
                  gradient: C.metricGradient,
                  borderRadius: BorderRadius.circular(C.radiusMd),
                ),
                child: const Text(
                  '立即收货',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _deviceCard(Device d) {
    final hasImg = d.imagePath != null && d.imagePath!.isNotEmpty;
    final firstImg = hasImg ? d.imagePath!.split(';').first : null;
    final goodCond = d.condition.contains('99') || d.condition.contains('95') || d.condition.contains('全新');
    return GestureDetector(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => DetailPage(device: d)),
      ).then((_) => refresh()),
      child: Container(
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(C.radiusMd),
          border: Border.all(color: C.line, width: 0.8),
          boxShadow: C.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(C.radiusMd - 1),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: C.cardMuted,
                      child: firstImg != null
                          ? Image.file(
                              File(firstImg), fit: BoxFit.cover,
                              width: double.infinity, height: double.infinity,
                            )
                          : Center(
                              child: Icon(Icons.tablet_mac_rounded, color: C.t3, size: 36),
                            ),
                    ),
                  ),
                  // 状态标签
                  Positioned(
                    top: 8, left: 8,
                    child: StatusChip(
                      d.isStagnant ? '滞销' : '在售',
                      d.isStagnant ? C.red : C.green,
                    ),
                  ),
                  if (!d.idLockClean)
                    Positioned(
                      top: 8, right: 8,
                      child: StatusChip('ID锁', C.red),
                    ),
                  // 电池健康度
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${d.batteryHealth}%',
                        style: const TextStyle(
                          fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 信息区域
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.model,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: C.t1),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d.capacity} · ${d.color} · ${d.network}',
                    style: TextStyle(fontSize: 10.5, color: C.t2),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        d.sellPrice > 0 ? yuan(d.sellPrice) : '未定价',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900,
                          color: d.sellPrice > 0 ? C.primary : C.orange,
                        ),
                      ),
                      const Spacer(),
                      StatusChip(d.condition, goodCond ? C.green : C.orange),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '库龄${d.stockDays}天 · 成本${yuan(d.purchaseCost)}',
                    style: TextStyle(fontSize: 9.5, color: C.t3),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
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
