import numpy as np

def iir_notch_filter(signal: np.ndarray) -> np.ndarray:
    """50Hz陷波滤波器（直接形式II转置）"""
    b = np.array([1.0, -1.9021, 1.0])       # 分子系数
    a = np.array([1.0, -1.71189, 0.81])     # 分母系数
    return np.array([signal[i] - a[1]*signal[i-1] - a[2]*signal[i-2] +
                     b[1]*signal[i-1] + b[2]*signal[i-2]
                     for i in range(2, len(signal))])

def iir_lowpass_filter(signal: np.ndarray) -> np.ndarray:
    """EEG低通滤波器（系数来自eegfilter数组）"""
    coeffs = np.array([
        -0.0053, 0.0033, 0.0034, 0.0039, 0.0048, 0.0060, 0.0074, 0.0090, 0.0108,
        0.0127, 0.0148, 0.0170, 0.0193, 0.0217, 0.0241, 0.0265, 0.0288, 0.0312,
        0.0334, 0.0355, 0.0374, 0.0392, 0.0407, 0.0420, 0.0430, 0.0437, 0.0442,
        0.0443, 0.0442, 0.0437, 0.0430, 0.0420, 0.0407, 0.0392, 0.0374, 0.0355,
        0.0334, 0.0312, 0.0288, 0.0265, 0.0241, 0.0217, 0.0193, 0.0170, 0.0148,
        0.0127, 0.0108, 0.0090, 0.0074, 0.0060, 0.0048, 0.0039, 0.0034, 0.0033,
        -0.0053
    ])
    pad_len = len(coeffs) - 1
    padded = np.pad(signal, (pad_len, 0), mode='edge')
    return np.convolve(padded, coeffs, mode='valid')

def fir_lowpass_filter(signal: np.ndarray) -> np.ndarray:
    """100Hz低通FIR滤波器（21阶）"""
    coeffs = np.array([
        0.0024, 0.0026, 0.0007, -0.0063, -0.0178, -0.0246, -0.0113, 0.0336,
        0.1058, 0.1826, 0.2323, 0.2323, 0.1826, 0.1058, 0.0336, -0.0113,
        -0.0246, -0.0178, -0.0063, 0.0007, 0.0026, 0.0024
    ])
    return np.convolve(signal, coeffs, mode='same')

def wavelet_denoise(signal: np.ndarray, level: int = 4) -> np.ndarray:
    """基于Bior6.8小波的多级去噪"""
    # 小波滤波器系数（与CPP中一致）
    ld = np.array([0, 0.0019, -0.0019, -0.0170, 0.0119, 0.0497, -0.0773,
                  -0.0941, 0.4208, 0.8259, 0.4208, -0.0941, -0.0773, 0.0497,
                  0.0119, -0.0170, -0.0019, 0.0019])
    hd = np.array([0, 0, 0, 0.0144, -0.0145, -0.0787, 0.0404, 0.4178,
                  -0.7589, 0.4178, 0.0404, -0.0787, -0.0145, 0.0144, 0, 0, 0, 0])
    lr = np.array([0, 0, 0, 0.0144, 0.0145, -0.0787, -0.0404, 0.4178,
                  0.7589, 0.4178, -0.0404, -0.0787, 0.0145, 0.0144, 0, 0, 0, 0])
    hr = np.array([0, -0.0019, -0.0019, 0.0170, 0.0119, -0.0497, -0.0773,
                  0.0941, 0.4208, -0.8259, 0.4208, 0.0941, -0.0773, -0.0497,
                  0.0119, 0.0170, -0.0019, -0.0019])

    # 小波分解
    def decompose(signal: np.ndarray) -> tuple:
        approx = np.convolve(signal, ld, mode='same')[::2]  # 近似系数
        detail = np.convolve(signal, hd, mode='same')[::2] # 细节系数
        return approx, detail

    # 小波重构
    def reconstruct(approx: np.ndarray, detail: np.ndarray) -> np.ndarray:
        """小波重构函数（修复长度不一致问题）"""
        # 上采样
        up_approx = np.zeros(len(approx) * 2)
        up_approx[::2] = approx
        up_detail = np.zeros(len(detail) * 2)
        up_detail[::2] = detail

        # 定义小波重构滤波器系数（与CPP代码一致）
        lr = np.array([0, 0, 0, 0.0144, 0.0145, -0.0787, -0.0404, 0.4178,
                       0.7589, 0.4178, -0.0404, -0.0787, 0.0145, 0.0144, 0, 0, 0, 0])
        hr = np.array([0, -0.0019, -0.0019, 0.0170, 0.0119, -0.0497, -0.0773,
                       0.0941, 0.4208, -0.8259, 0.4208, 0.0941, -0.0773, -0.0497,
                       0.0119, 0.0170, -0.0019, -0.0019])

        # 修正方案1：使用mode='full'后截取相同长度
        conv_approx = np.convolve(up_approx, lr, mode='full')
        conv_detail = np.convolve(up_detail, hr, mode='full')

        # 取中间相同长度的部分
        max_len = max(len(conv_approx), len(conv_detail))
        min_len = min(len(conv_approx), len(conv_detail))
        start = (max_len - min_len) // 2

        if len(conv_approx) > len(conv_detail):
            conv_approx = conv_approx[start:start + min_len]
        else:
            conv_detail = conv_detail[start:start + min_len]

        return conv_approx + conv_detail

    # 多级分解与阈值处理
    approx = signal.copy()
    details = []
    for _ in range(level):
        approx, det = decompose(approx)
        details.append(det)

    # 软阈值处理（仅保留高频细节）
    for i in range(level):
        threshold = np.median(np.abs(details[i])) * 0.6745
        details[i] = np.sign(details[i]) * np.maximum(
            np.abs(details[i]) - threshold, 0)

    # 重构信号
    for i in reversed(range(level)):
        approx = reconstruct(approx, details[i])

    return approx

def NingProcess(signal):
    # 完整滤波流程
    signal_notch = iir_notch_filter(signal)  # 50Hz陷波
    signal_lp = iir_lowpass_filter(signal_notch)  # 低通滤波
    signal_clean = wavelet_denoise(signal_lp)  # 小波去噪
    return signal_clean
