# 🎯 AI每日新闻推送 - 完整使用指南

> **项目地址**：https://github.com/paullbuth-arch/ai-daily-news
> **最后更新**：2025年3月8日

---

## 📋 目录

1. [快速开始](#快速开始)
2. [当前部署状态](#当前部署状态)
3. [GitHub Actions配置](#github-actions配置)
4. [阿里云函数计算配置](#阿里云函数计算配置)
5. [企业微信配置](#企业微信配置)
6. [邮箱配置](#邮箱配置)
7. [常见问题](#常见问题)
8. [换电脑/重新部署指南](#换电脑重新部署指南)

---

## 🚀 快速开始

### ✅ 已部署完成的功能

你目前拥有**双重推送保障**：

| 推送方式 | 状态 | 准确度 | 推送时间 |
|---------|------|--------|---------|
| **阿里云FC** | ✅ 已部署 | ±几秒 | 09:20, 12:20, 15:50 |
| **GitHub Actions** | ✅ 已配置 | ±5-30分钟 | 相同时间 |

**功能特性**：
- ✅ AI新闻自动翻译（英文→中文）
- ✅ GitHub热门AI项目推荐（含用途说明）
- ✅ 节日提醒（传统节日+特殊日期）
- ✅ 可点击的新闻链接
- ✅ 邮件+企业微信双推送

---

## 📊 当前部署状态

### 阿里云函数计算（主推送）

- **服务名称**：`ai-daily-news`
- **函数名称**：`daily-news-push`
- **地域**：华东1（杭州）
- **状态**：✅ 已自动部署完成

**访问地址**：
- 控制台：https://fc.console.aliyun.com/
- 直接访问函数：[登录后在服务列表查找](https://fc.console.aliyun.com/)

### GitHub Actions（备用推送）

- **仓库**：https://github.com/paullbuth-arch/ai-daily-news
- **Workflow**：`.github/workflows/daily-ai-news.yml`
- **状态**：✅ 已配置完成

---

## 🔧 GitHub Actions配置

### Secrets 配置

在GitHub仓库中已配置的Secrets：

1. 访问：https://github.com/paullbuth-arch/ai-daily-news/settings/secrets/actions

2. 已配置的Secret：
   ```
   WECOM_WEBHOOK = https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxxx
   ```

### 修改 Secrets

如需修改，点击 "New repository secret" 添加新的Secret。

---

## ☁️ 阿里云函数计算配置

### 已配置的环境变量

在阿里云函数 `daily-news-push` 中已配置：

```bash
WECOM_WEBHOOK = https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_WEBHOOK_KEY_HERE
ENABLE_TRANSLATION = true
```

### 定时触发器

已创建3个定时触发器：

| 触发器名称 | Cron表达式 | 北京时间 | 说明 |
|-----------|-----------|---------|------|
| morning-push | `0 20 1 * * *` | 09:20 | 早上推送 |
| noon-push | `0 20 4 * * *` | 12:20 | 中午推送 |
| afternoon-push | `0 50 7 * * *` | 15:50 | 下午推送 |

---

## 💬 企业微信配置

### 当前配置

**Webhook地址**：
```
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_WEBHOOK_KEY_HERE
```

### 修改企业微信

1. 在企业微信群中添加新的机器人
2. 复制新的 Webhook 地址
3. 更新配置：
   - **GitHub**：Settings → Secrets → Actions → 修改 `WECOM_WEBHOOK`
   - **阿里云**：函数详情页 → 配置 → 环境变量 → 修改 `WECOM_WEBHOOK`

---

## 📧 邮箱配置（可选）

当前未配置，如需启用：

### QQ邮箱配置示例

1. **获取授权码**：
   - 登录 https://mail.qq.com
   - 设置 → 账户 → 开启SMTP服务
   - 生成16位授权码

2. **添加 GitHub Secrets**：
   ```
   EMAIL_TO = your@qq.com          # 接收邮箱
   EMAIL_FROM = your@qq.com       # 发送邮箱
   SMTP_HOST = smtp.qq.com         # SMTP服务器
   SMTP_PORT = 587                 # SMTP端口
   SMTP_USER = your@qq.com        # SMTP用户名
   SMTP_PASSWORD = 授权码           # SMTP密码（授权码）
   ```

---

## ❓ 常见问题

### Q1: 没有收到推送怎么办？

**检查清单**：
1. 查看阿里云函数日志：控制台 → 函数详情 → 日志查询
2. 查看GitHub Actions：仓库 → Actions → 查看运行记录
3. 检查企业微信群机器人是否被删除
4. 查看垃圾邮件文件夹

### Q2: 如何修改推送时间？

**阿里云**：
- 控制台 → 函数详情 → 触发器管理 → 编辑触发器 → 修改Cron表达式

**GitHub**：
- 编辑 `.github/workflows/daily-ai-news.yml`
- 修改 `schedule.cron` 的值
- 提交到GitHub

### Q3: 如何查看日志？

**阿里云**：
1. 访问 https://fc.console.aliyun.com/
2. 找到服务 `ai-daily-news`
3. 点击函数 `daily-news-push`
4. 点击"日志查询"标签

**GitHub**：
1. 访问 https://github.com/paullbuth-arch/ai-daily-news/actions
2. 点击具体的运行记录
3. 展开各个步骤查看日志

### Q4: 推送失败怎么办？

**常见原因**：
1. 新闻源暂时无法访问（会自动重试）
2. GitHub API 请求限制（等待一段时间）
3. 企业微信群机器人被禁用（重新创建）
4. 阿里云函数执行超时（增加超时时间）

### Q5: 如何添加更多新闻源？

编辑 `get_ai_news.py` 文件，在 `RSS_SOURCES` 列表中添加：

```python
RSS_SOURCES = [
    {
        'name': '你的新闻源',
        'url': 'https://example.com/rss',
        'category': '分类'
    },
    # ... 更多源
]
```

---

## 🔄 换电脑/重新部署指南

### 场景1：已部署的服务正常运行，只需管理

**你只需要**：
1. 访问阿里云控制台：https://fc.console.aliyun.com/
2. 登录你的阿里云账号
3. 查看和管理函数

**无需重新部署！**

---

### 场景2：需要在新电脑重新部署

#### 步骤1：克隆项目

```bash
git clone https://github.com/paullbuth-arch/ai-daily-news.git
cd ai-daily-news
```

#### 步骤2：配置 GitHub Actions

1. 访问：https://github.com/paullbuth-arch/ai-daily-news/settings/secrets/actions
2. 添加 `WECOM_WEBHOOK` Secret：
   ```
   https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=你的key
   ```

#### 步骤3：配置阿里云函数计算

**方式A：手动配置（推荐，3分钟）**

1. 访问 https://fc.console.aliyun.com/
2. 选择地域（华东1-杭州）
3. 创建服务 `ai-daily-news`
4. 创建函数 `daily-news-push`：
   - 运行环境：Python 3.10
   - 内存：256 MB
   - 超时：300 秒
5. 在线编辑器粘贴 `index.py` 代码
6. 上传 `get_ai_news.py` 和 `requirements.txt`
7. 配置环境变量：
   ```
   WECOM_WEBHOOK = https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=你的key
   ENABLE_TRANSLATION = true
   ```
8. 创建3个定时触发器（见上方定时触发器表格）

**方式B：使用部署脚本（需要AccessKey）**

⚠️ **注意**：部署脚本包含AccessKey，仅在可信环境使用！

```bash
# 1. 创建 deploy.py（手动输入你的AccessKey）
# 2. 运行部署脚本
python3 deploy.py
```

---

## 📁 项目文件说明

### 核心文件

| 文件 | 说明 | 必需 |
|------|------|------|
| `get_ai_news.py` | 主程序，获取新闻并推送 | ✅ 是 |
| `index.py` | 阿里云函数入口 | ✅ 是 |
| `requirements.txt` | Python依赖包 | ✅ 是 |
| `.github/workflows/daily-ai-news.yml` | GitHub Actions配置 | ✅ 是 |
| `README.md` | 项目说明文档 | ✅ 是 |
| `README_ALIYUN.md` | 阿里云部署教程 | ✅ 是 |
| `.gitignore` | Git忽略文件配置 | ✅ 是 |

### 本地文件（不推送）

| 文件 | 说明 |
|------|------|
| `deploy_sdk.py` | 自动部署脚本（包含AccessKey） |
| `aliyun_deploy.py` | 备用部署脚本 |
| `code.zip` | 代码打包文件 |

---

## 🎯 快速参考

### 重要链接

- **GitHub仓库**：https://github.com/paullbuth-arch/ai-daily-news
- **阿里云控制台**：https://fc.console.aliyun.com/
- **GitHub Actions**：https://github.com/paullbuth-arch/ai-daily-news/actions

### 推送时间

- ⏰ **早上**：09:20（北京时间）
- ⏰ **中午**：12:20（北京时间）
- ⏰ **下午**：15:50（北京时间）

### 功能列表

- 📰 AI新闻（自动翻译）
- 🔥 GitHub项目（带用途说明）
- 🎉 节日提醒（传统节日+特殊日期）
- 🔗 可点击链接
- 💬 企业微信推送
- 📧 邮件推送（可选）

---

## 💡 使用建议

### 日常使用

- **查看推送**：直接查看企业微信群或邮箱
- **检查状态**：偶尔查看阿里云/GitHub日志
- **修改配置**：建议通过网页控制台修改

### 维护

- **定期检查**：每月检查一次运行状态
- **更新代码**：如有新功能，从GitHub拉取最新代码
- **更新密钥**：如果AccessKey泄露，立即更新并重新部署

### 备份

- **代码备份**：已托管在GitHub，随时可以拉取
- **配置备份**：记住企业微信Webhook和邮箱授权码
- **AccessKey备份**：安全保存在本地，不要上传到任何地方

---

## 📞 获取帮助

### 文档位置

- **当前文档**：项目根目录 `USAGE_GUIDE.md`
- **阿里云教程**：`README_ALIYUN.md`
- **项目说明**：`README.md`

### 遇到问题？

1. 查看本文档的"常见问题"部分
2. 查看阿里云/GitHub的执行日志
3. 访问GitHub Issues：https://github.com/paullbuth-arch/ai-daily-news/issues

---

## 🎉 总结

你现在拥有一个**完全自动化的AI新闻推送系统**：

- ✅ 双重保障（阿里云 + GitHub）
- ✅ 准时推送（误差几秒）
- ✅ 完全免费（在免费额度内）
- ✅ 功能丰富（翻译、链接、节日提醒）
- ✅ 文档完整（换电脑也能快速部署）

**享受每日AI新闻吧！** 🚀📱

---

**文档版本**：v1.0
**最后更新**：2025年3月8日
**维护者**：paullbuth-arch
