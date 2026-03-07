#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
阿里云函数计算 - 函数入口文件
直接复制到阿里云FC控制台的在线编辑器
"""

import sys
import os

def handler(event, context):
    """
    阿里云函数计算入口函数
    """
    # 导入主程序
    try:
        # 导入你的新闻推送程序
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
