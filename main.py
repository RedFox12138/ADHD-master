import os
import sys

from EntropyHub import SampEn

from SampEn import SampEn_optimized
from SingleDenoise import eog_removal
sys.path.append('D:\\anaconda\\lib\\site-packages')
import threading
import collections
from flask import Flask, request, jsonify
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation
import datetime
import requests
from scipy.signal import spectrogram
from PreProcess import preprocess3,compute_power_ratio

app = Flask(__name__)

APPID = 'wx5a83526f8eca0449'
SECRET = '907a464400ff1dcf21c297019e543582'
fs = 250
user_sessions = {}
session_lock = threading.Lock()
processed_raw_buffer = collections.deque(maxlen=1500)
processed_processed_buffer = collections.deque(maxlen=1500)


def get_user_session(user_id):
    current_time = datetime.datetime.now()
    date_str = current_time.strftime("%Y%m%d")  # 按日期组织数据

    # 创建按日期组织的目录结构
    user_dir = os.path.join('data', user_id, 'data', date_str)
    result_dir = os.path.join('data', user_id, 'result', date_str)

    with session_lock:
        os.makedirs(user_dir, exist_ok=True)
        os.makedirs(result_dir, exist_ok=True)

        if user_id not in user_sessions or \
                (current_time - user_sessions[user_id]['last_time']).total_seconds() > 10:
            timestamp = current_time.strftime("%H%M%S_%f")[:-3]
            user_sessions[user_id] = {
                'last_time': current_time,
                'date': date_str,
                'raw_file': os.path.join(user_dir, f"raw_{timestamp}.txt"),
                'Delta_result': os.path.join(result_dir, f"{timestamp}.txt"),
                'processed_file': os.path.join(user_dir, f"processed_{timestamp}.txt"),
                'processing_buffer': [],
                'delta_cumavg_history': [],
                'tbr_base_list': [],
                'Base_value': None,
                'Base_flag': False
            }
        else:
            user_sessions[user_id]['last_time'] = current_time

        return user_sessions[user_id]['raw_file'], user_sessions[user_id]['processed_file'], user_sessions[user_id][
            'Delta_result']


def calculate_delta_cumavg(eeg_data, Step,fs=250, session=None):
    """计算Delta波段的滑动窗口累积平均功率（6秒窗口，0.5秒步长）"""
    # 设置STFT参数
    window = "hamming"
    nfft = 1024
    # 计算STFT
    f, t, S = spectrogram(np.array(eeg_data), fs=fs, window=window, nperseg=512, noverlap=256, nfft=nfft, mode='magnitude')
    # 定义Delta波段范围
    delta_band = (f >= 0.5) & (f <= 4)  # Delta: 0.5-4Hz
    # 提取Delta波段功率（幅度平方）
    S_delta = np.abs(S[delta_band, :]) ** 2
    # 计算Delta波段瞬时功率（跨频率维度平均）
    delta_power = np.mean(S_delta, axis=0)
    # 计算当前窗口的平均功率
    current_window_avg = np.mean(delta_power) if len(delta_power) > 0 else None
    # 更新会话中的累积平均历史
    if current_window_avg is not None and session is not None:
        if Step == '基准阶段':
            session['delta_cumavg_history'].append(current_window_avg)
            cumulative_avg = np.mean(session['delta_cumavg_history'][-5:])  # 真正的累积平均
            return cumulative_avg
        elif Step == '治疗阶段':
            return current_window_avg
    return None

@app.route('/process', methods=['POST'])
def process_data():
    data = request.json
    points = data.get('points', [])
    user_id = data.get('userId')
    Step = data.get('Step')

    tbr_list = []
    # delta_cumavg_list = []

    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    raw_file, processed_file,delta_file= get_user_session(user_id)

    # if Step == '基准阶段' or Step == '治疗阶段':
    if True:
        with session_lock:
            session = user_sessions[user_id]
            session['processing_buffer'].extend(points)

        with open(raw_file, 'a') as f:
            for p in points:
                f.write(f"{p}\n")
            f.flush()


        with session_lock:
            session = user_sessions[user_id]
            processing_buffer = session['processing_buffer']

        while len(processing_buffer) >= 1500: # 6秒窗口（1500点）
            raw_window = processing_buffer[:1500]
            processed_points, _ = preprocess3(raw_window, fs)
            processed_points = eog_removal(processed_points, 250, False)

            # theta_band = [4, 8]
            # beta_band = [13, 30]
            # tbr = compute_power_ratio(processed_points, fs, theta_band, beta_band)

            samp = SampEn_optimized(processed_points)
            tbr = samp[0][2]

            # tbr = 1

            # 如果不是日常在屏蔽间测数据，删掉下面的1==1
            if Step == '基准阶段' :
                tbr_list.append(tbr)
                session['tbr_base_list'].append(tbr)
                tbr_cumavg = np.mean(session['tbr_base_list'])
                session['Base_value'] = tbr_cumavg

            elif(Step == '治疗阶段') :
                #治疗阶段刚开始的时候，把上一次基准阶段的最终值记录下来
                if session['Base_flag'] == False:
                    with open(delta_file, 'a') as f:
                        f.write(f"{session['Base_value']}\n")
                        f.flush()
                    session['Base_flag'] = True
                with open(delta_file, 'a') as f:
                    f.write(f"{tbr}\n")
                    f.flush()

                tbr_list.append(tbr)

            # 更新绘图缓冲区
            processed_raw_buffer.extend(raw_window)
            processed_processed_buffer.extend(processed_points)

            # 移动窗口（0.5秒步长=125点）
            with session_lock:
                session['processing_buffer'] = processing_buffer[125:]
                processing_buffer = session['processing_buffer']


        return jsonify({
            "status": "success",
            "TBR": tbr_list
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


@app.route('/getHistoryDates', methods=['POST'])
def get_history_dates():
    """
    获取用户有历史记录的日期列表
    请求参数: { "userId": "用户openid" }
    返回: { "success": bool, "dates": [日期列表], "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400

        # 用户结果目录路径
        result_dir = os.path.join('data', user_id, 'result')

        # 确保目录存在
        if not os.path.exists(result_dir):
            return jsonify({"success": True, "dates": []})

        # 获取所有日期目录
        dates = []
        for date_dir in os.listdir(result_dir):
            if os.path.isdir(os.path.join(result_dir, date_dir)):
                try:
                    # 验证是否为有效日期格式 (YYYYMMDD)
                    datetime.datetime.strptime(date_dir, "%Y%m%d")
                    dates.append(date_dir)
                except ValueError:
                    continue

        # 按日期降序排序
        dates.sort(reverse=True)

        return jsonify({
            "success": True,
            "dates": dates
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/getHistoryFiles', methods=['POST'])
def get_history_files():
    """
    获取用户特定日期的历史文件列表
    请求参数: { "userId": "用户openid", "date": "YYYYMMDD" }
    返回: { "success": bool, "files": [文件名列表], "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')
        date = data.get('date')

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400
        if not date:
            return jsonify({"success": False, "error": "date is required"}), 400

        # 验证日期格式
        try:
            datetime.datetime.strptime(date, "%Y%m%d")
        except ValueError:
            return jsonify({"success": False, "error": "Invalid date format (should be YYYYMMDD)"}), 400

        # 用户结果目录路径
        result_dir = os.path.join('data', user_id, 'result', date)

        # 确保目录存在
        if not os.path.exists(result_dir):
            return jsonify({"success": True, "files": []})

        # 获取所有.txt文件并按修改时间排序(最新在前)
        files = []
        for f in os.listdir(result_dir):
            if f.endswith('.txt'):
                file_path = os.path.join(result_dir, f)
                files.append({
                    "name": f,
                    "path": file_path,
                    "mtime": os.path.getmtime(file_path)
                })

        # 按修改时间降序排序
        files.sort(key=lambda x: x['mtime'], reverse=True)

        return jsonify({
            "success": True,
            "files": [f["name"] for f in files]
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/getHistoryFile', methods=['POST'])
def get_history_file():
    """
    获取特定历史文件内容
    请求参数: { "userId": "用户openid", "date": "YYYYMMDD", "fileName": "文件名" }
    返回: { "success": bool, "data": [数值数组], "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')
        date = data.get('date')
        file_name = data.get('fileName')

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400
        if not date:
            return jsonify({"success": False, "error": "date is required"}), 400
        if not file_name:
            return jsonify({"success": False, "error": "fileName is required"}), 400

        # 安全检查
        if '../' in file_name or '..\\' in file_name:
            return jsonify({"success": False, "error": "Invalid file name"}), 400

        # 文件路径
        file_path = os.path.join('data', user_id, 'result', date, file_name)

        # 检查文件是否存在
        if not os.path.exists(file_path):
            return jsonify({"success": False, "error": "File not found"}), 404

        # 读取文件内容并解析为数值数组
        data_points = []
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        value = float(line)
                        data_points.append(value)
                    except ValueError:
                        print(f"Warning: 无法解析行内容: {line}")
                        continue

        if not data_points:
            return jsonify({"success": False, "error": "文件无有效数据"}), 400

        return jsonify({
            "success": True,
            "data": data_points
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

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
