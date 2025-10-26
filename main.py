import os
import sys
import json
from EntropyHub import SampEn
from SampEn import SampEn_optimized
from SingleDenoise import eog_removal
sys.path.append('D:\\anaconda\\lib\\site-packages')
import threading
import collections
from flask import Flask, request, jsonify
from flask_sock import Sock
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.animation import FuncAnimation
import datetime
import requests
from scipy.signal import spectrogram
from PreProcess import preprocess3,compute_power_ratio

app = Flask(__name__)
app.config['SECRET_KEY'] = 'adhd_eeg_secret_2024'
sock = Sock(app)

APPID = 'wx5a83526f8eca0449'
SECRET = '907a464400ff1dcf21c297019e543582'
fs = 250
user_sessions = {}
session_lock = threading.Lock()
processed_raw_buffer = collections.deque(maxlen=1500)
processed_processed_buffer = collections.deque(maxlen=1500)
hex_buffers = {}  # 每个用户的16进制字符串缓冲区
user_websockets = {}  # 用户ID到WebSocket连接的映射 {user_id: ws}


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
                'Base_flag': False,
                'feature_buffer': [],  # 缓存4个0.5s窗口的特征值
                'push_counter': 0      # 推送计数器
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

def decode_hex_data(hex_string, user_id):
    """
    解码16进制字符串为EEG数据点（支持跨批次的不完整数据包）
    
    逻辑：
    1. 每个数据包长度为10个字符（5字节）
    2. 数据包格式：头部2字符(11) + 数据6字符 + 尾部2字符(01)
    3. 头部必须是'11'，尾部必须是'01'
    4. 中间6个字符是24位有符号整数的16进制表示
    5. 转换公式：value = int(hex_str, 16) * 2.24 * 1000 / 8388608
    6. 如果值 >= 8388608 (0x800000)，需要减去 16777216 (0x1000000) 来得到负数
    
    参数：
        hex_string: 16进制字符串
        user_id: 用户ID，用于管理用户缓冲区
    
    返回：
        decoded_data: 解码后的数据点列表
        remaining_hex: 未处理完的16进制字符串（留给下次处理）
    """
    global hex_buffers
    
    # 从用户缓冲区获取上次未处理完的数据
    if user_id not in hex_buffers:
        hex_buffers[user_id] = ''
    
    # 拼接上次剩余的数据
    full_hex = hex_buffers[user_id] + hex_string
    
    decoded_data = []
    packet_length = 10
    i = 0
    
    while i + packet_length <= len(full_hex):
        # 检查数据包格式：头部'11'，尾部'01'
        if (full_hex[i:i+2] == '11' and 
            full_hex[i+8:i+10] == '01'):
            
            # 提取中间6个字符（24位数据）
            hex_value = full_hex[i+2:i+8]
            
            try:
                # 转换为整数
                value = int(hex_value, 16)
                
                # 处理有符号数（24位补码）
                if value >= 8388608:  # 0x800000，24位最高位为1表示负数
                    value -= 16777216  # 0x1000000，转换为负数
                
                # 应用转换公式
                value = value * 2.24 * 1000 / 8388608
                
                decoded_data.append(value)
                i += packet_length
            except ValueError:
                # 如果转换失败，移动一个字符继续
                i += 1
        else:
            # 格式不匹配，移动一个字符继续搜索
            i += 1
    
    # 保存剩余的未处理数据到缓冲区
    hex_buffers[user_id] = full_hex[i:]
    
    return decoded_data


@app.route('/process', methods=['POST'])
def process_data():
    data = request.json
    hex_data = data.get('hexData', '')  # 接收16进制字符串
    points = data.get('points', [])      # 兼容旧版本：直接接收解码后的数据
    user_id = data.get('userId')
    Step = data.get('Step')

    tbr_list = []
    
    # 如果接收到16进制数据，先解码
    if hex_data:
        points = decode_hex_data(hex_data, user_id)
    
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
        #print(len(processing_buffer))

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

            # ========== 所有阶段都缓存TBR并推送（每2秒推送一次平均值） ==========
            session['feature_buffer'].append(tbr)
            session['push_counter'] += 1
            
            # 每4个0.5s窗口（2秒）推送一次平均值
            if session['push_counter'] >= 4:
                avg_tbr = np.mean(session['feature_buffer'])
                
                # 治疗阶段：保存平均值到文件
                if Step == '治疗阶段':
                    # 治疗阶段开始时，保存后端计算的基准值到文件
                    if session['Base_flag'] == False:
                        with open(delta_file, 'a') as f:
                            f.write(f"{session['Base_value']}\n")
                            f.flush()
                        session['Base_flag'] = True
                    
                    # 保存平均值到文件（每2秒保存一次）
                    with open(delta_file, 'a') as f:
                        f.write(f"{avg_tbr}\n")
                        f.flush()
                
                # 推送给小程序（所有阶段）
                if user_id in user_websockets:
                    try:
                        ws = user_websockets[user_id]
                        message_data = {
                            'TBR': avg_tbr,
                            'timestamp': datetime.datetime.now().isoformat(),
                            'Step': Step
                        }
                        ws.send(json.dumps(message_data))
                        # 静默推送，不打印日志（避免刷屏）
                    except Exception as e:
                        print(f'[推送] ❌ 推送失败: {e}')
                        # 推送失败，可能连接已断开，从字典中删除
                        if user_id in user_websockets:
                            del user_websockets[user_id]
                            print(f'[推送] 🔌 用户 {user_id} 连接已失效，已移除')
                else:
                    # 只在首次发现用户未注册时打印警告
                    if not hasattr(session, '_warned_unregistered'):
                        print(f'[推送] ⚠️ 用户 {user_id} 不在已注册列表中，无法推送TBR')
                        print(f'[推送] 📊 当前已注册用户: {list(user_websockets.keys())}')
                        session['_warned_unregistered'] = True
                
                # 清空缓冲区和计数器
                session['feature_buffer'] = []
                session['push_counter'] = 0
            # ========== 推送逻辑结束 ==========

            # 后端负责：累积计算基准值（用于保存）
            # 小程序负责：收集推送的样本熵，游戏开始时自己计算基准值
            if Step == '基准阶段' :
                tbr_list.append(tbr)
                
                # 后端累积计算基准值（用于保存到文件）
                session['tbr_base_list'].append(tbr)
                tbr_cumavg = np.mean(session['tbr_base_list'])
                session['Base_value'] = tbr_cumavg

            elif Step == '治疗阶段' :
                tbr_list.append(tbr)

            # 更新绘图缓冲区
            processed_raw_buffer.extend(raw_window)
            processed_processed_buffer.extend(processed_points)

            # 移动窗口（0.5秒步长=125点）
            with session_lock:
                session['processing_buffer'] = processing_buffer[125:]
                processing_buffer = session['processing_buffer']


        # 不再返回TBR列表，改为通过WebSocket推送
        return jsonify({
            "status": "success",
            "message": "Data received and processing"
        })


# ========== 原生WebSocket连接处理（flask-sock）==========

@sock.route('/ws')
def websocket(ws):
    """处理微信小程序的原生WebSocket连接"""
    user_id = None
    print('='*50)
    print('[WebSocket] 🔌 新连接建立')
    print('='*50)
    
    try:
        while True:
            # 接收消息
            message = ws.receive()
            if message is None:
                print('[WebSocket] ⚠️ 收到空消息，连接可能已断开')
                break
            
            # 只打印非心跳消息
            try:
                data = json.loads(message)
                event = data.get('event')
                
                # 心跳消息不打印
                if event != 'ping':
                    print(f'[WebSocket] 📩 收到消息: {message}')
                
                if event == 'register_user':
                    # 用户注册
                    user_id = data.get('userId')
                    if user_id:
                        # 如果用户已存在（重连），先删除旧连接
                        if user_id in user_websockets:
                            print(f'[WebSocket] 🔄 用户 {user_id} 重新连接，更新WebSocket对象')
                        
                        user_websockets[user_id] = ws
                        print(f'[WebSocket] ✅ 用户 {user_id} 注册成功')
                        print(f'[WebSocket] 📊 当前已注册用户: {list(user_websockets.keys())}')
                        
                        # 检查用户是否有活跃的session
                        has_session = user_id in user_sessions
                        print(f'[WebSocket] 📋 用户 {user_id} 是否有活跃session: {has_session}')
                        
                        ws.send(json.dumps({
                            'event': 'registered',
                            'message': f'用户 {user_id} 注册成功',
                            'userId': user_id,
                            'hasSession': has_session
                        }))
                        
                        # 如果没有session，提示需要发送数据
                        if not has_session:
                            print(f'[WebSocket] ⚠️ 用户 {user_id} 没有活跃session，需要开始发送数据才能接收TBR推送')
                        else:
                            print(f'[WebSocket] ✅ 用户 {user_id} 有活跃session，等待数据处理后推送TBR')
                
                elif event == 'ping':
                    # 心跳响应（静默处理，不打印日志）
                    ws.send(json.dumps({'event': 'pong', 'message': 'pong'}))
                    
                elif event == 'unregister_user':
                    # 用户注销
                    user_id = data.get('userId')
                    if user_id and user_id in user_websockets:
                        del user_websockets[user_id]
                        print(f'[WebSocket] 👋 用户 {user_id} 已注销')
                        ws.send(json.dumps({
                            'event': 'unregistered',
                            'message': f'用户 {user_id} 已注销'
                        }))
                
            except json.JSONDecodeError as e:
                print(f'[WebSocket] ❌ 消息格式错误: {e}')
                ws.send(json.dumps({'error': '消息格式错误'}))
    
    except Exception as e:
        print(f'[WebSocket] ❌ 连接异常: {e}')
        import traceback
        traceback.print_exc()
    
    finally:
        # 连接断开，清理用户注册信息
        if user_id and user_id in user_websockets:
            del user_websockets[user_id]
            print(f'[WebSocket] 🔌 用户 {user_id} 连接断开')
            print(f'[WebSocket] 📊 剩余用户: {list(user_websockets.keys())}')
        else:
            print('[WebSocket] 🔌 连接断开（未注册用户）')

# ========================================

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
    """运行Flask服务器"""
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
    获取特定历史文件内容（特征数据，从result目录）
    请求参数: { "userId": "用户openid", "date": "YYYYMMDD", "fileName": "文件名" }
    返回: { "success": bool, "data": [数值数组], "baseline": 基准值, "error": "错误信息" }
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

        # 第一个值是基准值，其余是治疗阶段数据
        baseline = data_points[0] if len(data_points) > 0 else None
        treatment_data = data_points[1:] if len(data_points) > 1 else []

        return jsonify({
            "success": True,
            "data": treatment_data,
            "baseline": baseline,
            "totalPoints": len(treatment_data)
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/getRawHistoryDates', methods=['POST'])
def get_raw_history_dates():
    """
    获取用户有原始信号记录的日期列表
    请求参数: { "userId": "用户openid" }
    返回: { "success": bool, "dates": [日期列表], "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400

        # 用户原始数据目录路径
        data_dir = os.path.join('data', user_id, 'data')

        # 确保目录存在
        if not os.path.exists(data_dir):
            return jsonify({"success": True, "dates": []})

        # 获取所有日期目录
        dates = []
        for date_dir in os.listdir(data_dir):
            if os.path.isdir(os.path.join(data_dir, date_dir)):
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

@app.route('/getRawHistoryFiles', methods=['POST'])
def get_raw_history_files():
    """
    获取用户特定日期的原始信号文件列表
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

        # 用户原始数据目录路径
        data_dir = os.path.join('data', user_id, 'data', date)

        # 确保目录存在
        if not os.path.exists(data_dir):
            return jsonify({"success": True, "files": []})

        # 获取所有raw_开头的.txt文件并按修改时间排序(最新在前)
        files = []
        for f in os.listdir(data_dir):
            if f.startswith('raw_') and f.endswith('.txt'):
                file_path = os.path.join(data_dir, f)
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

@app.route('/getRawHistoryFile', methods=['POST'])
def get_raw_history_file():
    """
    获取特定原始信号文件内容
    请求参数: { "userId": "用户openid", "date": "YYYYMMDD", "fileName": "文件名", "start": 起始索引, "count": 数据点数量 }
    返回: { "success": bool, "data": [数值数组], "totalPoints": 总数据点数, "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')
        date = data.get('date')
        file_name = data.get('fileName')
        start = data.get('start', 0)  # 起始索引，默认0
        count = data.get('count', 10000)  # 一次读取的数据点数，默认10000

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400
        if not date:
            return jsonify({"success": False, "error": "date is required"}), 400
        if not file_name:
            return jsonify({"success": False, "error": "fileName is required"}), 400

        # 安全检查
        if '../' in file_name or '..\\' in file_name:
            return jsonify({"success": False, "error": "Invalid file name"}), 400
        if not file_name.startswith('raw_'):
            return jsonify({"success": False, "error": "Invalid raw file name"}), 400

        # 文件路径
        file_path = os.path.join('data', user_id, 'data', date, file_name)

        # 检查文件是否存在
        if not os.path.exists(file_path):
            return jsonify({"success": False, "error": "File not found"}), 404

        # 读取文件内容并解析为数值数组
        all_data = []
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        value = float(line)
                        all_data.append(value)
                    except ValueError:
                        continue

        if not all_data:
            return jsonify({"success": False, "error": "文件无有效数据"}), 400

        total_points = len(all_data)
        
        # 根据start和count截取数据
        end = min(start + count, total_points)
        data_slice = all_data[start:end]

        return jsonify({
            "success": True,
            "data": data_slice,
            "totalPoints": total_points,
            "start": start,
            "end": end
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/saveGameRecord', methods=['POST'])
def save_game_record():
    """
    保存游戏时长记录
    请求参数: { "userId": "用户openid", "gameTime": 游戏时长(秒) }
    返回: { "success": bool, "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')
        game_time = data.get('gameTime')

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400
        if game_time is None:
            return jsonify({"success": False, "error": "gameTime is required"}), 400

        # 确保game_time是整数
        try:
            game_time = int(game_time)
        except (ValueError, TypeError):
            return jsonify({"success": False, "error": "gameTime must be an integer"}), 400

        # 获取当前日期和时间
        now = datetime.datetime.now()
        date_str = now.strftime("%Y%m%d")
        timestamp = now.strftime("%Y-%m-%d %H:%M:%S")

        # 游戏记录目录路径
        records_dir = os.path.join('data', user_id, 'game_records')
        os.makedirs(records_dir, exist_ok=True)

        # 记录文件路径（按日期命名）
        record_file = os.path.join(records_dir, f"{date_str}.txt")

        # 追加记录（格式：时间戳,游戏时长）
        with open(record_file, 'a', encoding='utf-8') as f:
            f.write(f"{timestamp},{game_time}\n")

        print(f"[游戏记录] 用户 {user_id} 游戏时长 {game_time}秒 已保存")

        return jsonify({"success": True})

    except Exception as e:
        print(f"[游戏记录错误] {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

def analyze_training_trend(records):
    """
    分析训练历史趋势并给出建议
    返回: {
        "trend": "improving/stable/declining", 
        "suggestion": "建议文本",
        "stats": {...}
    }
    """
    if not records or len(records) == 0:
        return {
            "trend": "no_data",
            "suggestion": "暂无训练数据，开始您的第一次训练吧！",
            "stats": {}
        }
    
    game_times = [r['gameTime'] for r in records]
    total_games = len(game_times)
    
    # 基础统计
    avg_time = sum(game_times) / total_games
    max_time = max(game_times)
    min_time = min(game_times)
    
    stats = {
        "totalGames": total_games,
        "avgTime": round(avg_time, 1),
        "maxTime": max_time,
        "minTime": min_time
    }
    
    # 数据不足，无法分析趋势
    if total_games < 3:
        return {
            "trend": "insufficient",
            "suggestion": f"已完成{total_games}次训练，继续加油！建议至少完成5次训练后查看趋势分析。",
            "stats": stats
        }
    
    # 计算趋势：使用线性回归斜率
    # y = game_time, x = game_index
    n = len(game_times)
    x = list(range(n))
    y = game_times
    
    # 计算线性回归斜率
    x_mean = sum(x) / n
    y_mean = sum(y) / n
    
    numerator = sum((x[i] - x_mean) * (y[i] - y_mean) for i in range(n))
    denominator = sum((x[i] - x_mean) ** 2 for i in range(n))
    
    slope = numerator / denominator if denominator != 0 else 0
    
    # 计算最近5次与整体平均的对比
    recent_count = min(5, total_games)
    recent_avg = sum(game_times[-recent_count:]) / recent_count
    improvement_rate = ((recent_avg - avg_time) / avg_time * 100) if avg_time > 0 else 0
    
    # 计算稳定性（变异系数）
    std_dev = (sum((t - avg_time) ** 2 for t in game_times) / total_games) ** 0.5
    cv = (std_dev / avg_time * 100) if avg_time > 0 else 0  # 变异系数
    
    # 判断趋势
    trend = "stable"
    suggestion = ""
    
    # 斜率阈值：每次提升超过1秒为明显进步
    if slope > 1.0 and improvement_rate > 10:
        trend = "improving"
        if cv < 20:
            suggestion = f"🎉 太棒了！您的专注时间持续提升，最近表现比平均水平高{abs(improvement_rate):.1f}%！而且表现很稳定。继续保持这个节奏，建议每天训练1-2次。"
        else:
            suggestion = f"📈 很好！您的专注时间在提升，最近表现比平均水平高{abs(improvement_rate):.1f}%。不过波动较大，建议保持规律的训练时间，避免过度疲劳。"
    
    elif slope < -1.0 and improvement_rate < -10:
        trend = "declining"
        if total_games < 10:
            suggestion = f"💪 前期适应很正常！您的专注时间暂时下降了{abs(improvement_rate):.1f}%，但这可能是在寻找最适合自己的节奏。建议：①确保训练环境安静 ②每次训练前做深呼吸放松 ③尝试不同时段找到最佳状态。"
        else:
            suggestion = f"⚠️ 注意：最近的专注时间下降了{abs(improvement_rate):.1f}%。可能原因：①训练疲劳 ②注意力分散 ③压力过大。建议：①适当休息1-2天 ②调整训练时间到精力充沛时段 ③减少训练难度，重建信心。"
    
    else:
        # 稳定状态
        if cv < 15:
            if avg_time > 60:
                suggestion = f"✨ 非常好！您的专注时间稳定在{avg_time:.0f}秒左右，表现很稳定（波动小于15%）。您已经建立了良好的专注力基础。下一步建议：①尝试增加难度 ②延长训练时间 ③设定新的挑战目标。"
            else:
                suggestion = f"📊 表现稳定，平均专注时间{avg_time:.0f}秒，波动较小。继续保持规律训练，您的专注力正在稳步提升。建议每次训练后记录感受，找到最佳状态。"
        else:
            suggestion = f"📊 您的平均专注时间是{avg_time:.0f}秒，但波动较大（变异系数{cv:.1f}%）。建议：①固定每天训练时间 ②保持训练环境一致 ③训练前做5分钟冥想放松 ④避免在疲劳或情绪不佳时训练。"
    
    # 添加通用建议
    if total_games >= 20:
        if max_time > avg_time * 1.5:
            suggestion += f"\n\n💡 您的最佳记录是{max_time}秒，说明您有很大潜力。试着回忆那次的状态和条件，复制成功经验！"
    
    if total_games >= 30:
        suggestion += f"\n\n🏆 已完成{total_games}次训练，您的坚持非常值得称赞！长期训练对ADHD改善效果显著，建议继续保持。"
    
    stats.update({
        "slope": round(slope, 2),
        "improvementRate": round(improvement_rate, 1),
        "stability": round(100 - cv, 1),  # 稳定性百分比
        "recentAvg": round(recent_avg, 1)
    })
    
    return {
        "trend": trend,
        "suggestion": suggestion,
        "stats": stats
    }

@app.route('/getGameRecords', methods=['POST'])
def get_game_records():
    """
    获取游戏时长记录
    请求参数: { "userId": "用户openid", "date": "YYYYMMDD" (可选,不提供则返回所有记录) }
    返回: { "success": bool, "records": [{"date": "日期", "time": "时间", "gameTime": 时长}], "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')
        target_date = data.get('date')  # 可选参数

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400

        # 游戏记录目录路径
        records_dir = os.path.join('data', user_id, 'game_records')

        if not os.path.exists(records_dir):
            return jsonify({"success": True, "records": []})

        records = []

        # 如果指定了日期，只读取该日期的文件
        if target_date:
            try:
                datetime.datetime.strptime(target_date, "%Y%m%d")
            except ValueError:
                return jsonify({"success": False, "error": "Invalid date format (should be YYYYMMDD)"}), 400

            record_file = os.path.join(records_dir, f"{target_date}.txt")
            if os.path.exists(record_file):
                with open(record_file, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if ',' in line:
                            timestamp, game_time = line.split(',', 1)
                            try:
                                records.append({
                                    "timestamp": timestamp,
                                    "gameTime": int(game_time)
                                })
                            except ValueError:
                                continue
        else:
            # 读取所有日期的记录文件
            for filename in sorted(os.listdir(records_dir)):
                if filename.endswith('.txt'):
                    record_file = os.path.join(records_dir, filename)
                    with open(record_file, 'r', encoding='utf-8') as f:
                        for line in f:
                            line = line.strip()
                            if ',' in line:
                                timestamp, game_time = line.split(',', 1)
                                try:
                                    records.append({
                                        "timestamp": timestamp,
                                        "gameTime": int(game_time)
                                    })
                                except ValueError:
                                    continue

        # 按时间戳排序
        records.sort(key=lambda x: x['timestamp'])

        # 计算趋势分析和建议
        analysis = analyze_training_trend(records)

        return jsonify({
            "success": True,
            "records": records,
            "analysis": analysis
        })

    except Exception as e:
        print(f"[获取游戏记录错误] {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/saveSchulteRecord', methods=['POST'])
def save_schulte_record():
    """
    保存舒尔特方格训练记录
    """
    try:
        data = request.get_json()
        user_id = data.get('userId', 'user001')
        difficulty = data.get('difficulty', '5x5')  # 5x5, 6x6, 7x7
        time = data.get('time', 0)  # 完成用时（秒）
        
        if time <= 0:
            return jsonify({"success": False, "error": "无效的用时"}), 400
        
        # 舒尔特方格记录目录路径（按用户和难度分类）
        records_dir = os.path.join('data', user_id, 'schulte_records', difficulty)
        os.makedirs(records_dir, exist_ok=True)
        
        # 获取当前日期
        current_time = datetime.datetime.now()
        date_str = current_time.strftime("%Y-%m-%d")
        timestamp = current_time.strftime("%Y-%m-%d %H:%M:%S")
        
        # 记录文件路径（按日期命名）
        record_file = os.path.join(records_dir, f"{date_str}.txt")
        
        # 追加记录（格式：时间戳,用时）
        with open(record_file, 'a', encoding='utf-8') as f:
            f.write(f"{timestamp},{time}\n")
        
        print(f"[舒尔特记录] 用户 {user_id} 难度 {difficulty} 用时 {time}秒 已保存")
        return jsonify({"success": True})
        
    except Exception as e:
        print(f"[舒尔特记录错误] {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/getSchulteRecords', methods=['GET'])
def get_schulte_records():
    """
    获取舒尔特方格训练记录
    """
    try:
        user_id = request.args.get('userId', 'user001')
        difficulty = request.args.get('difficulty', '5x5')
        
        # 舒尔特方格记录目录路径
        records_dir = os.path.join('data', user_id, 'schulte_records', difficulty)
        
        if not os.path.exists(records_dir):
            return jsonify({
                "success": True,
                "records": [],
                "stats": {
                    "bestTime": 0,
                    "avgTime": 0,
                    "totalGames": 0
                }
            })
        
        # 读取所有记录文件
        all_records = []
        for filename in os.listdir(records_dir):
            if filename.endswith('.txt'):
                file_path = os.path.join(records_dir, filename)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        for line in f:
                            line = line.strip()
                            if line:
                                parts = line.split(',')
                                if len(parts) >= 2:
                                    timestamp = parts[0]
                                    time_value = float(parts[1])
                                    all_records.append({
                                        "timestamp": timestamp,
                                        "time": time_value,
                                        "date": timestamp.split()[0]
                                    })
                except Exception as e:
                    print(f"[读取文件错误] {filename}: {e}")
                    continue
        
        # 按时间戳排序（最新的在前）
        all_records.sort(key=lambda x: x['timestamp'], reverse=True)
        
        # 计算统计数据
        stats = {
            "bestTime": 0,
            "avgTime": 0,
            "totalGames": 0
        }
        
        if all_records:
            times = [r['time'] for r in all_records]
            stats['bestTime'] = min(times)
            stats['avgTime'] = sum(times) / len(times)
            stats['totalGames'] = len(times)
        
        return jsonify({
            "success": True,
            "records": all_records[:50],  # 返回最近50条记录
            "stats": stats
        })

    except Exception as e:
        print(f"[获取舒尔特记录错误] {e}")
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
