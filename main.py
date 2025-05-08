import os
import sys

sys.path.append('D:\\anaconda\\lib\\site-packages')
import threading
import collections
from flask import Flask, request, jsonify
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation
import datetime
import requests

from PreProcess import preprocess3, preprocess1

app = Flask(__name__)

APPID = 'wx5a83526f8eca0449'
SECRET = '907a464400ff1dcf21c297019e543582'

fs = 250

user_sessions = {}
session_lock = threading.Lock()

# 用于存储处理后的数据以供绘图
processed_raw_buffer = collections.deque(maxlen=1500)
processed_processed_buffer = collections.deque(maxlen=1500)


def get_user_session(user_id):
    current_time = datetime.datetime.now()
    user_dir = os.path.join('data', user_id)

    with session_lock:
        os.makedirs(user_dir, exist_ok=True)

        if user_id not in user_sessions or \
                (current_time - user_sessions[user_id]['last_time']).total_seconds() > 5:
            timestamp = current_time.strftime("%Y%m%d_%H%M%S_%f")[:-3]
            user_sessions[user_id] = {
                'last_time': current_time,
                'raw_file': os.path.join(user_dir, f"raw_{timestamp}.txt"),
                'processed_file': os.path.join(user_dir, f"processed_{timestamp}.txt"),
                'processing_buffer': []
            }
        else:
            user_sessions[user_id]['last_time'] = current_time

        return user_sessions[user_id]['raw_file'], user_sessions[user_id]['processed_file']


@app.route('/process', methods=['POST'])
def process_data():
    data = request.json
    points = data.get('points', [])
    user_id = data.get('userId')
    tbr_list = []  # 存储所有窗口的TBR值
    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    raw_file, processed_file = get_user_session(user_id)

    with session_lock:
        session = user_sessions[user_id]
        session['processing_buffer'].extend(points)

    # 写入原始数据
    with open(raw_file, 'a') as f:
        for p in points:
            f.write(f"{p}\n")

    tbr = None
    with session_lock:
        session = user_sessions[user_id]
        processing_buffer = session['processing_buffer']

    while len(processing_buffer) >= 1500:
        raw_window = processing_buffer[:1500]
        processed_points, tbr = preprocess3(raw_window, fs)
        tbr_list.append(tbr)  # 收集每次的TBR值
        # 写入处理后的数据
        with open(processed_file, 'a') as f:
            for pp in processed_points:
                f.write(f"{pp}\n")

        # 更新绘图缓冲区
        processed_raw_buffer.extend(raw_window)
        processed_processed_buffer.extend(processed_points)

        # 移动窗口
        with session_lock:
            session['processing_buffer'] = processing_buffer[125:]
            processing_buffer = session['processing_buffer']

    return jsonify({
        "status": "success",
        "TBR": tbr_list,
    })


@app.route('/getOpenId', methods=['POST'])
def get_openid():
    data = request.json
    code = data.get('code')

    if not code:
        return jsonify({"error": "code is required"}), 400

    url = f"https://api.weixin.qq.com/sns/jscode2session?appid={APPID}&secret={SECRET}&js_code={code}&grant_type=authorization_code"
    response = requests.get(url)
    result = response.json()
    if 'openid' in result:
        return jsonify({"openid": result['openid']})
    else:
        return jsonify({"error": "Failed to get openid", "details": result}), 500


def run_flask():
    app.run(host='0.0.0.0', port=5000, debug=False)


def update_plot(frame):
    x = np.arange(len(processed_raw_buffer))
    y_raw = np.array(processed_raw_buffer)
    y_processed = np.array(processed_processed_buffer)

    raw_line.set_data(x, y_raw)
    processed_line.set_data(x, y_processed)

    ax.set_xlim(0, 1500)
    ax.set_ylim(-200, 200)
    return raw_line, processed_line


if __name__ == '__main__':
    os.makedirs('data', exist_ok=True)
    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()

    fig, ax = plt.subplots()
    raw_line, = ax.plot([], [], label='Raw Data')
    processed_line, = ax.plot([], [], label='Processed Data')
    ax.legend()
    ax.set_title("Processing Window (6s) with 0.5s Overlap")

    ani = FuncAnimation(
        fig,
        update_plot,
        interval=50,
    )

    plt.show()
