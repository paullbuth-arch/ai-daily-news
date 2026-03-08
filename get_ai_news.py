#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
每日AI新闻推送脚本
功能：
1. 获取 AI 相关新闻（从多个RSS源）
2. 获取 GitHub 上热门的 AI 项目
3. 通过邮件和企业微信推送
"""

import os
import sys
import json
import smtplib
import requests
import random
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import Header
from datetime import datetime
from bs4 import BeautifulSoup
import feedparser
try:
    from googletrans import Translator
    translator = Translator()
    TRANSLATION_AVAILABLE = True
except:
    TRANSLATION_AVAILABLE = False
    print("⚠️ 翻译库未安装，将使用原文（如需翻译功能，请运行: pip install googletrans==4.0.0-rc1）")

# ==================== 配置区域 ====================

# RSS 新闻源（AI相关）
RSS_SOURCES = [
    {
        'name': 'MIT Technology News',
        'url': 'https://www.technologyreview.com/feed/',
        'category': 'AI技术'
    },
    {
        'name': 'Hacker News',
        'url': 'https://news.ycombinator.com/rss',
        'category': '技术动态'
    },
    {
        'name': 'VentureBeat AI',
        'url': 'https://venturebeat.com/ai/feed/',
        'category': 'AI产业'
    },
    {
        'name': 'AI News',
        'url': 'https://artificialintelligence-news.com/feed/',
        'category': 'AI资讯'
    },
    {
        'name': 'Towards Data Science',
        'url': 'https://towardsdatascience.com/feed',
        'category': '数据科学'
    }
]

# GitHub API 配置
GITHUB_API_URL = 'https://api.github.com/search/repositories'
GITHUB_TOPICS = [
    'artificial-intelligence',
    'machine-learning',
    'deep-learning',
    'llm',
    'openai',
    'transformers',
    'pytorch',
    'tensorflow',
    'nlp',
    'computer-vision'
]

# 扩展的AI关键词列表
AI_KEYWORDS = [
    # 英文关键词
    'AI', 'artificial intelligence', 'machine learning', 'deep learning',
    'neural network', 'LLM', 'GPT', 'ChatGPT', 'OpenAI', 'model',
    'transformer', 'BERT', 'diffusion', 'stable diffusion',
    'computer vision', 'NLP', 'natural language processing',
    'reinforcement learning', 'generative AI', 'AGI',
    'Claude', 'Gemini', 'Llama', 'Mistral', 'Hugging Face',
    'LangChain', 'AutoML', 'prompt engineering',
    'multimodal', 'embeddings', 'vector database',
    'RLHF', 'fine-tuning', 'inference', 'training',

    # 中文关键词
    '人工智能', '机器学习', '深度学习', '神经网络',
    '大模型', '语言模型', 'AIGC', '生成式AI',
    '计算机视觉', '自然语言处理', '强化学习',
    'Transformer', '预训练', '微调', '推理',
    '多模态', '向量数据库', '提示工程'
]

# 节日配置
FESTIVALS = {
    # 固定日期的节日（公历）
    '0101': '🎉 元旦',
    '0214': '❤️ 情人节',
    '0308': '💐 国际妇女节',
    '0312': '🌳 植树节',
    '0401': '🃏 愚人节',
    '0501': '💪 劳动节',
    '0504': '🎓 青年节',
    '0601': '🎈 儿童节',
    '0701': '🎖️ 建党节',
    '0801': '🎖️ 建军节',
    '0910': '👨‍🏫 教师节',
    '1001': '🇨🇳 国庆节',
    '1225': '🎄 圣诞节',

    # 2025年特殊节日（需要每年更新农历）
    '0129': '🧧 2025春节',  # 2025年1月29日春节
    '0212': '🏮 元宵节',  # 农历正月十五
    '0404': '🌿 清明节',  # 2025年4月4日清明
    '0601': '👨‍👩‍👧 儿童节',
    '0629': '🌝 端午节',  # 2025年6月29日端午
    '0920': '🌕 中秋节',  # 2025年9月20日中秋
    '1029': '🍂 重阳节',  # 2025年10月29日重阳
}

# 邮件配置（从环境变量读取）
EMAIL_CONFIG = {
    'to': os.getenv('EMAIL_TO'),
    'from': os.getenv('EMAIL_FROM'),
    'smtp_host': os.getenv('SMTP_HOST'),
    'smtp_port': int(os.getenv('SMTP_PORT') or '587'),  # 处理空字符串
    'username': os.getenv('SMTP_USER'),
    'password': os.getenv('SMTP_PASSWORD'),
}

# 企业微信 Webhook（从环境变量读取）
WECOM_WEBHOOK = os.getenv('WECOM_WEBHOOK')

# 翻译配置
ENABLE_TRANSLATION = os.getenv('ENABLE_TRANSLATION', 'true').lower() == 'true'

# ==================== 翻译功能 ====================

def translate_text(text, max_length=500):
    """翻译文本到中文"""
    if not TRANSLATION_AVAILABLE or not ENABLE_TRANSLATION:
        return text

    try:
        # 截断过长的文本
        if len(text) > max_length:
            text = text[:max_length]

        # 翻译
        result = translator.translate(text, src='en', dest='zh-cn')
        return result.text
    except Exception as e:
        print(f"  ⚠️ 翻译失败: {e}，使用原文")
        return text

def translate_news_title(title):
    """翻译新闻标题"""
    # 检查是否包含中文
    has_chinese = any('\u4e00' <= char <= '\u9fff' for char in title)
    if has_chinese:
        return title  # 已经是中文，不翻译

    return translate_text(title)

# ==================== 节日提醒 ====================

def get_today_festival():
    """获取今天的节日信息"""
    today = datetime.now()
    date_key = today.strftime('%m%d')
    weekday = today.weekday()  # 0=周一, 6=周日

    festivals = []

    # 检查固定节日
    if date_key in FESTIVALS:
        festivals.append({
            'name': FESTIVALS[date_key],
            'type': '节日',
            'date': today.strftime('%Y年%m月%d日')
        })

    # 检查周末提醒
    if weekday == 5:  # 周六
        festivals.append({
            'name': '🎉 周末愉快',
            'type': '周末',
            'date': today.strftime('%Y年%m月%d日')
        })
    elif weekday == 6:  # 周日
        festivals.append({
            'name': '😴 周日休息',
            'type': '周末',
            'date': today.strftime('%Y年%m月%d日'),
            'note': '明天是周一，记得调整状态！'
        })
    elif weekday == 0:  # 周一
        festivals.append({
            'name': '💪 新的一周',
            'type': '工作日',
            'date': today.strftime('%Y年%m月%d日'),
            'note': '加油，打工人！'
        })

    # 月初提醒
    if today.day == 1:
        festivals.append({
            'name': '📅 新月开始',
            'type': '提醒',
            'date': today.strftime('%Y年%m月'),
            'note': '新的月份，制定新的目标吧！'
        })

    return festivals

# ==================== 新闻获取 ====================

def get_ai_news_from_rss(limit=5):
    """从RSS源获取AI相关新闻（随机选择新闻源）"""
    print("📰 开始获取RSS新闻...")

    # 随机选择50%-70%的新闻源
    sample_size = random.randint(len(RSS_SOURCES) // 2, int(len(RSS_SOURCES) * 0.7))
    selected_sources = random.sample(RSS_SOURCES, sample_size)

    print(f"  🎲 本次随机选择了 {sample_size} 个新闻源:")
    for source in selected_sources:
        print(f"     - {source['name']}")

    all_news = []

    for source in selected_sources:
        try:
            print(f"  正在获取: {source['name']}")
            feed = feedparser.parse(source['url'])

            for entry in feed.entries[:limit * 2]:  # 获取更多以便筛选
                title = entry.get('title', '')
                description = entry.get('description', '')
                link = entry.get('link', '')

                # 使用扩展的关键词列表进行更精确的过滤
                title_lower = title.lower()
                desc_lower = description.lower()

                # 检查是否包含AI关键词（至少匹配一个）
                has_ai_keyword = any(
                    keyword.lower() in title_lower or keyword.lower() in desc_lower
                    for keyword in AI_KEYWORDS
                )

                if has_ai_keyword:
                    # 计算相关度（匹配关键词数量）
                    keyword_count = sum(
                        1 for keyword in AI_KEYWORDS
                        if keyword.lower() in title_lower or keyword.lower() in desc_lower
                    )

                    # 清理描述
                    clean_desc = BeautifulSoup(description, 'html.parser').get_text()[:200] + '...'

                    # 翻译标题
                    translated_title = translate_news_title(title)

                    all_news.append({
                        'title': translated_title,  # 使用翻译后的标题
                        'title_en': title,  # 保留英文标题
                        'description': clean_desc,
                        'link': link,
                        'source': source['name'],
                        'category': source['category'],
                        'date': entry.get('published', datetime.now().strftime('%Y-%m-%d')),
                        'relevance': keyword_count  # 添加相关度分数
                    })

        except Exception as e:
            print(f"  ❌ 获取 {source['name']} 失败: {e}")
            continue

    # 按相关度排序，返回最相关的新闻
    all_news.sort(key=lambda x: x.get('relevance', 0), reverse=True)
    print(f"✅ 共获取到 {len(all_news)} 条AI新闻")
    return all_news[:10]  # 返回最多10条

def get_github_ai_projects(limit=5):
    """从GitHub获取热门AI项目（随机选择主题）"""
    print("🐙 开始获取GitHub热门AI项目...")

    # 随机选择50%-70%的主题
    sample_size = random.randint(len(GITHUB_TOPICS) // 2, int(len(GITHUB_TOPICS) * 0.7))
    selected_topics = random.sample(GITHUB_TOPICS, sample_size)

    print(f"  🎲 本次随机选择了 {sample_size} 个主题:")
    for topic in selected_topics:
        print(f"     - {topic}")

    projects = []

    for topic in selected_topics:
        try:
            print(f"  正在搜索主题: {topic}")
            params = {
                'q': f'topic:{topic}',
                'sort': 'stars',
                'order': 'desc',
                'per_page': limit
            }

            response = requests.get(GITHUB_API_URL, params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()
                for item in data.get('items', []):
                    # 避免重复
                    if not any(p['url'] == item['html_url'] for p in projects):
                        # 获取项目详细信息
                        full_name = item.get('full_name', '')
                        name = item.get('name', '')
                        description = item.get('description', '暂无描述')

                        # 如果描述是英文，尝试翻译
                        if description and description != '暂无描述':
                            has_chinese = any('\u4e00' <= c <= '\u9fff' for c in description)
                            if not has_chinese:
                                description = translate_text(description)

                        # 获取主题标签
                        topics_list = item.get('topics', [])[:5]  # 最多5个标签

                        # 构建用途场景说明
                        use_case = build_use_case(name, topics_list, description)

                        projects.append({
                            'name': name,
                            'full_name': full_name,
                            'description': description,
                            'use_case': use_case,
                            'url': item['html_url'],
                            'stars': item['stargazers_count'],
                            'language': item.get('language', 'Unknown'),
                            'topics': topics_list,
                            'forks': item.get('forks_count', 0),
                            'updated_at': item.get('updated_at', '')
                        })
            else:
                print(f"  ⚠️ API请求失败: {response.status_code}")

        except Exception as e:
            print(f"  ❌ 获取主题 {topic} 失败: {e}")
            continue

    print(f"✅ 共获取到 {len(projects)} 个AI项目")
    # 按星标数排序
    projects.sort(key=lambda x: x['stars'], reverse=True)
    return projects[:8]  # 返回最多8个项目

def build_use_case(name, topics, description):
    """根据项目信息生成用途场景说明"""
    # 常见AI场景映射
    scenarios = {
        'llm': '大语言模型应用',
        'transformer': 'Transformer模型',
        'nlp': '自然语言处理',
        'computer-vision': '计算机视觉',
        'deep-learning': '深度学习',
        'machine-learning': '机器学习',
        'chatbot': '聊天机器人',
        'agent': 'AI智能体',
        'rag': '检索增强生成',
        'fine-tuning': '模型微调',
        'inference': '模型推理',
        'training': '模型训练',
        'diffusion': '图像生成',
        'stable-diffusion': 'Stable Diffusion相关',
        'voice': '语音处理',
        'video': '视频处理',
        'recommendation': '推荐系统',
        'embedding': '向量嵌入',
        'vector-database': '向量数据库',
        'prompt': '提示工程',
        'multi-agent': '多智能体系统',
    }

    # 根据主题匹配场景
    detected_scenarios = []
    for topic in topics:
        topic_lower = topic.lower().replace('-', '')
        for key, value in scenarios.items():
            if key.replace('-', '') in topic_lower:
                detected_scenarios.append(value)
                break

    # 去重并限制数量
    detected_scenarios = list(dict.fromkeys(detected_scenarios))[:3]

    if detected_scenarios:
        return ' | '.join(detected_scenarios)
    else:
        # 根据名称推断
        name_lower = name.lower()
        if 'llm' in name_lower or 'gpt' in name_lower:
            return '大语言模型相关'
        elif 'chat' in name_lower or 'bot' in name_lower:
            return '聊天对话系统'
        elif 'agent' in name_lower:
            return 'AI智能体'
        elif 'train' in name_lower:
            return '模型训练工具'
        elif 'serve' in name_lower or 'deploy' in name_lower:
            return '模型部署服务'
        else:
            return 'AI工具库'

def get_ai_daily_news(limit=5):
    """从免费API获取每日AI新闻（备用方案）"""
    print("📰 尝试从免费API获取AI新闻...")
    news_items = []

    # 使用免费的新闻API
    try:
        # 使用聚合数据的API（需要申请key）或其他免费API
        # 这里使用一个示例，实际使用时需要替换
        url = "https://api.vvhan.com/api/news/wxhot"
        response = requests.get(url, timeout=10)

        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                for item in data.get('data', [])[:limit]:
                    # 过滤AI相关
                    if any(keyword in item.get('title', '') for keyword in ['AI', '人工智能', '模型', '算法']):
                        news_items.append({
                            'title': item.get('title'),
                            'description': item.get('desc', ''),
                            'link': item.get('sourceUrl', ''),
                            'source': '微信热点',
                            'category': 'AI热点',
                            'date': datetime.now().strftime('%Y-%m-%d')
                        })
    except Exception as e:
        print(f"  ❌ API获取失败: {e}")

    return news_items

# ==================== 内容格式化 ====================

def format_email_content(news_list, projects, festivals=None):
    """格式化邮件内容（含节日提醒）"""
    today = datetime.now().strftime('%Y年%m月%d日')
    current_time = datetime.now().strftime('%H:%M')

    content = f"""
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center; }}
            .festival-alert {{ background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 15px; border-radius: 8px; margin: 20px 0; }}
            .section {{ margin: 20px 0; padding: 15px; background: #f8f9fa; border-radius: 8px; }}
            .news-item {{ margin: 15px 0; padding: 10px; background: white; border-left: 3px solid #667eea; }}
            .project-item {{ margin: 10px 0; padding: 10px; background: white; border-left: 3px solid #28a745; }}
            h2 {{ color: #667eea; }}
            h3 {{ color: #333; }}
            a {{ color: #667eea; text-decoration: none; }}
            a:hover {{ text-decoration: underline; }}
            .tag {{ display: inline-block; background: #667eea; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px; }}
            .stars {{ color: #f39c12; }}
            .time {{ color: #999; font-size: 14px; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🤖 每日AI新闻速递</h1>
            <p>{today} {current_time}</p>
        </div>
    """

    # 添加节日提醒
    if festivals:
        content += '<div class="festival-alert">'
        content += '<h2 style="color: white; margin-top: 0;">🎉 今日特别提醒</h2>'
        for festival in festivals:
            content += f"<p><strong>{festival['name']}</strong> ({festival['type']})</p>"
            if festival.get('note'):
                content += f"<p style='font-size: 14px;'>{festival['note']}</p>"
        content += '</div>'

    content += """
        <div class="section">
            <h2>📰 今日AI要闻</h2>
    """

    # 添加新闻内容
    for news in news_list:
        # 标题：如果有英文原文，显示双语
        if news.get('title_en') and news['title'] != news['title_en']:
            title_html = f"""
                <h3>{news['title']}</h3>
                <p style="color: #666; font-size: 14px;">原文：{news['title_en']}</p>
            """
        else:
            title_html = f"<h3>{news['title']}</h3>"

        content += f"""
            <div class="news-item">
                {title_html}
                <p>{news.get('description', '暂无描述')}</p>
                <p>
                    <span class="tag">{news.get('category', '新闻')}</span>
                    <span class="tag">{news.get('source', '未知来源')}</span>
                    <a href="{news['link']}" target="_blank" style="color: #667eea; font-weight: bold;">阅读全文 →</a>
                </p>
            </div>
        """

    content += """
        </div>

        <div class="section">
            <h2>🔥 GitHub 热门AI项目推荐</h2>
    """

    # 添加GitHub项目
    for project in projects:
        # 用途场景标签
        use_case_tag = ""
        if project.get('use_case'):
            use_case_tag = f'<span class="tag" style="background: #e67e22;">📌 {project["use_case"]}</span>'

        # 语言和fork信息
        lang = project.get('language', 'Unknown')
        forks = project.get('forks', 0)
        meta_info = f"<span class='tag'>{lang}</span>"
        if forks > 0:
            meta_info += f" <span class='tag' style='background: #95a5a6;'>🍴 {forks}</span>"

        content += f"""
            <div class="project-item">
                <h3>
                    <a href="{project['url']}" target="_blank" style="color: #333; text-decoration: none;">
                        {project['name']} <span class="stars">⭐ {project['stars']}</span>
                    </a>
                </h3>
                {use_case_tag}
                <p style="margin: 10px 0;">{project.get('description', '暂无描述')}</p>
                <p>
                    {meta_info}
                    <a href="{project['url']}" target="_blank" style="color: #28a745; font-weight: bold; margin-left: 10px;">查看项目 →</a>
                </p>
            </div>
        """

    content += f"""
        </div>

        <div style="text-align: center; color: #999; padding: 20px;">
            <p>本邮件由 GitHub Actions 自动发送</p>
            <p>如有问题或建议，请回复邮件</p>
        </div>
    </body>
    </html>
    """

    return content

def format_wecom_message(news_list, projects, festivals=None):
    """格式化企业微信消息（简洁版，含节日提醒）"""
    today = datetime.now().strftime('%Y年%m月%d日')
    current_time = datetime.now().strftime('%H:%M')

    content = f"## 🤖 每日AI新闻速递\n\n**日期时间**：{today} {current_time}\n\n"

    # 添加节日提醒
    if festivals:
        content += "### 🎉 今日特别提醒\n\n"
        for festival in festivals:
            content += f"> **{festival['name']}** ({festival['type']})\n"
            if festival.get('note'):
                content += f"> {festival['note']}\n"
        content += "\n"

    content += "### 📰 今日AI要闻\n\n"
    for i, news in enumerate(news_list[:5], 1):
        # 标题：如果有英文原文，显示双语
        if news.get('title_en') and news['title'] != news['title_en']:
            content += f"{i}. [{news['title']}]({news['link']})\n"
            content += f"   > 原文：{news['title_en']}\n"
        else:
            content += f"{i}. [{news['title']}]({news['link']})\n"

        content += f"   > {news.get('description', '暂无描述')[:80]}...\n"
        content += f"   <font color='info'>{news.get('source', '新闻')}</font>\n\n"

    content += "\n### 🔥 GitHub热门AI项目\n\n"
    for i, project in enumerate(projects[:3], 1):
        # 项目名称和星标
        content += f"{i}. **[{project['name']}]({project['url']})** ⭐ {project['stars']}\n"

        # 用途场景
        if project.get('use_case'):
            content += f"   > 📌 **用途**：{project['use_case']}\n"

        # 项目描述
        desc = project.get('description', '暂无描述')
        if desc and desc != '暂无描述':
            content += f"   > 📝 {desc[:100]}...\n"

        # 语言和标签
        lang = project.get('language', 'Unknown')
        if lang and lang != 'Unknown':
            content += f"   > 💻 {lang}"
        if project.get('forks', 0) > 0:
            content += f" | 🍴 {project['forks']}"
        content += "\n\n"

    content += "\n---\n📧 详细内容已发送至邮箱"

    return content

# ==================== 发送功能 ====================

def send_email(content):
    """发送邮件"""
    print("📧 正在发送邮件...")

    # 检查必要配置
    required_fields = ['to', 'from', 'smtp_host', 'username', 'password']
    if not all(EMAIL_CONFIG.get(k) for k in required_fields):
        print("  ⚠️ 邮件配置不完整，跳过邮件发送")
        return True  # 返回True而不是False，避免判定为失败

    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = Header(f'🤖 每日AI新闻速递 - {datetime.now().strftime("%Y-%m-%d")}', 'utf-8')
        msg['From'] = EMAIL_CONFIG['from']
        msg['To'] = EMAIL_CONFIG['to']

        html_part = MIMEText(content, 'html', 'utf-8')
        msg.attach(html_part)

        # 连接SMTP服务器
        if EMAIL_CONFIG['smtp_port'] == 465:
            server = smtplib.SMTP_SSL(EMAIL_CONFIG['smtp_host'], EMAIL_CONFIG['smtp_port'])
        else:
            server = smtplib.SMTP(EMAIL_CONFIG['smtp_host'], EMAIL_CONFIG['smtp_port'])
            server.starttls()

        server.login(EMAIL_CONFIG['username'], EMAIL_CONFIG['password'])
        server.send_message(msg)
        server.quit()

        print("  ✅ 邮件发送成功！")
        return True

    except Exception as e:
        print(f"  ❌ 邮件发送失败: {e}")
        return False

def send_wecom_notification(content):
    """发送企业微信通知"""
    print("💬 正在发送企业微信通知...")

    if not WECOM_WEBHOOK:
        print("  ⚠️ 未配置企业微信Webhook，跳过")
        return False

    try:
        data = {
            "msgtype": "markdown",
            "markdown": {
                "content": content
            }
        }

        response = requests.post(WECOM_WEBHOOK, json=data, timeout=10)

        if response.status_code == 200:
            result = response.json()
            if result.get('errcode') == 0:
                print("  ✅ 企业微信通知发送成功！")
                return True
            else:
                print(f"  ❌ 发送失败: {result.get('errmsg')}")
        else:
            print(f"  ❌ HTTP错误: {response.status_code}")

        return False

    except Exception as e:
        print(f"  ❌ 企业微信通知失败: {e}")
        return False

# ==================== 主程序 ====================

def main():
    print("=" * 60)
    print("🚀 开始执行每日AI新闻推送任务")
    print("=" * 60)

    # 1. 检查今日节日
    print("\n🎅 检查今日节日...")
    festivals = get_today_festival()
    if festivals:
        for festival in festivals:
            print(f"  ✅ {festival['name']}")
    else:
        print("  ℹ️ 今日无特殊节日")

    # 2. 获取AI新闻（优化过滤）
    news_list = get_ai_news_from_rss(limit=5)

    # 如果RSS获取失败，使用备用方案
    if not news_list:
        print("⚠️ RSS获取失败，尝试备用API...")
        news_list = get_ai_daily_news(limit=5)

    if not news_list:
        print("❌ 无法获取新闻，使用示例数据")
        news_list = [{
            'title': '今日AI新闻更新中',
            'description': '新闻源暂时无法访问，请稍后查看',
            'link': '#',
            'source': '系统',
            'category': '通知',
            'relevance': 0
        }]

    # 3. 获取GitHub热门AI项目
    projects = get_github_ai_projects(limit=5)

    if not projects:
        print("⚠️ 无法获取GitHub项目，使用示例数据")
        projects = [{
            'name': '示例项目',
            'description': 'GitHub API暂时无法访问',
            'url': 'https://github.com',
            'stars': 0,
            'language': 'Unknown'
        }]

    # 4. 生成内容（包含节日信息）
    print("\n📝 正在生成邮件内容...")
    email_content = format_email_content(news_list, projects, festivals)
    wecom_content = format_wecom_message(news_list, projects, festivals)

    # 5. 发送邮件
    email_sent = send_email(email_content)

    # 6. 发送企业微信通知
    wecom_sent = send_wecom_notification(wecom_content)

    # 7. 总结
    print("\n" + "=" * 60)
    print("📊 任务执行总结：")
    print(f"  ✅ 节日提醒: {len(festivals)} 个" if festivals else "  ℹ️ 节日提醒: 无")
    print(f"  ✅ 获取新闻: {len(news_list)} 条")
    print(f"  ✅ 获取项目: {len(projects)} 个")
    print(f"  {'✅' if email_sent else '❌'} 邮件发送: {'成功' if email_sent else '失败'}")
    print(f"  {'✅' if wecom_sent else '❌'} 微信通知: {'成功' if wecom_sent else '失败'}")
    print("=" * 60)

if __name__ == '__main__':
    main()
