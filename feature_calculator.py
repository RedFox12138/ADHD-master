"""
全局特征计算模块
统一管理所有EEG特征的计算，方便以后替换和扩展

使用示例：
    from feature_calculator import calculate_features, calculate_windowed_features
    
    # 计算单个窗口的特征
    features = calculate_features(eeg_data, fs=250)
    
    # 计算滑动窗口特征
    features_list = calculate_windowed_features(eeg_data, fs=250, window_sec=6, step_sec=2)
"""

import numpy as np
from SampEn import SampEn_optimized


# ==================== 配置项 ====================
# 当前使用的特征类型
CURRENT_FEATURE = 'sample_entropy'

# 样本熵参数
SAMPEN_M = 2  # 嵌入维度
SAMPEN_R = 0.2  # 容差阈值（相对于标准差的倍数）

# 滑动窗口参数（用于离线实验）
DEFAULT_WINDOW_SEC = 6  # 默认窗口长度（秒）
DEFAULT_STEP_SEC = 2    # 默认步长（秒）


# ==================== 特征计算函数 ====================

def calculate_sample_entropy(data, m=SAMPEN_M, r=None):
    """
    计算样本熵
    
    参数:
        data: EEG数据数组
        m: 嵌入维度
        r: 容差阈值（None时自动计算为0.2*std）
        
    返回:
        样本熵值（float）
    """
    try:
        # 完全按照main.py的调用方式
        samp = SampEn_optimized(data)
        tbr = samp[0][2]
        return tbr
    except Exception as e:
        print(f'[特征计算] 样本熵计算失败: {e}')
        import traceback
        traceback.print_exc()
        return 0.0


def calculate_power_spectrum_features(data, fs):
    """
    计算功率谱特征（预留接口）
    
    参数:
        data: EEG数据数组
        fs: 采样率
        
    返回:
        特征字典，例如：{'delta': 0.5, 'theta': 0.3, ...}
    """
    # TODO: 实现功率谱特征计算
    # 可以计算 Delta, Theta, Alpha, Beta, Gamma 频段功率
    pass


def calculate_frequency_domain_features(data, fs):
    """
    计算频域特征（预留接口）
    
    参数:
        data: EEG数据数组
        fs: 采样率
        
    返回:
        特征值
    """
    # TODO: 实现频域特征计算
    pass


def calculate_time_domain_features(data):
    """
    计算时域特征（预留接口）
    
    参数:
        data: EEG数据数组
        
    返回:
        特征字典，例如：{'mean': 0.5, 'std': 0.3, ...}
    """
    # TODO: 实现时域特征计算
    # 例如：均值、标准差、峰峰值、过零率等
    pass


# ==================== 统一特征计算接口 ====================

def calculate_features(data, fs=250, feature_type=None):
    """
    统一的特征计算接口（单个窗口）
    
    参数:
        data: EEG数据数组
        fs: 采样率
        feature_type: 特征类型，None时使用默认类型（CURRENT_FEATURE）
            可选: 'sample_entropy', 'power_spectrum', 'frequency_domain', 'time_domain'
        
    返回:
        特征值（float或dict）
    """
    if feature_type is None:
        feature_type = CURRENT_FEATURE
    
    # 检查数据有效性
    if data is None or len(data) == 0:
        print('[特征计算] 警告: 数据为空')
        return 0.0
    
    # 转换为numpy数组
    if not isinstance(data, np.ndarray):
        data = np.array(data)
    
    # 根据类型计算特征
    if feature_type == 'sample_entropy':
        return calculate_sample_entropy(data)
    
    elif feature_type == 'power_spectrum':
        return calculate_power_spectrum_features(data, fs)
    
    elif feature_type == 'frequency_domain':
        return calculate_frequency_domain_features(data, fs)
    
    elif feature_type == 'time_domain':
        return calculate_time_domain_features(data)
    
    else:
        raise ValueError(f'未知的特征类型: {feature_type}')


def calculate_windowed_features(data, fs=250, window_sec=None, step_sec=None, feature_type=None):
    """
    使用滑动窗口计算特征序列
    
    参数:
        data: EEG数据数组
        fs: 采样率
        window_sec: 窗口长度（秒），None时使用默认值
        step_sec: 步长（秒），None时使用默认值
        feature_type: 特征类型，None时使用默认类型
        
    返回:
        特征值列表
    """
    if window_sec is None:
        window_sec = DEFAULT_WINDOW_SEC
    if step_sec is None:
        step_sec = DEFAULT_STEP_SEC
    
    # 转换为numpy数组
    if not isinstance(data, np.ndarray):
        data = np.array(data)
    
    window_size = int(window_sec * fs)
    step_size = int(step_sec * fs)
    
    features = []
    num_windows = (len(data) - window_size) // step_size + 1
    
    print(f'[特征计算] 滑动窗口: {window_sec}秒窗口, {step_sec}秒步长, 共{num_windows}个窗口')
    
    for i in range(num_windows):
        start = i * step_size
        end = start + window_size
        
        if end > len(data):
            break
        
        window_data = data[start:end]
        feature = calculate_features(window_data, fs, feature_type)
        features.append(feature)
    
    return features


# ==================== 特征比较与分类 ====================

def classify_user_type(resting_features, attention_features):
    """
    根据静息和注意力特征判断用户类型
    
    参数:
        resting_features: 静息阶段特征列表
        attention_features: 注意力阶段特征列表
        
    返回:
        {
            'user_type': 'type_A' or 'type_B',
            'resting_mean': float,
            'attention_mean': float,
            'description': str
        }
    """
    resting_mean = float(np.mean(resting_features))
    attention_mean = float(np.mean(attention_features))
    
    # 判断用户类型
    if resting_mean > attention_mean:
        user_type = 'type_A'
        description = f'静息特征({resting_mean:.4f}) > 注意力特征({attention_mean:.4f})'
    else:
        user_type = 'type_B'
        description = f'静息特征({resting_mean:.4f}) < 注意力特征({attention_mean:.4f})'
    
    return {
        'user_type': user_type,
        'resting_mean': resting_mean,
        'attention_mean': attention_mean,
        'description': description
    }


# ==================== 实时特征计算（游戏中使用） ====================

def calculate_realtime_feature(data_buffer, fs=250):
    """
    实时计算特征（用于游戏中的实时判断）
    
    参数:
        data_buffer: 数据缓冲区（通常是6秒数据）
        fs: 采样率
        
    返回:
        特征值
    """
    return calculate_features(data_buffer, fs)


# ==================== 批量特征计算 ====================

def calculate_features_batch(data_list, fs=250, feature_type=None):
    """
    批量计算多段数据的特征
    
    参数:
        data_list: 数据列表，每个元素是一段EEG数据
        fs: 采样率
        feature_type: 特征类型
        
    返回:
        特征值列表
    """
    features = []
    for data in data_list:
        feature = calculate_features(data, fs, feature_type)
        features.append(feature)
    return features


# ==================== 辅助函数 ====================

def get_current_feature_name():
    """获取当前使用的特征名称"""
    return CURRENT_FEATURE


def get_feature_config():
    """获取当前特征配置"""
    return {
        'feature_type': CURRENT_FEATURE,
        'sampen_m': SAMPEN_M,
        'sampen_r': SAMPEN_R,
        'window_sec': DEFAULT_WINDOW_SEC,
        'step_sec': DEFAULT_STEP_SEC
    }


def set_feature_type(feature_type):
    """
    设置全局特征类型
    
    参数:
        feature_type: 'sample_entropy', 'power_spectrum', 'frequency_domain', 'time_domain'
    """
    global CURRENT_FEATURE
    CURRENT_FEATURE = feature_type
    print(f'[特征计算] 全局特征类型已设置为: {feature_type}')


if __name__ == '__main__':
    # 测试代码
    print('=== 特征计算模块测试 ===')
    
    # 生成测试数据
    test_data = np.random.randn(250 * 30)  # 30秒数据
    
    # 测试单窗口特征计算
    print('\n1. 单窗口特征计算:')
    feature = calculate_features(test_data[:250*6])  # 6秒数据
    print(f'   样本熵: {feature:.4f}')
    
    # 测试滑动窗口特征计算
    print('\n2. 滑动窗口特征计算:')
    features = calculate_windowed_features(test_data, fs=250)
    print(f'   特征数量: {len(features)}')
    print(f'   特征均值: {np.mean(features):.4f}')
    
    # 测试用户分类
    print('\n3. 用户分类测试:')
    resting_features = [0.5, 0.6, 0.55]
    attention_features = [0.4, 0.45, 0.42]
    result = classify_user_type(resting_features, attention_features)
    print(f'   用户类型: {result["user_type"]}')
    print(f'   描述: {result["description"]}')
    
    print('\n=== 测试完成 ===')
