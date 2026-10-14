import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../main.dart';
import '../services/data_health_service.dart';

/// 数据体检 · 只读扫描
///
/// 只看不改：页面上没有任何写操作，扫出来的问题需要手动处理。
class DataHealthPage extends StatefulWidget {
  const DataHealthPage({Key? key}) : super(key: key);
  @override
  State<DataHealthPage> createState() => _DataHealthPageState();
}

class _DataHealthPageState extends State<DataHealthPage> {
  String _deviceStatusLabel(String status) {
    switch (status) {
      case 'in_stock':
        return '在库';
      case 'listed':
        return '已上架';
      case 'sold':
        return '已售';
      case 'returned':
        return '已退回';
      default:
        return status;
    }
  }

  Color _deviceStatusColor(String status) {
    switch (status) {
      case 'listed':
        return C.cyan;
      case 'sold':
        return C.green;
      case 'returned':
        return C.orange;
      default:
        return C.t3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = gStorage.getDevices();
    final repairOrders = gStorage.getRepairOrders();
    final report = scanDataHealth(
      devices: devices,
      repairOrders: repairOrders,
    );

    return appScaffold(
      context,
      '数据体检 · 只读扫描',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _summaryCard(report, devices.length, repairOrders.length),
          const SizedBox(height: 4),
          if (report.isClean)
            _cleanState()
          else
            ...report.repairCostLosses.map(_lossCard),
          const SizedBox(height: 6),
          _explainer(),
        ],
      ),
    );
  }

  Widget _summaryCard(DataHealthReport report, int deviceCount, int orderCount) {
    final clean = report.isClean;
    final tone = clean ? C.green : C.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(C.radiusLg),
        border: Border.all(color: tone.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                clean
                    ? Icons.verified_outlined
                    : Icons.report_problem_outlined,
                color: tone,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  clean
                      ? '未发现维修成本异常'
                      : '${report.repairCostLosses.length} 台机器的维修成本对不上',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          if (!clean) ...[
            const SizedBox(height: 10),
            Text(
              '合计少记 ${yuan(report.lostTotal)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: C.t1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '这部分成本没进毛利，历史利润相应偏高',
              style: TextStyle(fontSize: 11, color: C.t2),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '已扫描 ${deviceCount}台设备 · ${orderCount}条维修工单',
            style: TextStyle(fontSize: 11, color: C.t3),
          ),
        ],
      ),
    );
  }

  Widget _cleanState() => Padding(
    padding: const EdgeInsets.only(top: 30, bottom: 10),
    child: Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: C.bgCardMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border),
          ),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: C.green,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '每台机器的维修成本都记得上工单',
          style: TextStyle(color: C.t2, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _lossCard(RepairCostLoss loss) {
    final device = loss.device;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${device.model} ${device.capacity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.t1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                _deviceStatusLabel(device.status),
                _deviceStatusColor(device.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _moneyColumn(
                  '维修工单合计',
                  loss.repairOrdersTotal,
                  C.t2,
                ),
              ),
              Expanded(
                child: _moneyColumn('设备上记录的', loss.recorded, C.t3),
              ),
              Expanded(
                child: _moneyColumn('少记', loss.lost, C.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${device.color} · ${device.serial.isEmpty ? "序列号未填" : device.serial}'
            '${device.sellDate == null ? "" : " · 售出 ${device.sellDate}"}',
            style: TextStyle(fontSize: 10, color: C.t3),
          ),
        ],
      ),
    );
  }

  Widget _moneyColumn(String label, int fen, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: C.t3)),
      const SizedBox(height: 3),
      Text(
        yuan(fen),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );

  Widget _explainer() => Padding(
    padding: const EdgeInsets.all(14),
    child: Text(
      '体检项：维修工单合计 > 设备记录的维修成本。\n'
      '这是旧版售出页的一个缺陷 —— 表单里空白的「维修成本」会覆盖掉设备上'
      '已记录的值，让"修过又卖过"的机器丢掉成本。真实金额一直留在维修工单里，'
      '所以能对出来。\n'
      '反向的差异（设备记录 > 工单合计）不报：那通常是售出时手填的、没建工单的'
      '维修费，属于正常输入。\n'
      '本页只读，不会改动任何数据。',
      style: TextStyle(fontSize: 11, color: C.t3, height: 1.8),
    ),
  );
}
