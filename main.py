import os
import sys
#python库的路径
sys.path.append('D:\\anaconda\\lib\\site-packages')
import threading
import collections
from flask import Flask, request, jsonify
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation
import datetime  # 用于生成时间戳

from sphinx.util import requests

# 假设这里是你已经实现的预处理函数
from PreProcess import preprocess, preprocess1

"""
   该代码用于实时接收小程序的脑电信号
"""

app = Flask(__name__)

# 微信小程序配置
APPID = 'wx5a83526f8eca0449'  # 替换为你的小程序 appid
SECRET = '907a464400ff1dcf21c297019e543582'  # 替换为你的小程序 secret

fs = 250

# 全局变量用于管理用户会话
user_sessions = {}
session_lock = threading.Lock()  # 用于线程安全的锁

# 固定长度队列，用于存放最近 1000 个点
raw_data_buffer = collections.deque(maxlen=1000)
processed_data_buffer = collections.deque(maxlen=1000)


def get_user_session(user_id):
    """
    获取或创建用户会话，返回当前有效的文件名
    """
    current_time = datetime.datetime.now()
    user_dir = os.path.join('data', user_id)

    with session_lock:
        # 创建用户目录
        os.makedirs(user_dir, exist_ok=True)

        # 新用户或超过5秒间隔时创建新会话
        if user_id not in user_sessions or \
                (current_time - user_sessions[user_id]['last_time']).total_seconds() > 5:

            # 生成带毫秒的时间戳
            timestamp = current_time.strftime("%Y%m%d_%H%M%S_%f")[:-3]

            # 创建新会话记录
            user_sessions[user_id] = {
                'last_time': current_time,
                'raw_file': os.path.join(user_dir, f"raw_{timestamp}.txt"),
                'processed_file': os.path.join(user_dir, f"processed_{timestamp}.txt")
            }
        else:
            # 更新最后活动时间
            user_sessions[user_id]['last_time'] = current_time

        return user_sessions[user_id]['raw_file'], user_sessions[user_id]['processed_file']

@app.route('/process', methods=['POST'])
def process_data():
    data = request.json
    points = data.get('points', [])
    user_id = data.get('userId')  # 获取用户ID

    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    # 调用预处理函数
    processed_points, tbr = preprocess1(points, fs)

    # 获取当前会话的文件路径
    raw_file, processed_file = get_user_session(user_id)

    # 将新收到的数据追加到队列
    raw_data_buffer.extend(points)
    processed_data_buffer.extend(processed_points)

    # 写入文件
    with open(raw_file, 'a') as f:
        for p in points:
            f.write(f"{p}\n")

    with open(processed_file, 'a') as f:
        for pp in processed_points:
            f.write(f"{pp}\n")

    return jsonify({
        "status": "success",
        "TBR": tbr,
    })



@app.route('/getOpenId', methods=['POST'])
def get_openid():
    """
    通过 code 获取 openid
    """
    data = request.json
    code = data.get('code')  # 获取小程序发送的 code

    if not code:
        return jsonify({"error": "code is required"}), 400

    # 调用微信接口获取 openid
    url = f"https://api.weixin.qq.com/sns/jscode2session?appid={APPID}&secret={SECRET}&js_code={code}&grant_type=authorization_code"
    response = requests.get(url)
    result = response.json()
    print(result)
    if 'openid' in result:
        return jsonify({"openid": result['openid']})
    else:
        return jsonify({"error": "Failed to get openid", "details": result}), 500


def run_flask():
    """
    启动 Flask 服务
    """
    app.run(host='0.0.0.0', port=5000, debug=False)


def update_plot(frame):
    """
    Matplotlib 动画更新函数，用于刷新曲线
    """
    # x 轴范围设为与队列长度一致
    x = np.arange(len(raw_data_buffer))
    y_raw = np.array(raw_data_buffer)
    y_processed = np.array(processed_data_buffer)

    # 更新原始数据曲线
    raw_line.set_data(x, y_raw)
    # 更新预处理后数据曲线
    processed_line.set_data(x, y_processed)

    # 如果你想让 x 轴固定 0~1000，可以写死下行，否则根据数据长度动态调整
    ax.set_xlim(0, 1000)

    # 这一步可以根据你的信号幅度来定，也可以根据数据自动更新
    # 这里假设信号幅度可能在 -1 ~ 1
    ax.set_ylim(-200, 200)

    return raw_line, processed_line


if __name__ == '__main__':
    # 创建数据存储主目录
    os.makedirs('data', exist_ok=True)

    # 启动Flask线程和Matplotlib可视化
    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()

    # 可视化部分保持不变
    fig, ax = plt.subplots()
    raw_line, = ax.plot([], [], label='Raw Data')
    processed_line, = ax.plot([], [], label='Processed Data')
    ax.legend()
    ax.set_title("Real-time Waveform")

    ani = FuncAnimation(
        fig,
        update_plot,
        init_func=lambda: (raw_line, processed_line),
        interval=50,
    )

    plt.show()