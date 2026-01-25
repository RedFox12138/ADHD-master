"""
离线实验数据处理模块
处理离线实验的完整信号：预处理、去眼电、特征提取
"""

import numpy as np
import os
from PreProcess import preprocess3
from SingleDenoise_CORRECTED import eog_removal_corrected
from feature_calculator import calculate_windowed_features, classify_user_type


def process_calibration_trial(raw_file_path, user_id, trial_number, fs=250):
    """
    处理单次离线实验数据
    
    参数:
        raw_file_path: 原始数据文件路径
        user_id: 用户ID
        trial_number: 实验次数
        fs: 采样率
        
    返回:
        {
            'success': bool,
            'resting_features': list,  # 静息阶段的样本熵特征
            'attention_features': list,  # 注意力阶段的样本熵特征
            'resting_mean': float,
            'attention_mean': float
        }
    """
    try:
        print(f'[离线实验处理] 开始处理用户 {user_id} 的第 {trial_number} 次实验')
        
        # 读取原始数据
        if not os.path.exists(raw_file_path):
            return {'success': False, 'message': f'数据文件不存在: {raw_file_path}'}
        
        with open(raw_file_path, 'r') as f:
            lines = f.readlines()
        
        # 解析数据（浮点数，与塔防游戏保存格式一致）
        eeg_data = []
        for line in lines:
            line = line.strip()
            if line:
                try:
                    eeg_data.append(float(line))  # 改为float，因为保存的是转换后的数据
                except:
                    continue
        
        if len(eeg_data) < fs * 70:  # 至少70秒数据（10准备+30静息+10休息+30注意力=80秒，留10秒缓冲）
            return {'success': False, 'message': f'数据长度不足: {len(eeg_data)} < {fs*70}'}
        
        print(f'[离线实验处理] 读取到 {len(eeg_data)} 个数据点 ({len(eeg_data)/fs:.2f}秒)')
        
        # 1. 预处理完整信号
        print(f'[离线实验处理] 步骤1: 预处理完整信号')
        processed_signal, _ = preprocess3(np.array(eeg_data), fs)
        
        # 2. 去眼电
        print(f'[离线实验处理] 步骤2: 去除眼电')
        cleaned_signal = eog_removal_corrected(processed_signal, fs, visualize=False)
        
        print(f'[离线实验处理] 处理后信号总长度: {len(cleaned_signal)} 点 ({len(cleaned_signal)/fs:.2f}秒)')
        
        # 3. 分割静息和注意力阶段
        # 10s准备 + 30s静息 + 10s休息 + 30s注意力
        prepare_end = int(10 * fs)
        rest_start = prepare_end
        rest_end = rest_start + int(30 * fs)
        break_end = rest_end + int(10 * fs)
        attention_start = break_end
        attention_end = attention_start + int(30 * fs)
        
        print(f'[离线实验处理] 时间分割点:')
        print(f'  准备阶段: 0 - {prepare_end} ({prepare_end/fs:.2f}秒)')
        print(f'  静息阶段: {rest_start} - {rest_end} ({(rest_end-rest_start)/fs:.2f}秒)')
        print(f'  休息阶段: {rest_end} - {break_end} ({(break_end-rest_end)/fs:.2f}秒)')
        print(f'  注意力阶段: {attention_start} - {attention_end} ({(attention_end-attention_start)/fs:.2f}秒)')
        print(f'  总计需要: {attention_end} 点 ({attention_end/fs:.2f}秒)')
        
        # 检查数据是否足够
        if len(cleaned_signal) < attention_end:
            print(f'[离线实验处理] ⚠️ 警告: 数据长度不足，实际{len(cleaned_signal)}点，需要{attention_end}点')
            print(f'[离线实验处理] 缺少 {attention_end - len(cleaned_signal)} 点 ({(attention_end - len(cleaned_signal))/fs:.2f}秒)')
        
        rest_signal = cleaned_signal[rest_start:rest_end]
        attention_signal = cleaned_signal[attention_start:attention_end]
        
        print(f'[离线实验处理] 静息阶段: {len(rest_signal)} 点 ({len(rest_signal)/fs:.2f}秒)')
        print(f'[离线实验处理] 注意力阶段: {len(attention_signal)} 点 ({len(attention_signal)/fs:.2f}秒)')
        
        # 4. 计算特征（使用统一的特征计算模块）
        print(f'[离线实验处理] 步骤3: 计算特征 (使用全局特征计算模块)')
        
        resting_features = calculate_windowed_features(rest_signal, fs=fs)
        attention_features = calculate_windowed_features(attention_signal, fs=fs)
        
        print(f'[离线实验处理] 静息特征数: {len(resting_features)}, 均值: {np.mean(resting_features):.4f}')
        print(f'[离线实验处理] 注意力特征数: {len(attention_features)}, 均值: {np.mean(attention_features):.4f}')
        
        # 保存处理后的数据
        save_processed_data(user_id, trial_number, rest_signal, attention_signal, 
                           resting_features, attention_features)
        
        return {
            'success': True,
            'resting_features': resting_features,
            'attention_features': attention_features,
            'resting_mean': float(np.mean(resting_features)),
            'attention_mean': float(np.mean(attention_features))
        }
        
    except Exception as e:
        print(f'[离线实验处理] 处理失败: {e}')
        import traceback
        traceback.print_exc()
        return {'success': False, 'message': str(e)}




def save_processed_data(user_id, trial_number, rest_signal, attention_signal, 
                       resting_features, attention_features):
    """
    保存处理后的数据
    """
    import json
    
    # 创建保存目录
    calibration_dir = os.path.join('data', user_id, 'calibration')
    os.makedirs(calibration_dir, exist_ok=True)
    
    # 保存处理后的信号
    processed_file = os.path.join(calibration_dir, f'trial_{trial_number}_processed.npz')
    np.savez(processed_file, 
             rest=rest_signal, 
             attention=attention_signal,
             resting_features=resting_features,
             attention_features=attention_features)
    
    # 保存特征到JSON
    features_file = os.path.join(calibration_dir, f'trial_{trial_number}_features.json')
    with open(features_file, 'w') as f:
        json.dump({
            'trial_number': trial_number,
            'resting_features': [float(f) for f in resting_features],
            'attention_features': [float(f) for f in attention_features],
            'resting_mean': float(np.mean(resting_features)),
            'attention_mean': float(np.mean(attention_features))
        }, f, indent=2)
    
    print(f'[离线实验处理] 数据已保存到 {calibration_dir}')


def analyze_all_trials(user_id, num_trials=2):
    """
    分析所有实验，取平均结果
    
    参数:
        user_id: 用户ID
        num_trials: 实验次数
        
    返回:
        用户分类结果
    """
    import json
    
    calibration_dir = os.path.join('data', user_id, 'calibration')
    
    all_resting_means = []
    all_attention_means = []
    
    for trial in range(1, num_trials + 1):
        features_file = os.path.join(calibration_dir, f'trial_{trial}_features.json')
        
        if not os.path.exists(features_file):
            print(f'[离线实验分析] 缺少实验 {trial} 的特征文件')
            continue
        
        with open(features_file, 'r') as f:
            data = json.load(f)
            all_resting_means.append(data['resting_mean'])
            all_attention_means.append(data['attention_mean'])
    
    if len(all_resting_means) < num_trials:
        return {
            'success': False,
            'message': f'实验数据不足: {len(all_resting_means)}/{num_trials}'
        }
    
    # 使用统一的分类方法
    # 这里传入所有特征值的列表
    result = classify_user_type(all_resting_means, all_attention_means)
    
    print(f'[离线实验分析] 用户类型: {result["user_type"]} ({result["description"]})')
    
    return {
        'success': True,
        'user_type': result['user_type'],
        'resting_mean': result['resting_mean'],
        'attention_mean': result['attention_mean'],
        'description': result['description'],
        'all_resting_means': [float(m) for m in all_resting_means],
        'all_attention_means': [float(m) for m in all_attention_means]
    }

