# 🤖 每日AI新闻速递

> 自动推送每日AI新闻和GitHub热门AI项目到你的邮箱和企业微信

## ✨ 功能特点

- 📰 **AI新闻聚合**：自动获取多个来源的AI相关新闻，**智能过滤只推送AI内容**
- 🔥 **GitHub项目推荐**：每天推送GitHub上最新的热门AI项目
- 📧 **邮件推送**：精美HTML格式的邮件推送
- 💬 **企业微信通知**：简洁的Markdown格式摘要推送
- ⏰ **多时段推送**：每天3个时段定时推送（9:20、12:20、15:50）
- 🎉 **节日提醒**：智能识别节日、周末、月初等特殊日期
- 🎯 **智能过滤**：扩展的AI关键词库，确保只推送AI相关的高质量内容

## 📅 推送时间

系统每天会在以下时间自动推送（北京时间）：

| 时间段 | 推送时间 | 说明 |
|--------|---------|------|
| ☀️ 早上 | 09:20 | 早上开工，浏览最新AI新闻 |
| 🌤️ 中午 | 12:20 | 午休时间，了解行业动态 |
| 🌤️ 下午 | 15:50 | 下午茶时间，发现热门项目 |

## 🎉 节日提醒功能

系统会自动识别以下特殊日期：

### 📌 固定节日
- 元旦、春节、元宵节、清明节
- 劳动节、端午节、教师节
- 国庆节、中秋节、重阳节
- 情人节、愚人节、圣诞节等

### 📅 特殊日期
- **周末提醒**：周六/周日特殊问候
- **周一激励**：新的一周加油打气
- **月初提醒**：每月1日提醒制定新目标

## 🚀 快速开始

### 1. 创建企业微信群机器人（可选）

如果你想要企业微信通知：

1. 在企业微信群中：点击右上角 `...` → `群机器人` → `添加机器人`
2. 设置机器人名称（如"AI小助手"）
3. 复制 Webhook 地址，格式如：`https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxxx`

### 2. 配置邮箱（推荐）

你需要一个可以发送邮件的邮箱账号，以下是一些选择：

#### 方式一：使用QQ邮箱（推荐）
- SMTP服务器：`smtp.qq.com`
- 端口：`587`（TLS）或 `465`（SSL）
- 需要在QQ邮箱设置中开启SMTP服务并获取授权码

#### 方式二：使用Gmail
- SMTP服务器：`smtp.gmail.com`
- 端口：`587`（TLS）
- 需要开启应用专用密码

#### 方式三：使用163邮箱
- SMTP服务器：`smtp.163.com`
- 端口：`465`（SSL）或 `994`（SSL）
- 需要开启SMTP服务并获取授权码

#### 方式四：使用企业邮箱
如果你有企业邮箱，直接使用企业邮箱的SMTP配置即可

### 3. Fork 本项目到你的 GitHub

1. 点击右上角的 Fork 按钮
2. 将项目 Fork 到你自己的 GitHub 账号

### 4. 配置 GitHub Secrets

在你 Fork 的仓库中配置以下 Secrets：

进入：`Settings` → `Secrets and variables` → `Actions` → `New repository secret`

#### 必须配置的 Secrets：

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `EMAIL_TO` | 接收邮件的邮箱 | `your-email@example.com` |
| `EMAIL_FROM` | 发送邮件的邮箱 | `your-email@qq.com` |
| `SMTP_HOST` | SMTP服务器地址 | `smtp.qq.com` |
| `SMTP_PORT` | SMTP端口 | `587` |
| `SMTP_USER` | SMTP用户名（通常是邮箱） | `your-email@qq.com` |
| `SMTP_PASSWORD` | SMTP密码（授权码） | `your-authorization-code` |

#### 可选配置的 Secrets：

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `WECOM_WEBHOOK` | 企业微信机器人Webhook | `https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxxx` |

### 5. 启用 GitHub Actions

1. 进入你 Fork 的仓库
2. 点击 `Actions` 标签
3. 如果提示启用 Actions，点击启用
4. 在左侧选择 `每日AI新闻推送` workflow
5. 点击 `Run workflow` 手动测试一次

### 6. 完成！

现在系统会每天 **北京时间早上 9:00** 自动推送AI新闻到你的邮箱（和企业微信）

## ⏰ 自定义推送时间

如果想修改推送时间，编辑 `.github/workflows/daily-ai-news.yml` 文件中的 cron 表达式：

```yaml
schedule:
  - cron: '20 1 * * *'  # 北京时间 9:20
  - cron: '20 4 * * *'  # 北京时间 12:20
  - cron: '50 7 * * *'  # 北京时间 15:50
```

### 常用 Cron 表达式参考（北京时间）：

| Cron 表达式 | 北京时间 | 说明 |
|------------|---------|------|
| `20 1 * * *` | 09:20 | 早上9点20分 |
| `20 4 * * *` | 12:20 | 中午12点20分 |
| `50 7 * * *` | 15:50 | 下午3点50分 |
| `0 1 * * 1-5` | 09:00 | 工作日早上9点 |
| `0 0,12 * * *` | 08:00, 20:00 | 每天8点和20点 |

**注意**：GitHub Actions 使用 UTC 时间，北京时间 = UTC + 8

## 📰 新闻来源与AI过滤

### 当前新闻源
- MIT Technology Review
- Hacker News
- VentureBeat AI
- AI News
- Towards Data Science
- GitHub Trending（AI相关项目）

### AI关键词过滤

系统使用扩展的AI关键词库进行智能过滤，确保只推送AI相关内容：

**英文关键词**：
- AI, artificial intelligence, machine learning, deep learning
- neural network, LLM, GPT, ChatGPT, OpenAI
- transformer, BERT, diffusion, stable diffusion
- computer vision, NLP, reinforcement learning
- generative AI, Claude, Gemini, Llama, Mistral
- LangChain, AutoML, prompt engineering
- multimodal, embeddings, vector database

**中文关键词**：
- 人工智能, 机器学习, 深度学习, 神经网络
- 大模型, 语言模型, AIGC, 生成式AI
- 计算机视觉, 自然语言处理, 强化学习
- Transformer, 预训练, 微调, 推理
- 多模态, 向量数据库, 提示工程

### 添加自定义新闻源

编辑 `get_ai_news.py` 文件，在 `RSS_SOURCES` 列表中添加：

```python
RSS_SOURCES = [
    {
        'name': '你的新闻源名称',
        'url': 'https://example.com/rss',
        'category': '分类名称'
    },
]
```

### 添加AI关键词

编辑 `get_ai_news.py`，在 `AI_KEYWORDS` 列表中添加：

```python
AI_KEYWORDS = [
    '你的关键词1',
    '你的关键词2',
]
```

## 🎉 自定义节日提醒

编辑 `get_ai_news.py`，在 `FESTIVALS` 字典中添加节日：

```python
FESTIVALS = {
    '0101': '🎉 元旦',
    '1225': '🎄 圣诞节',
    # 添加更多节日，格式为 '月日': '节日名称'
}
```

## 🔧 自定义配置

### 添加更多新闻源

编辑 `get_ai_news.py` 文件，在 `RSS_SOURCES` 列表中添加：

```python
RSS_SOURCES = [
    {
        'name': '你的新闻源名称',
        'url': 'https://example.com/rss',
        'category': '分类名称'
    },
]
```

### 修改 GitHub 主题关键词

编辑 `get_ai_news.py` 文件，修改 `GITHUB_TOPICS` 列表：

```python
GITHUB_TOPICS = [
    'artificial-intelligence',
    'machine-learning',
    'deep-learning',
    # 添加你感兴趣的主题
]
```

### 修改推送数量

在 `get_ai_news.py` 中修改各个函数的 `limit` 参数：

```python
news_list = get_ai_news_from_rss(limit=10)  # 获取10条新闻
projects = get_github_ai_projects(limit=5)   # 获取5个项目
```

## 📬 邮箱配置示例

### QQ邮箱

```
SMTP_HOST: smtp.qq.com
SMTP_PORT: 587
SMTP_USER: your-email@qq.com
SMTP_PASSWORD: 你的授权码（在QQ邮箱设置中获取）
```

**获取QQ邮箱授权码步骤：**
1. 登录 QQ邮箱 (mail.qq.com)
2. 点击 设置 → 账户
3. 找到 "POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV服务"
4. 开启 "SMTP服务"
5. 生成授权码（不是QQ密码！）

### Gmail

```
SMTP_HOST: smtp.gmail.com
SMTP_PORT: 587
SMTP_USER: your-email@gmail.com
SMTP_PASSWORD: 应用专用密码（需要开启两步验证）
```

**获取Gmail应用密码步骤：**
1. 开启Google账户两步验证
2. 进入 Google账户设置
3. 安全性 → 应用密码
4. 生成一个新的应用密码

### 163邮箱

```
SMTP_HOST: smtp.163.com
SMTP_PORT: 465
SMTP_USER: your-email@163.com
SMTP_PASSWORD: 授权码（在163邮箱设置中获取）
```

## 🛠️ 故障排查

### 邮件发送失败

1. **检查SMTP配置是否正确**
2. **确认授权码是否有效**（不是邮箱登录密码）
3. **检查SMTP端口**（587用于TLS，465用于SSL）
4. **确认邮箱已开启SMTP服务**

### GitHub Actions 运行失败

1. 检查 Secrets 是否配置完整
2. 查看 Actions 日志：点击具体的运行记录 → 查看详细日志
3. 确认 Python 脚本没有语法错误

### 企业微信通知失败

1. 确认 Webhook 地址正确
2. 检查企业微信群机器人是否被删除
3. 查看企业微信群机器人是否有发送频率限制

### 没有收到推送

1. 检查垃圾邮件文件夹
2. 确认 GitHub Actions 是否正常运行
3. 查看 Actions 日志确认是否发送成功
4. 检查邮箱配置是否正确

## 📝 手动测试

配置完成后，你可以手动运行一次测试：

1. 进入仓库的 `Actions` 页面
2. 选择 `每日AI新闻推送` workflow
3. 点击 `Run workflow` → `Run workflow`
4. 等待运行完成，检查是否收到邮件/微信通知

## 🎨 自定义邮件样式

你可以修改 `get_ai_news.py` 中的 `format_email_content` 函数来自定义邮件的HTML样式。

## 📄 License

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 💡 提示

- **GitHub Actions 有使用限制**：公开仓库免费，每月有2000分钟免费额度
- **邮件发送频率**：建议每天只发送一次，避免被邮箱服务商限制
- **新闻源稳定性**：某些RSS源可能不稳定，脚本会自动跳过失败的源

## 📮 联系方式

如有问题，请在 GitHub Issues 中提出。

---

**享受每日AI新闻！** 🎉
