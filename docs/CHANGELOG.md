# 机掌柜 版本更新记录

## v1.6.0 （2026-06-23）— WebDAV云同步 + 售后闭环 + 闲鱼效率 + 首页优化

### ✨ 新功能

- **WebDAV 云同步**（设置→WebDAV云同步）：
  - 支持坚果云等标准 WebDAV 服务，纯 Dart 实现零第三方依赖
  - 一键上传/下载，下载前自动备份本地数据
  - 测试连接验证配置
  - 多设备同步：换手机/平板数据无缝衔接
- **售后追踪闭环**：
  - 售后录入增加原因分类：质量问题/买家反悔/描述不符/物流损坏/其他
  - 订单详情页展示售后原因
  - 经营分析页供应商排行增加售后率统计，高售后率（≥20%）标红预警
- **闲鱼效率优化**：
  - 复用历史描述：同型号二次入库时弹窗选择"复用历史描述"或"重新AI生成"，省 token 省时间
  - 售价微调：设备详情页直接改售价（不用进滞销页），改后自动上架
- **首页信息密度优化**：
  - 今日GMV卡片增加环比昨日百分比（↑/↓ x.x%）
  - 快捷操作支持长按直达

### 🔧 技术改进

- `Order` 模型新增 `afterSaleReason` 字段
- `Storage.getSupplierStats()` 新增 `afterSaleRate` 售后率计算
- `Storage.getYesterdayGmv()` 新增昨日GMV方法
- 新建 `webdav_service.dart`（纯 Dart WebDAV 客户端）
- `_quick` 组件支持 `onLongPress` 长按回调
- 版本号 1.4.0+4 → 1.6.0+6

---

## v1.4.0 （2026-06-23）— 数据备份 + AI配置用户化 + 采购决策

### ✨ 新功能

- **数据导入/导出备份**（我的→备份与恢复）：
  - 一键导出：打包数据(JSON) + 图片(about/dev/cover)为 zip，通过系统分享发到微信/网盘/云端
  - 一键导入：从 zip 文件恢复全部数据，自动备份当前数据为 .bak（可一键回滚）
  - 导入后自动重写 imagePath（跨设备路径适配），图片正常显示
  - 7天未备份自动弹窗提醒
- **AI 配置用户化**（我的→AI配置 / 设置→配置AI引擎）：
  - 协议URL、API Token、模型名 三项可用户自定义，不再硬编码
  - 支持测试连接（发简单请求验证配置是否可用）
  - 空字段自动回退默认值（当前 DeepSeek 配置），向后兼容旧数据
  - 预留协议类型下拉（当前 Anthropic，OpenAI 格式后续支持）
  - 导入备份后自动同步 AI 配置
- **采购决策模块**（我的→采购决策·该不该收）：
  - 输入型号 + 采购成本 + 数量，一键分析
  - 历史指标：销量/平均利润/平均周转/压货率 + 在售/滞销/均价/均成本
  - 供应商表现：各渠道台数 + 均利润
  - AI 综合判断：建议收/谨慎收/不建议 + 理由 + 风险提示
  - 无历史数据时友好提示

### 🔧 技术改进

- `AiService` 从 `static const` 硬编码改为运行时配置注入（静态持有者模式，避免循环依赖）
- `Storage.getSettings()` 修复 JSON 解码类型转换问题（`Map<dynamic>` → `Map<String, dynamic>`）
- `pubspec.yaml` 版本号从 1.0.0+1 修正为 1.4.0+4（历史遗留 bug：APK versionName 一直显示 1.0.0）
- 修正代码内 "v3.1 增强版" → "v1.4.0"（3处版本显示错误）
- 新增依赖：archive 3.3.2（zip压缩）、file_picker 5.2.6（文件选择）、share_plus 4.5.3（系统分享）
- 新增 `backup_service.dart`（纯Dart，可单元测试）
- 新增 `Storage.getModelAnalysis()` 按型号综合分析方法
- 新增 `AiConfig` 类 + `AiService.testConnection()` + `AiService.purchaseDecision()`
- 测试从 35 项增至 52 项（+17：AiConfig 9项 / BackupService 6项 / getModelAnalysis 2项）

---

## v1.3.0 （2026-06-22）— 订单流转 + 自动定价 + 经营分析

### ✨ 新功能

- **订单详情页与流转**：订单卡片可点进详情，按状态操作：
  - 已发货 → 设为已完成
  - 已完成 → 重新上架（原订单作废，利润从历史统计自动扣除，设备回上架待售）
  - 售后 → 录入/修改售后费用（自动从月/年总利润扣除）
  - 售出设备直接生成"已发货"订单（跳过待发货环节）
- **自动定价**：入库填采购价后，按分档规则自动算售价并上架（listed）：
  <1000→+168 / 1000-2000→+238 / 2000-3000→+298 / 3000-4000→+398 / 4000-5000→+498 / 5000-7000→+598 / 7000-9000→+798 / >9000→+12%
- **经营分析页**（我的→经营分析·KPI看板）：
  - KPI：库存金额、平均单台利润(目标350+)、平均周转天数(目标≤15天)、资金周转率(目标>2)，达标自动标绿
  - 库存年龄分布（0-7/8-15/16-30/30+天）柱状图
  - 型号利润排行 Top8、型号周转分析（快→慢）、供应商利润排行 Top8

### 🎨 优化

- **滞销改15天**：isStagnant 阈值从30天改为15天；首页滞销预警卡片和列表可点进「滞销预警页」，对每台设备操作：售出/降价/上架
- **订单页**：删除刷新按钮，去掉"待发货"tab（全部/已发货/已完成/售后）
- **当月图表**：X轴标签每2天显示一个，不再密集
- **删除"设置售价并上架"**：自动定价取代手动设价

### 🔧 核心重构：利润一致性

所有利润统计统一基于 `Order.netProfit`（毛利-售后费用），过滤 `cancelled` 订单。涉及 computeStats/getDailyStats/getMonthlyStats/getYesterdayProfit/getChannelGmv 五处聚合。售后费用同时写入 Order 和 Device，作废订单自动从历史日/月利润剔除。三处趋势图与首页KPI自动一致。

- `Order` 新增 `afterSaleCost` 字段 + `netProfit` getter
- `Device.isStagnant` 改 15 天
- 新增顶层函数 `calcAutoPrice()`
- `Storage` 新增 6 个分析方法

### ✅ 测试

- `flutter analyze`：无 error
- `flutter test`：35 个单元测试全部通过（新增 calcAutoPrice 边界、15天滞销、Order.netProfit 售后扣除等测试）
- `flutter build apk --release`：构建成功，19.2MB

---

## v1.2.0 （2026-06-22）— 闲鱼跳转 + UI 优化

### ✨ 新功能

- **下载后跳转闲鱼**：设备详情页一键下载区改为双按钮——"仅下载"（不跳转）和"下载并去闲鱼"（下载成功后自动拉起闲鱼 app）。
  - 原生 MethodChannel 用包名 Intent（com.taobao.idlefish）拉起闲鱼，失败兜底尝试 fleamarket:// scheme，未安装则提示。
  - AndroidManifest 增加 `<queries>` 声明闲鱼包名（Android 11+ 包可见性要求）。
- **首页趋势箭头**：今日毛利、今日订单旁显示 ↑↓ 小箭头对比昨日数据，一眼看出涨跌。
- **图表周期切换**：近7天毛利趋势图增加"近7天 / 当月 / 近12月"三种周期切换，标题和累计值随之变化。
  - 新增 `Storage.getMonthlyStats()` 月度统计方法。

### 🎨 UI 优化

- **库存相册改网格视图**：从单列大卡片改为 2 列网格，缩略图占主体，型号/价格/成色/状态标签紧凑展示，一屏看更多台。
- **去掉刷新按钮**：删除首页、库存相册、订单页右上角的 🔄 刷新按钮（数据本就实时读取，按钮冗余且影响美观）。
- **趋势图 Y 轴去 k**：从 `¥1.5k` 改为 `¥1500` 元，更直观。

### ✅ 测试

- `flutter analyze`：无 error。
- `flutter test`：21 个单元测试全部通过。
- `flutter build apk --release`：构建成功，19.2MB，已签名。

---

## v1.1.0 （2026-06-22）— 首个正式发布版（功能修复 + 完善）

基于用户反馈修复四大问题并完善工程结构，已通过全量测试并构建 release APK。

### 🐛 问题修复

- **【问题三】AI 完全不可用（DNS 解析失败）**
  根因：`android/app/src/main/AndroidManifest.xml` 缺失，release 包无 INTERNET 权限。
  修复：重建完整 android 目录，main manifest 加 INTERNET / ACCESS_NETWORK_STATE / 相机 / 存储权限。DeepSeek AI（endpoint: api.deepseek.com/anthropic，model: deepseek-v4-flash）现已可正常调用，已实测商品描述生成、定价建议、日报均正常。

- **【问题二】点击功能时黑框提示完全看不见字**
  根因：toast 的 SnackBar 用 `Colors.black87` 背景，与应用深色背景（0xFF0B0F1A）几乎融合。
  修复：改为高对比度配色——卡片色背景 + 品牌色边框 + 信息图标 + 清晰文字，所有提示清晰可见。

### ✨ 新功能

- **【问题一.1】AI 商品描述自动入库**
  - `Device` 模型新增 `description` 字段（向后兼容，旧数据无此字段时为 null）。
  - 扫码收货页入库时调用 `AiService.generateDescription()`，根据型号/容量/颜色/成色/电池健康/循环次数/ID锁等准确信息自动生成 100-180 字商品描述，与设备一并入库。
  - 设备详情页商品描述区固定三行高度（66px），超出部分滑动查看，支持选中复制，不占篇幅。

- **【问题一.2】一键下载（上架闲鱼利器）**
  - 设备详情页新增绿色主按钮"一键下载"。
  - 商品描述自动复制到手机剪贴板。
  - 所有实拍图通过原生 MethodChannel 调用 MediaStore 保存到手机相册 `Pictures/机掌柜` 目录（兼容 Android 9 及以下）。
  - 最前面自动插入一张自制封面图（RepaintBoundary 截图，含型号/配置/成色/电池/售价等信息，360×480），防止闲鱼添加相册图片时顺序错乱。

### 📦 工程完善

- 重建缺失的 android 工程目录：settings.gradle、gradle.properties、gradle-wrapper（jar+properties, Gradle 7.4）、gradlew、MainActivity.kt、res 资源（styles/launch_background/ic_launcher）。
- 启动主题改为深色，与应用风格一致，避免启动闪白屏。
- 应用名设为"机掌柜"。

### ✅ 测试

- `flutter analyze`：无 error（仅原代码 8 个 info 级提示，不影响编译）。
- `flutter test`：21 个单元测试全部通过。
- AI 真实调用验证：商品描述生成、定价建议均正常返回。
- `flutter build apk --release`：构建成功，19.2MB，已签名。

### 🔧 技术栈

Flutter 3.0.0 / Dart 2.17.0 / JDK 17 / AGP 7.1.2 / Gradle 7.4 / Kotlin 1.7.10 / compileSdk 33

---

## v1.0.0 （初始版本）

用户提供的原始源代码，存在以下问题（已在 v1.1.0 修复）：
- android 目录不完整，无 AndroidManifest，AI 无法联网
- toast 黑框看不见字
- 无商品描述功能
- 无一键下载功能
