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
from feature_calculator import calculate_features, calculate_realtime_feature
# from openai import OpenAI
from simple_websocket import ConnectionClosed

app = Flask(__name__)
app.config['SECRET_KEY'] = 'adhd_eeg_secret_2024'
sock = Sock(app)

APPID = 'wx5a83526f8eca0449'
SECRET = '907a464400ff1dcf21c297019e543582'
fs = 250


# 初始化阿里云百炼大模型客户端，优先用环境变量 DASHSCOPE_API_KEY
# import os
# ai_client = OpenAI(
#     api_key=os.getenv("DASHSCOPE_API_KEY", "sk-341c8f4ad671494c84d12201dc2737cf"),
#     base_url="https://dashscope.aliyuncs.com/compatible-mode/v1"
# )

user_sessions = {}
session_lock = threading.Lock()
processed_raw_buffer = collections.deque(maxlen=1500)
processed_processed_buffer = collections.deque(maxlen=1500)
hex_buffers = {}  # 每个用户的16进制字符串缓冲区
user_websockets = {}  # 用户ID到WebSocket连接的映射 {user_id: ws}


def process_calibration_data(user_id, trials):
    """
    处理离线实验标定数据，判断用户类型
    
    参数:
        user_id: 用户ID
        trials: 实验数据列表，每个trial包含restingData和attentionData
    
    返回:
        {
            'success': bool,
            'user_type': 'type_A' or 'type_B',
            'resting_mean': float,
            'attention_mean': float,
            'description': str
        }
    """
    try:
        print(f'[标定] 开始处理用户 {user_id} 的标定数据，共 {len(trials)} 次实验')
        
        # 收集所有静息和注意力阶段的特征值
        all_resting_features = []
        all_attention_features = []
        
        for i, trial in enumerate(trials):
            print(f'[标定] 处理第 {i+1} 次实验')
            
            resting_data = trial.get('restingData', [[]])[0]  # 获取第一个元素（数据列表）
            attention_data = trial.get('attentionData', [[]])[0]
            
            # 计算静息阶段的特征（这里使用样本熵作为示例）
            if len(resting_data) > 0:
                # 假设数据是原始EEG值，需要先预处理
                # 这里简化处理，实际应该调用你的预处理函数
                try:
                    # 计算样本熵（可以根据实际情况调整参数）
                    resting_sampen = calculate_sampen_from_raw(resting_data)
                    all_resting_features.append(resting_sampen)
                    print(f'[标定] 实验{i+1} 静息样本熵: {resting_sampen:.4f}')
                except Exception as e:
                    print(f'[标定] 实验{i+1} 静息数据处理失败: {e}')
            
            # 计算注意力阶段的特征
            if len(attention_data) > 0:
                try:
                    attention_sampen = calculate_sampen_from_raw(attention_data)
                    all_attention_features.append(attention_sampen)
                    print(f'[标定] 实验{i+1} 注意力样本熵: {attention_sampen:.4f}')
                except Exception as e:
                    print(f'[标定] 实验{i+1} 注意力数据处理失败: {e}')
        
        # 检查是否有足够的数据
        if len(all_resting_features) < 2 or len(all_attention_features) < 2:
            return {
                'success': False,
                'message': f'数据不足，需要至少2次有效实验。当前静息: {len(all_resting_features)}, 注意力: {len(all_attention_features)}'
            }
        
        # 计算均值
        resting_mean = np.mean(all_resting_features)
        attention_mean = np.mean(all_attention_features)
        
        print(f'[标定] 静息均值: {resting_mean:.4f}, 注意力均值: {attention_mean:.4f}')
        
        # 判断用户类型
        if resting_mean > attention_mean:
            user_type = 'type_A'
            description = '静息时样本熵 > 注意力时样本熵'
        else:
            user_type = 'type_B'
            description = '静息时样本熵 < 注意力时样本熵'
        
        print(f'[标定] 用户类型: {user_type} ({description})')
        
        return {
            'success': True,
            'user_type': user_type,
            'resting_mean': float(resting_mean),
            'attention_mean': float(attention_mean),
            'description': description,
            'resting_features': [float(f) for f in all_resting_features],
            'attention_features': [float(f) for f in all_attention_features]
        }
        
    except Exception as e:
        print(f'[标定] 处理失败: {e}')
        import traceback
        traceback.print_exc()
        return {
            'success': False,
            'message': str(e)
        }


def calculate_sampen_from_raw(raw_data):
    """
    从原始数据计算特征（使用全局特征计算模块）
    
    参数:
        raw_data: 原始EEG数据列表（16进制字符串或数值）
    
    返回:
        特征值
    """
    # 如果数据是16进制字符串列表，需要先转换
    if isinstance(raw_data[0], str):
        # 转换16进制字符串为整数
        eeg_values = []
        for hex_str in raw_data:
            try:
                # 假设每10个字符是一个数据包
                for i in range(0, len(hex_str), 10):
                    packet = hex_str[i:i+10]
                    if len(packet) == 10:
                        # 提取EEG值（根据你的数据格式调整）
                        eeg_hex = packet[0:6]
                        value = int(eeg_hex, 16)
                        # 转换为有符号数
                        if value > 0x7FFFFF:
                            value -= 0x1000000
                        eeg_values.append(value)
            except Exception as e:
                continue
    else:
        eeg_values = raw_data
    
    # 预处理：去除基线漂移等
    if len(eeg_values) > 100:
        eeg_array = np.array(eeg_values, dtype=float)
        
        # 简单的去均值处理
        eeg_array = eeg_array - np.mean(eeg_array)
        
        # 使用统一的特征计算接口
        try:
            feature_value = calculate_features(eeg_array, fs=250)
            return feature_value
        except Exception as e:
            print(f'[特征计算] 计算失败: {e}')
            # 降级使用简单统计特征
            return np.std(eeg_array)
    else:
        return 0.0


def get_user_session(user_id):
    current_time = datetime.datetime.now()
    date_str = current_time.strftime("%Y%m%d")  # 按日期组织数据

    # 创建按日期组织的目录结构 - 统一使用 eeg_data 和 eeg_results
    user_dir = os.path.join('data', user_id, 'eeg_data', date_str)
    result_dir = os.path.join('data', user_id, 'eeg_results', date_str)

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
                'push_counter': 0,     # 推送计数器
                'difficulty_saved': False,  # 难度信息保存标志
                'recording': False,  # 数据记录控制标志
                'recording_started': False  # 是否已经开始过记录（用于创建新文件）
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
    difficulty = data.get('difficulty', 'normal')  # 接收难度信息，默认为normal

    tbr_list = []
    
    # 如果接收到16进制数据，先解码
    if hex_data:
        points = decode_hex_data(hex_data, user_id)
    
    # delta_cumavg_list = []

    if not user_id:
        return jsonify({"error": "userId is required"}), 400

    raw_file, processed_file,delta_file= get_user_session(user_id)
    
    # 保存难度信息到difficulty.json（仅在治疗阶段开始时保存一次）
    if Step == '治疗阶段':
        with session_lock:
            session = user_sessions[user_id]
            if not session.get('difficulty_saved', False):
                # 获取结果目录路径
                result_dir = os.path.dirname(delta_file)
                difficulty_file = os.path.join(result_dir, 'difficulty.json')
                
                # 读取现有的难度信息
                difficulties = {}
                if os.path.exists(difficulty_file):
                    try:
                        with open(difficulty_file, 'r', encoding='utf-8') as f:
                            difficulties = json.load(f)
                    except Exception as e:
                        print(f"[难度信息] 读取失败: {e}")
                
                # 添加当前文件的难度信息
                file_name = os.path.basename(delta_file)
                difficulties[file_name] = difficulty
                
                # 保存难度信息
                try:
                    with open(difficulty_file, 'w', encoding='utf-8') as f:
                        json.dump(difficulties, f, ensure_ascii=False, indent=2)
                    print(f"[难度信息] 保存成功: {file_name} -> {difficulty}")
                except Exception as e:
                    print(f"[难度信息] 保存失败: {e}")
                
                session['difficulty_saved'] = True

    # if Step == '基准阶段' or Step == '治疗阶段':
    if True:
        with session_lock:
            session = user_sessions[user_id]
            session['processing_buffer'].extend(points)

        # 只有在recording为True时才保存原始数据到文件
        with session_lock:
            session = user_sessions[user_id]
            is_recording = session.get('recording', False)
            is_calibration_recording = session.get('calibration_recording', False)
            calibration_raw_file = session.get('calibration_raw_file')
        
        if is_recording:
            with open(raw_file, 'a') as f:
                for p in points:
                    f.write(f"{p}\n")
                f.flush()
        
        # 离线实验期间同时写入离线实验文件（与塔防游戏一样，写入转换后的数据）
        if is_calibration_recording and calibration_raw_file:
            with open(calibration_raw_file, 'a') as f:
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
                    
                elif event == 'start_recording':
                    # 开始记录数据
                    user_id = data.get('userId')
                    if user_id:
                        with session_lock:
                            if user_id in user_sessions:
                                session = user_sessions[user_id]
                                # 如果是第一次开始记录，创建新文件
                                if not session.get('recording_started', False):
                                    current_time = datetime.datetime.now()
                                    date_str = current_time.strftime("%Y%m%d")
                                    timestamp = current_time.strftime("%H%M%S_%f")[:-3]
                                    
                                    user_dir = os.path.join('data', user_id, 'eeg_data', date_str)
                                    result_dir = os.path.join('data', user_id, 'eeg_results', date_str)
                                    os.makedirs(user_dir, exist_ok=True)
                                    os.makedirs(result_dir, exist_ok=True)
                                    
                                    session['raw_file'] = os.path.join(user_dir, f"raw_{timestamp}.txt")
                                    session['Delta_result'] = os.path.join(result_dir, f"{timestamp}.txt")
                                    session['processed_file'] = os.path.join(user_dir, f"processed_{timestamp}.txt")
                                    session['recording_started'] = True
                                
                                session['recording'] = True
                                print(f'[WebSocket] 🔴 用户 {user_id} 开始记录数据 -> {session["raw_file"]}')
                                ws.send(json.dumps({
                                    'event': 'recording_started',
                                    'message': '开始记录数据',
                                    'userId': user_id
                                }))
                            else:
                                print(f'[WebSocket] ⚠️ 用户 {user_id} 没有活跃session，无法开始记录')
                                ws.send(json.dumps({
                                    'event': 'error',
                                    'message': '没有活跃session'
                                }))
                    
                elif event == 'stop_recording':
                    # 停止记录数据
                    user_id = data.get('userId')
                    if user_id:
                        with session_lock:
                            if user_id in user_sessions:
                                session = user_sessions[user_id]
                                session['recording'] = False
                                session['recording_started'] = False  # 重置标志，下次开始时创建新文件
                                print(f'[WebSocket] ⏹️ 用户 {user_id} 停止记录数据')
                                ws.send(json.dumps({
                                    'event': 'recording_stopped',
                                    'message': '停止记录数据',
                                    'userId': user_id
                                }))
                            else:
                                print(f'[WebSocket] ⚠️ 用户 {user_id} 没有活跃session')
                
                elif event == 'start_calibration_recording':
                    # 开始离线实验数据记录（学习塔防游戏的方式）
                    user_id = data.get('userId')
                    trial_number = data.get('trialNumber', 1)
                    if user_id:
                        with session_lock:
                            if user_id in user_sessions:
                                session = user_sessions[user_id]
                                current_time = datetime.datetime.now()
                                timestamp = current_time.strftime("%Y%m%d_%H%M%S")
                                
                                # 创建离线实验目录
                                calibration_dir = os.path.join('data', user_id, 'calibration', f'trial_{trial_number}')
                                os.makedirs(calibration_dir, exist_ok=True)
                                
                                session['calibration_raw_file'] = os.path.join(calibration_dir, f"raw_{timestamp}.txt")
                                session['calibration_trial'] = trial_number
                                session['calibration_recording'] = True
                                
                                print(f'[WebSocket] 🔴 离线实验{trial_number} 开始记录 -> {session["calibration_raw_file"]}')
                                ws.send(json.dumps({
                                    'event': 'calibration_recording_started',
                                    'message': f'离线实验{trial_number}开始记录',
                                    'userId': user_id
                                }))
                
                elif event == 'stop_calibration_recording':
                    # 停止离线实验数据记录并触发处理
                    user_id = data.get('userId')
                    trial_number = data.get('trialNumber', 1)
                    if user_id:
                        with session_lock:
                            if user_id in user_sessions:
                                session = user_sessions[user_id]
                                session['calibration_recording'] = False
                                raw_file = session.get('calibration_raw_file')
                                
                                print(f'[WebSocket] ⏹️ 离线实验{trial_number} 停止记录')
                                
                                # 异步处理数据
                                def process_async():
                                    from calibration_processor import process_calibration_trial, analyze_all_trials
                                    
                                    if raw_file and os.path.exists(raw_file):
                                        result = process_calibration_trial(raw_file, user_id, trial_number, fs=250)
                                        
                                        if result['success']:
                                            print(f'[离线实验] ✅ 第{trial_number}次实验处理完成')
                                            
                                            # 检查是否所有实验都完成
                                            features_files = [
                                                os.path.join('data', user_id, 'calibration', f'trial_{i}_features.json')
                                                for i in range(1, 3)
                                            ]
                                            
                                            if all(os.path.exists(f) for f in features_files):
                                                print(f'[离线实验] 🎯 所有实验完成，开始最终分析...')
                                                final_result = analyze_all_trials(user_id, num_trials=2)
                                                
                                                if final_result['success']:
                                                    result_file = os.path.join('data', user_id, 'calibration', 'calibration_result.json')
                                                    with open(result_file, 'w', encoding='utf-8') as f:
                                                        json.dump(final_result, f, ensure_ascii=False, indent=2)
                                                    print(f'[离线实验] ✅ 用户{user_id}标定完成: {final_result["user_type"]}')
                                
                                threading.Thread(target=process_async).start()
                                
                                ws.send(json.dumps({
                                    'event': 'calibration_recording_stopped',
                                    'message': f'离线实验{trial_number}停止记录，开始处理',
                                    'userId': user_id
                                }))
                    
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
                
                elif event == 'submit_calibration':
                    # 接收离线实验标定数据并进行分类
                    print('[WebSocket] 🎯 收到离线实验标定数据')
                    user_id = data.get('user_id')
                    trials = data.get('trials', [])
                    
                    if not user_id or not trials:
                        ws.send(json.dumps({
                            'type': 'error',
                            'message': '缺少必要参数'
                        }))
                    else:
                        # 调用标定数据处理函数
                        result = process_calibration_data(user_id, trials)
                        
                        if result['success']:
                            # 保存标定结果
                            calibration_dir = os.path.join('data', user_id, 'calibration')
                            os.makedirs(calibration_dir, exist_ok=True)
                            
                            result_file = os.path.join(calibration_dir, 'calibration_result.json')
                            with open(result_file, 'w', encoding='utf-8') as f:
                                json.dump(result, f, ensure_ascii=False, indent=2)
                            
                            print(f'[WebSocket] ✅ 用户 {user_id} 标定完成: {result["user_type"]}')
                            
                            # 发送结果到小程序
                            ws.send(json.dumps({
                                'type': 'calibration_result',
                                'data': {
                                    'user_type': result['user_type'],
                                    'resting_mean': result['resting_mean'],
                                    'attention_mean': result['attention_mean'],
                                    'description': result.get('description', '')
                                }
                            }))
                        else:
                            ws.send(json.dumps({
                                'type': 'error',
                                'message': result.get('message', '标定数据处理失败')
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

@app.route('/upload_calibration_data', methods=['POST'])
def upload_calibration_data():
    """
    接收离线实验数据并处理
    """
    try:
        data = request.json
        user_id = data.get('user_id')
        trial_number = data.get('trial_number', 1)
        eeg_data = data.get('eeg_data', [])  # 80秒的EEG数据数组
        
        if not user_id or not eeg_data:
            return jsonify({'success': False, 'message': '缺少必要参数'}), 400
        
        print(f'[离线实验] 收到用户 {user_id} 第 {trial_number} 次实验数据，共 {len(eeg_data)} 个点')
        
        # 创建目录
        calibration_dir = os.path.join('data', user_id, 'calibration', f'trial_{trial_number}')
        os.makedirs(calibration_dir, exist_ok=True)
        
        # 保存原始数据
        current_time = datetime.datetime.now()
        timestamp = current_time.strftime("%Y%m%d_%H%M%S")
        raw_file = os.path.join(calibration_dir, f'raw_{timestamp}.txt')
        
        with open(raw_file, 'w') as f:
            for value in eeg_data:
                f.write(f'{value}\n')
        
        print(f'[离线实验] 数据已保存到: {raw_file}')
        
        # 启动后台处理
        def process_async():
            from calibration_processor import process_calibration_trial, analyze_all_trials
            
            # 处理单次实验
            result = process_calibration_trial(raw_file, user_id, trial_number, fs=250)
            
            if result['success']:
                print(f'[离线实验] ✅ 第 {trial_number} 次实验处理完成')
                print(f'[离线实验] 📁 数据保存位置: data/{user_id}/calibration/')
                
                # 检查是否所有实验都完成（假设需要2次）
                features_files = [
                    os.path.join('data', user_id, 'calibration', f'trial_{i}_features.json')
                    for i in range(1, 3)
                ]
                
                if all(os.path.exists(f) for f in features_files):
                    print(f'[离线实验] 🎯 所有实验完成，开始最终分析...')
                    
                    # 分析所有实验
                    final_result = analyze_all_trials(user_id, num_trials=2)
                    
                    if final_result['success']:
                        result_file = os.path.join('data', user_id, 'calibration', 'calibration_result.json')
                        with open(result_file, 'w', encoding='utf-8') as f:
                            json.dump(final_result, f, ensure_ascii=False, indent=2)
                        
                        print(f'[离线实验] ✅ 用户 {user_id} 标定完成: {final_result["user_type"]}')
                        print(f'[离线实验] 📊 分析结果已保存: {result_file}')
                        
                        # 保存详细的分析报告
                        report_file = os.path.join('data', user_id, 'calibration', 'analysis_report.txt')
                        with open(report_file, 'w', encoding='utf-8') as f:
                            f.write(f"用户标定分析报告\n")
                            f.write(f"=" * 50 + "\n")
                            f.write(f"用户ID: {user_id}\n")
                            f.write(f"实验次数: {num_trials}\n")
                            f.write(f"分类结果: {final_result['user_type']}\n")
                            f.write(f"描述: {final_result['description']}\n")
                            f.write(f"\n详细数据:\n")
                            f.write(f"静息阶段均值: {final_result['resting_mean']:.4f}\n")
                            f.write(f"注意力阶段均值: {final_result['attention_mean']:.4f}\n")
                            f.write(f"\n各次实验数据:\n")
                            for i, (r, a) in enumerate(zip(final_result.get('all_resting_means', []), 
                                                          final_result.get('all_attention_means', [])), 1):
                                f.write(f"  实验{i}: 静息={r:.4f}, 注意力={a:.4f}\n")
                        print(f'[离线实验] 📄 分析报告已保存: {report_file}')
            else:
                print(f'[离线实验] ❌ 处理失败: {result.get("message")}')
        
        # 在后台线程处理（不阻塞响应）
        threading.Thread(target=process_async).start()
        
        # 立即返回响应
        return jsonify({
            'success': True,
            'message': f'第 {trial_number} 次实验数据已接收，正在后台处理...',
            'trial_number': trial_number
        })
        
    except Exception as e:
        print(f'[离线实验] ❌ 上传失败: {e}')
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/get_calibration_result', methods=['GET'])
def get_calibration_result():
    """
    查询离线实验的处理结果
    """
    user_id = request.args.get('user_id')
    
    if not user_id:
        return jsonify({'success': False, 'message': '缺少user_id参数'}), 400
    
    result_file = os.path.join('data', user_id, 'calibration', 'calibration_result.json')
    
    if os.path.exists(result_file):
        with open(result_file, 'r', encoding='utf-8') as f:
            result = json.load(f)
        return jsonify(result)
    else:
        # 检查已完成的实验数量
        trial_count = 0
        for i in range(1, 3):
            features_file = os.path.join('data', user_id, 'calibration', f'trial_{i}_features.json')
            if os.path.exists(features_file):
                trial_count += 1
        
        return jsonify({
            'success': False,
            'message': '标定未完成',
            'completed_trials': trial_count,
            'required_trials': 2
        })


@app.route('/get_calibration_status', methods=['GET'])
def get_calibration_status():
    """
    获取用户标定状态（包括已完成的实验次数和标定结果）
    用于小程序重新打开时加载用户数据
    """
    user_id = request.args.get('user_id')
    
    if not user_id:
        return jsonify({'success': False, 'message': '缺少user_id参数'}), 400
    
    print(f'[标定状态] 查询用户 {user_id} 的标定状态')
    
    # 检查已完成的实验数量
    trial_count = 0
    for i in range(1, 10):  # 最多检查10次实验
        features_file = os.path.join('data', user_id, 'calibration', f'trial_{i}_features.json')
        if os.path.exists(features_file):
            trial_count += 1
        else:
            break  # 如果某次不存在，后面的也不存在
    
    # 检查是否有最终标定结果
    result_file = os.path.join('data', user_id, 'calibration', 'calibration_result.json')
    calibration_result = None
    
    if os.path.exists(result_file):
        try:
            with open(result_file, 'r', encoding='utf-8') as f:
                calibration_result = json.load(f)
            print(f'[标定状态] 用户 {user_id} 已完成标定: {calibration_result.get("user_type")}')
        except Exception as e:
            print(f'[标定状态] 读取标定结果失败: {e}')
    
    response_data = {
        'success': True,
        'user_id': user_id,
        'completed_trials': trial_count,
        'required_trials': 2,
        'calibration_result': calibration_result  # 可能为None
    }
    
    print(f'[标定状态] 返回: 已完成{trial_count}次实验, 标定结果={calibration_result is not None}')
    
    return jsonify(response_data)


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
        
        # 读取难度信息（从同目录下的difficulty.json文件）
        difficulties = {}
        difficulty_file = os.path.join(result_dir, 'difficulty.json')
        if os.path.exists(difficulty_file):
            try:
                with open(difficulty_file, 'r', encoding='utf-8') as f:
                    difficulties = json.load(f)
            except Exception as e:
                print(f"[难度信息] 读取失败: {e}")

        return jsonify({
            "success": True,
            "files": [f["name"] for f in files],
            "difficulties": difficulties  # 添加难度信息
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
        
        # 读取难度信息
        difficulty = 'normal'  # 默认普通难度
        difficulty_file = os.path.join('data', user_id, 'result', date, 'difficulty.json')
        if os.path.exists(difficulty_file):
            try:
                with open(difficulty_file, 'r', encoding='utf-8') as f:
                    difficulties = json.load(f)
                    difficulty = difficulties.get(file_name, 'normal')
            except Exception as e:
                print(f"[难度信息] 读取失败: {e}")

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
            "totalPoints": len(treatment_data),
            "difficulty": difficulty  # 添加难度信息
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
    请求参数: { "userId": "用户openid", "gameTime": 游戏时长(秒), "difficulty": "easy/normal/hard" }
    返回: { "success": bool, "error": "错误信息" }
    """
    try:
        data = request.json
        user_id = data.get('userId')
        game_time = data.get('gameTime')
        difficulty = data.get('difficulty', 'normal')  # 获取难度，默认为普通

        if not user_id:
            return jsonify({"success": False, "error": "userId is required"}), 400
        if game_time is None:
            return jsonify({"success": False, "error": "gameTime is required"}), 400

        # 确保game_time是整数
        try:
            game_time = int(game_time)
        except (ValueError, TypeError):
            return jsonify({"success": False, "error": "gameTime must be an integer"}), 400

        # 验证难度参数
        if difficulty not in ['easy', 'normal', 'hard']:
            difficulty = 'normal'

        # 获取当前日期和时间
        now = datetime.datetime.now()
        date_str = now.strftime("%Y%m%d")
        timestamp = now.strftime("%Y-%m-%d %H:%M:%S")

        # 游戏记录目录路径
        records_dir = os.path.join('data', user_id, 'game_records')
        os.makedirs(records_dir, exist_ok=True)

        # 记录文件路径（按日期命名）
        record_file = os.path.join(records_dir, f"{date_str}.txt")

        # 追加记录（格式：时间戳,游戏时长,难度）
        with open(record_file, 'a', encoding='utf-8') as f:
            f.write(f"{timestamp},{game_time},{difficulty}\n")

        print(f"[游戏记录] 用户 {user_id} 游戏时长 {game_time}秒 难度 {difficulty} 已保存")

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
                            parts = line.split(',')
                            try:
                                record = {
                                    "timestamp": parts[0],
                                    "gameTime": int(parts[1])
                                }
                                # 兼容旧格式（无难度信息）和新格式（有难度信息）
                                if len(parts) >= 3:
                                    record["difficulty"] = parts[2]
                                else:
                                    record["difficulty"] = "normal"  # 默认为普通难度
                                records.append(record)
                            except (ValueError, IndexError):
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
                                parts = line.split(',')
                                try:
                                    record = {
                                        "timestamp": parts[0],
                                        "gameTime": int(parts[1])
                                    }
                                    # 兼容旧格式（无难度信息）和新格式（有难度信息）
                                    if len(parts) >= 3:
                                        record["difficulty"] = parts[2]
                                    else:
                                        record["difficulty"] = "normal"  # 默认为普通难度
                                    records.append(record)
                                except (ValueError, IndexError):
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
        records_dir = os.path.join('data', user_id, 'schulte', difficulty)
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
        records_dir = os.path.join('data', user_id, 'schulte', difficulty)
        
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

def collect_user_training_data(user_id):
    """
    收集用户所有训练数据，包括：
    1. 躲避游戏记录（训练频率、成绩、时间段）
    2. 舒尔特方格记录（不同难度）
    3. 离线实验标定数据
    """
    training_data = {
        "game_records": [],
        "schulte_records": {},
        "calibration_data": None,
        "summary": {}
    }
    
    # 1. 收集躲避游戏记录
    game_records_dir = os.path.join('data', user_id, 'game_records')
    if os.path.exists(game_records_dir):
        game_records = []
        for filename in sorted(os.listdir(game_records_dir)):
            if filename.endswith('.txt'):
                record_file = os.path.join(game_records_dir, filename)
                with open(record_file, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if ',' in line:
                            parts = line.split(',')
                            try:
                                timestamp = parts[0]
                                game_time = int(parts[1])
                                difficulty = parts[2] if len(parts) >= 3 else "normal"
                                
                                # 解析时间段
                                hour = int(timestamp.split()[1].split(':')[0])
                                time_period = "早晨" if 6 <= hour < 12 else "下午" if 12 <= hour < 18 else "晚上"
                                
                                game_records.append({
                                    "timestamp": timestamp,
                                    "gameTime": game_time,
                                    "difficulty": difficulty,
                                    "hour": hour,
                                    "timePeriod": time_period
                                })
                            except (ValueError, IndexError):
                                continue
        training_data["game_records"] = game_records
    
    # 2. 收集舒尔特方格记录
    schulte_base_dir = os.path.join('data', user_id, 'schulte')
    if os.path.exists(schulte_base_dir):
        for difficulty in ['5x5', '6x6', '7x7']:
            difficulty_dir = os.path.join(schulte_base_dir, difficulty)
            if os.path.exists(difficulty_dir):
                records = []
                for filename in os.listdir(difficulty_dir):
                    if filename.endswith('.txt'):
                        file_path = os.path.join(difficulty_dir, filename)
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                for line in f:
                                    line = line.strip()
                                    if line:
                                        parts = line.split(',')
                                        if len(parts) >= 2:
                                            timestamp = parts[0]
                                            time_value = float(parts[1])
                                            
                                            # 解析时间段
                                            hour = int(timestamp.split()[1].split(':')[0])
                                            time_period = "早晨" if 6 <= hour < 12 else "下午" if 12 <= hour < 18 else "晚上"
                                            
                                            records.append({
                                                "timestamp": timestamp,
                                                "time": time_value,
                                                "hour": hour,
                                                "timePeriod": time_period
                                            })
                        except Exception as e:
                            continue
                training_data["schulte_records"][difficulty] = records
    
    # 3. 收集离线标定数据（如果存在）
    calibration_file = os.path.join('data', user_id, 'eeg_data', 'calibration_result.json')
    if os.path.exists(calibration_file):
        try:
            with open(calibration_file, 'r', encoding='utf-8') as f:
                training_data["calibration_data"] = json.load(f)
        except:
            pass
    
    # 4. 生成汇总统计
    summary = {}
    
    # 躲避游戏统计
    if game_records:
        game_times = [r['gameTime'] for r in game_records]
        time_periods = {}
        for r in game_records:
            period = r['timePeriod']
            time_periods[period] = time_periods.get(period, []) + [r['gameTime']]
        
        summary['game'] = {
            "total_count": len(game_records),
            "avg_time": sum(game_times) / len(game_times),
            "best_time": max(game_times),
            "worst_time": min(game_times),
            "by_time_period": {
                period: {
                    "count": len(times),
                    "avg": sum(times) / len(times)
                } for period, times in time_periods.items()
            },
            "recent_7_days": len([r for r in game_records if (datetime.datetime.now() - datetime.datetime.strptime(r['timestamp'], "%Y-%m-%d %H:%M:%S")).days <= 7]),
            "training_days": len(set(r['timestamp'].split()[0] for r in game_records))
        }
    
    # 舒尔特方格统计
    schulte_summary = {}
    for difficulty, records in training_data["schulte_records"].items():
        if records:
            times = [r['time'] for r in records]
            schulte_summary[difficulty] = {
                "total_count": len(records),
                "best_time": min(times),
                "avg_time": sum(times) / len(times),
                "recent_7_days": len([r for r in records if (datetime.datetime.now() - datetime.datetime.strptime(r['timestamp'], "%Y-%m-%d %H:%M:%S")).days <= 7])
            }
    if schulte_summary:
        summary['schulte'] = schulte_summary
    
    training_data["summary"] = summary
    return training_data

def generate_ai_advice(training_data):
    """
    使用阿里云百炼大模型生成训练建议
    """
    try:
        # 构建prompt
        prompt = f"""你是一个专业的ADHD（注意力缺陷多动障碍）训练指导专家，需要根据用户的训练数据给出针对性的建议。

用户训练数据摘要：

【塔防小游戏训练】
"""
        if 'game' in training_data['summary']:
            game_data = training_data['summary']['game']
            prompt += f"- 总训练次数：{game_data['total_count']}次\n"
            prompt += f"- 平均生存时间：{game_data['avg_time']:.1f}秒\n"
            prompt += f"- 最长生存时间：{game_data['best_time']}秒\n"
            prompt += f"- 最短生存时间：{game_data['worst_time']}秒\n"
            prompt += f"- 训练天数：{game_data['training_days']}天\n"
            prompt += f"- 近7天训练次数：{game_data['recent_7_days']}次\n"
            
            if 'by_time_period' in game_data:
                prompt += "\n不同时段训练表现：\n"
                for period, stats in game_data['by_time_period'].items():
                    prompt += f"  • {period}：{stats['count']}次训练，平均生存{stats['avg']:.1f}秒\n"
        else:
            prompt += "- 暂无塔防游戏训练记录\n"
        
        prompt += "\n【舒尔特方格训练】\n"
        if 'schulte' in training_data['summary']:
            for difficulty, stats in training_data['summary']['schulte'].items():
                prompt += f"- {difficulty}难度：{stats['total_count']}次训练，最佳{stats['best_time']:.1f}秒，平均{stats['avg_time']:.1f}秒\n"
        else:
            prompt += "- 暂无舒尔特方格训练记录\n"
        
        prompt += """

请基于以上数据，从以下几个维度给出建议：
1. **训练频率**：评估当前训练频率是否合理，是否需要调整
2. **训练效果**：分析训练成绩的变化趋势（塔防游戏生存时间是否提升，舒尔特方格完成时间是否缩短）
3. **训练时段**：根据不同时段的表现，建议最佳训练时间
4. **训练难度**：是否需要调整难度以获得更好的训练效果
5. **个性化建议**：结合用户的具体情况，给出3-5条实用的训练建议

请用温暖、鼓励的语气，给出200字左右的综合建议。使用emoji让建议更生动友好。"""

        # 调用大模型
        try:
            # 参考GDScript working example，使用requests直接调用API，避免SDK兼容性问题
            api_key = os.getenv("DASHSCOPE_API_KEY", "sk-341c8f4ad671494c84d12201dc2737cf")
            url = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}"
            }
            
            payload = {
                "model": "qwen-flash",
                "messages": [
                    {
                        "role": "system",
                        "content": "你是一个专业、温暖的ADHD训练指导专家，擅长分析用户数据并给出个性化建议。"
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                "temperature": 0.7,
                "max_tokens": 800
            }
            
            # 增加超时设置
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                if "choices" in result and len(result["choices"]) > 0:
                    advice = result["choices"][0]["message"]["content"]
                    return advice
                else:
                    print(f"[AI建议生成错误] 响应格式异常: {result}")
            else:
                print(f"[AI建议生成错误] API返回错误: {response.status_code} - {response.text}")
                
            return "暂时无法生成AI建议，请稍后再试。继续保持规律训练，您的坚持一定会有回报！💪"
            
        except Exception as e:
            print(f"[AI建议生成错误] {e}")
            print("请参考文档：https://help.aliyun.com/zh/model-studio/developer-reference/error-code")
            return "暂时无法生成AI建议，请稍后再试。继续保持规律训练，您的坚持一定会有回报！💪"

    except Exception as e:
        print(f"[全局AI建议错误] {e}")
        return "暂时无法生成AI建议，请稍后再试。"

@app.route('/getAIAdvice', methods=['POST'])
def get_ai_advice():
    """
    获取AI生成的训练建议
    """
    try:
        data = request.get_json()
        user_id = data.get('userId')
        
        if not user_id:
            return jsonify({
                "success": False,
                "error": "缺少用户ID"
            }), 400
        
        # 收集用户训练数据
        training_data = collect_user_training_data(user_id)
        
        # 生成AI建议
        advice = generate_ai_advice(training_data)
        
        return jsonify({
            "success": True,
            "advice": advice,
            "summary": training_data['summary']
        })
        
    except Exception as e:
        print(f"[获取AI建议错误] {e}")
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
