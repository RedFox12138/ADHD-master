#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
WebSocket 连接测试脚本
用于测试后端 WebSocket 是否正常工作
"""

import json
import time
from simple_websocket import Client, ConnectionClosed

def test_websocket():
    print("="*60)
    print("开始测试 WebSocket 连接")
    print("="*60)
    
    try:
        # 连接到 WebSocket 服务器
        print("\n1. 连接到 ws://localhost:5000/ws ...")
        ws = Client.connect('ws://localhost:5000/ws')
        print("✅ 连接成功！")
        
        # 发送注册消息
        print("\n2. 发送用户注册消息...")
        register_msg = {
            'event': 'register_user',
            'userId': 'test_user_123'
        }
        ws.send(json.dumps(register_msg))
        print(f"✅ 已发送: {register_msg}")
        
        # 接收注册确认
        print("\n3. 等待服务器响应...")
        response = ws.receive()
        print(f"✅ 收到响应: {response}")
        
        # 发送心跳
        print("\n4. 发送心跳消息...")
        ping_msg = {'event': 'ping'}
        ws.send(json.dumps(ping_msg))
        print(f"✅ 已发送: {ping_msg}")
        
        # 接收心跳响应
        response = ws.receive(timeout=2)
        print(f"✅ 收到响应: {response}")
        
        # 保持连接，等待服务器推送
        print("\n5. 保持连接30秒，监听服务器推送...")
        print("   （此时可以通过小程序发送数据到后端，观察是否收到推送）")
        
        start_time = time.time()
        while time.time() - start_time < 30:
            try:
                msg = ws.receive(timeout=1)
                if msg:
                    print(f"📩 收到推送: {msg}")
            except:
                pass  # 超时继续等待
        
        # 关闭连接
        print("\n6. 关闭连接...")
        ws.close()
        print("✅ 测试完成！")
        
        print("\n" + "="*60)
        print("✅ WebSocket 功能正常！")
        print("="*60)
        
    except ConnectionClosed as e:
        print(f"\n❌ 连接被关闭: {e}")
    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    print("\n请确保后端服务器已启动（python main.py）")
    input("按回车键开始测试...")
    test_websocket()
