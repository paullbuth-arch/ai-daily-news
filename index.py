#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
阿里云函数计算 - 函数入口文件
直接复制到阿里云FC控制台的在线编辑器
"""

import sys
import os

def install_dependencies():
    """
    自动安装依赖包
    阿里云函数计算不会自动安装requirements.txt
    需要在函数启动时手动安装
    """
    import subprocess

    print("📦 正在安装依赖包...")

    packages = [
        'beautifulsoup4',
        'lxml',
        'feedparser',
        'googletrans==4.0.0-rc1',
        'requests',
        'html5lib',
        'urllib3'
    ]

    for package in packages:
        try:
            # 尝试导入，如果失败则安装
            if package == 'beautifulsoup4':
                import bs4
            elif package == 'lxml':
                import lxml
            elif package == 'feedparser':
                import feedparser
            elif 'googletrans' in package:
                import googletrans
            print(f"  ✅ {package} 已安装")
        except ImportError:
            print(f"  ⬇️  正在安装 {package}...")
            try:
                subprocess.check_call([
                    sys.executable, "-m", "pip", "install",
                    package, "-q", "--target", "/opt/python", "--upgrade"
                ], stderr=subprocess.DEVNULL)
                # 将安装路径添加到sys.path最前面
                sys.path.insert(0, '/opt/python/lib/python3.10/site-packages')
                print(f"  ✅ {package} 安装成功")
            except Exception as e:
                print(f"  ❌ {package} 安装失败: {e}")

    print("📦 依赖包安装完成")

def handler(event, context):
    """
    阿里云函数计算入口函数
    """
    # 先安装依赖
    install_dependencies()

    # 导入你的主程序
    try:
        from get_ai_news import main

        # 设置环境变量（也可以在阿里云控制台配置）
        os.environ['WECOM_WEBHOOK'] = os.getenv('WECOM_WEBHOOK',
            'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=11dd60d2-d449-420b-9287-a8556147431f')
        os.environ['ENABLE_TRANSLATION'] = os.getenv('ENABLE_TRANSLATION', 'true')

        # 执行主程序
        main()

        return {
            'statusCode': 200,
            'body': 'AI新闻推送成功',
            'headers': {
                'Content-Type': 'application/json'
            }
        }

    except Exception as e:
        print(f"执行失败: {str(e)}")
        import traceback
        traceback.print_exc()

        return {
            'statusCode': 500,
            'body': f'执行失败: {str(e)}',
            'headers': {
                'Content-Type': 'application/json'
            }
        }
