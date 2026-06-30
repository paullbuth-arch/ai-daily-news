import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../components/index.dart';
import '../utils/utils.dart';
import '../storage.dart';
import '../main.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({Key? key}) : super(key: key);
  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  @override
  Widget build(BuildContext context) {
    final customers = gStorage.getCustomers();
    return appScaffold(
      context,
      '客户管理 · 复购召回',
      ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (customers.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: C.cardMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.line),
                    ),
                    child: Icon(Icons.contacts_outlined, color: C.t3, size: 26),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '暂无客户，售出设备后自动生成',
                    style: TextStyle(color: C.t2, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...customers.map(
              (c) => CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.orange.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: C.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['name'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: C.t1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '购买${c["count"]}次 · 累计${yuan(c["totalAmount"] as int)}',
                            style: TextStyle(fontSize: 11, color: C.t2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '最后购买：${c["lastDate"]} · 渠道：${(c["channels"] as Set).join("/")}',
                            style: TextStyle(fontSize: 10, color: C.t3),
                          ),
                        ],
                      ),
                    ),
                    if ((c['count'] as int) >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: C.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '复购',
                          style: TextStyle(
                            fontSize: 9,
                            color: C.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '客户数据从订单自动聚合，售出设备越多客户库越完善。复购客户建议主动回访，推荐以旧换新。',
              style: TextStyle(fontSize: 11, color: C.t3, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}
