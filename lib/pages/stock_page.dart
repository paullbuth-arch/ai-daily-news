import 'dart:io';
import 'package:flutter/material.dart';
import '../components/index.dart';
import '../theme/colors.dart';
import '../utils/utils.dart';
import '../models.dart';
import '../main.dart';
import 'detail_page.dart';
import 'scan_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({Key? key}) : super(key: key);

  @override
  State<StockPage> createState() => StockPageState();
}

class StockPageState extends State<StockPage> {
  int chipIndex = 0;
  String searchKw = '';
  final chips = ['全部', 'iPad Pro', 'iPad Air', '数字系列', 'iPad mini'];

  void refresh() => setState(() {});

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
                d.capacity.toLowerCase().contains(kw);
          }).toList();
    }
    return list;
  }

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

    return PageScaffold(
      title: const Text(
        'My stock',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          color: C.t1,
        ),
      ),
      subtitle: Text(
        '在售 ${all.length} 台 · 成本占用 ${yuan(cost)}',
        style: const TextStyle(
          fontSize: 12,
          color: C.t2,
          fontWeight: FontWeight.w700,
        ),
      ),
      action: RoundIconButton(
        icon: Icons.add_rounded,
        color: Colors.black,
        background: Colors.white,
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanPage()),
            ).then((_) => refresh()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StockStat(
                  label: '在售',
                  value: '${all.where((d) => d.status == 'listed').length}',
                  color: C.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StockStat(
                  label: '未定价',
                  value: '${all.where((d) => d.sellPrice <= 0).length}',
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
            value: searchKw,
            onChanged: (v) => setState(() => searchKw = v),
            onClear: () => setState(() => searchKw = ''),
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
          const SizedBox(height: 16),
          if (devices.isEmpty)
            _EmptyStock(
              onScan: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanPage()),
                ).then((_) => refresh());
              },
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 720 ? 2 : 1;
                return GridView.builder(
                  itemCount: devices.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 1.55 : 1.35,
                  ),
                  itemBuilder:
                      (_, i) => _DeviceProjectCard(
                        device: devices[i],
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailPage(device: devices[i]),
                              ),
                            ).then((_) => refresh()),
                      ),
                );
              },
            ),
        ],
      ),
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
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: 13),
    radius: 22,
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(
        color: C.t1,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        icon: const Icon(Icons.search_rounded, color: C.t2),
        hintText: '搜索型号、序列号、容量',
        suffixIcon:
            value.isEmpty
                ? null
                : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, color: C.t3, size: 18),
                ),
      ),
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

class _DeviceProjectCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;

  const _DeviceProjectCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = _firstImage(device);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  Image.file(image, fit: BoxFit.cover)
                else
                  CustomPaint(painter: _DeviceBackdropPainter(device.model)),
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
                  child: Container(
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
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                      ],
                    ),
                  ),
                ),
              ],
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
    final file = File(path);
    return file.existsSync() ? file : null;
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
