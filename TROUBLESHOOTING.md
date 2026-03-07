# 🔧 故障排查指南

## 📋 目录

1. [依赖库问题](#依赖库问题)
2. [推送失败问题](#推送失败问题)
3. [阿里云函数问题](#阿里云函数问题)
4. [GitHub Actions问题](#github-actions问题)
5. [企业微信推送问题](#企业微信推送问题)

---

## 1. 依赖库问题

### ❌ 错误：`No module named 'bs4'`

**原因**：缺少 `beautifulsoup4` 库

**解决方案**：

#### 方法一：重新部署（自动）

```bash
python3 update_function.py
```

#### 方法二：手动更新（控制台）

1. 访问 https://fc.console.aliyun.com/
2. 找到函数 `daily-news-push`
3. 点击"配置" → "环境变量"
4. 查看是否正确配置

#### 方法三：使用层（Layers）

1. 函数详情 → 配置 → 层 → "添加层"
2. 选择公共层或创建自定义层
3. 添加依赖：`beautifulsoup4`, `lxml`, `feedparser`

---

### ❌ 错误：`No module named 'googletrans'`

**解决方案**：

googletrans 库可能不稳定，可以修改代码禁用翻译：

```python
# 在 get_ai_news.py 中
TRANSLATION_AVAILABLE = False  # 禁用翻译
```

或安装其他翻译库。

---

## 2. 推送失败问题

### ❌ 错误：企业微信群收不到消息

**检查清单**：

1. **检查 Webhook 是否有效**
   - 在企业微信群发送测试消息
   - 查看是否收到

2. **检查阿里云日志**
   - 函数详情 → 日志查询
   - 查看具体错误信息

3. **检查函数配置**
   - 环境变量是否正确配置
   - Webhook 地址是否完整

4. **检查触发器**
   - 触发器是否启用
   - Cron 表达式是否正确

---

### ❌ 错误：推送延迟或未推送

**可能原因**：

1. **阿里云**：函数执行超时
   - 解决：增加超时时间（当前300秒）

2. **GitHub Actions**：队列延迟
   - 解决：无法避免，这是GitHub的限制

3. **网络问题**：新闻源无法访问
   - 解决：等待下次运行，会自动重试

---

## 3. 阿里云函数问题

### ❌ 错误：函数执行失败

**查看日志**：

1. 访问 https://fc.console.aliyun.com/
2. 找到服务 `ai-daily-news`
3. 点击函数 `daily-news-push`
4. 点击"日志查询"
5. 选择时间范围
6. 查看错误详情

**常见错误**：

| 错误 | 解决方案 |
|------|---------|
| `No module named` | 缺少依赖，运行 `update_function.py` |
| `Timeout` | 增加函数超时时间 |
| `KeyError` | 环境变量未配置 |
| `Connection error` | 网络问题，等待下次运行 |

---

## 4. GitHub Actions 问题

### ❌ 错误：Workflow 运行失败

**查看日志**：

1. 访问 https://github.com/paullbuth-arch/ai-daily-news/actions
2. 点击失败的运行记录
3. 展开失败的步骤
4. 查看错误信息

---

## 5. 企业微信推送问题

### ❌ 错误：发送失败

**可能原因**：

1. **机器人被删除**
   - 解决：重新创建机器人，更新 Webhook

2. **发送频率过高**
   - 解决：阿里云限制为每分钟20条
   - 当前配置：每天3次，不会超限

3. **Webhook 地址错误**
   - 解决：检查地址格式是否正确

---

## 🔧 快速修复命令

### 更新函数代码

```bash
python3 update_function.py
```

### 测试函数

1. 访问：https://fc.console.aliyun.com/
2. 找到函数
3. 点击"测试函数"

### 查看日志

函数详情 → 日志查询 → 选择时间

---

## 📞 获取帮助

### 文档

- **完整使用指南**：[USAGE_GUIDE.md](https://github.com/paullbuth-arch/ai-daily-news/blob/main/USAGE_GUIDE.md)
- **部署教程**：[README_ALIYUN.md](https://github.com/paullbuth-arch/ai-daily-news/blob/main/README_ALIYUN.md)

### 在线资源

- 阿里云控制台：https://fc.console.aliyun.com/
- GitHub 仓库：https://github.com/paullbuth-arch/ai-daily-news
- GitHub Issues：https://github.com/paullbuth-arch/ai-daily-news/issues

---

## 💡 预防措施

1. **定期检查日志**：每周查看一次
2. **测试功能**：重大修改后手动测试
3. **备份配置**：保存 Webhook 和授权码
4. **关注费用**：确保在免费额度内

---

**更新时间**：2025年3月8日
