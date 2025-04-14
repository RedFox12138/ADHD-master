import numpy as np
import pywt

def wavelet_decomposition(signal, wavelet='sym7', level=5):
    """
    实现多层小波分解
    参数：
        signal : 输入信号（1D数组）
        wavelet : 母波类型（默认sym7）
        level : 分解层数（默认5层）
    返回：
        coeffs : 分解系数列表 [cA5, cD5, cD4, cD3, cD2, cD1]
                 对应6个WCs（近似系数 + 细节系数）
    """
    # 执行小波分解
    coeffs = pywt.wavedec(signal, wavelet=wavelet, level=level)

    # 验证分解结果
    assert len(coeffs) == level + 1, "分解结果数量应与分解层数+1相等"
    return coeffs


def compute_frequency_ranges(fs, level=5):
    """
    计算各层频率范围的函数
    :param fs: 采样率（单位Hz）
    :param level: 分解层数
    :return: 频率范围字典
    """
    freq_ranges = {}

    # 细节系数频率范围
    for n in range(1, level + 1):
        upper = fs / (2 ** n)
        lower = upper / 2
        freq_ranges[f'cD{n}'] = (lower, upper)

    # 近似系数频率范围
    freq_ranges[f'cA{level}'] = (0, fs / (2  ** (level+1)))

    return freq_ranges


import numpy as np

def ewt_decomposition(x, fs=250, delta_band=4, gamma=0.05):
    """
    优化后的EWT分解函数，减少低频段幅度损失。

    参数:
        x (array): 输入信号（单通道脑电信号）
        fs (int): 采样频率（默认250Hz）
        delta_band (float): δ频段截止频率（默认4Hz）
        gamma (float): 过渡带宽度参数（默认0.05）

    返回:
        low_signal (array): δ频段信号（0-4Hz）
        high_signal (array): 高频段信号（4-40Hz）
    """
    n = len(x)
    X = np.fft.fft(x)
    freqs = np.fft.fftfreq(n, 1 / fs)

    phi_filter = np.zeros(n, dtype=np.complex_)
    psi_filter = np.zeros(n, dtype=np.complex_)

    omega_1 = delta_band
    omega_2 = 40
    tau_1 = gamma * omega_1  # 更窄的低频过渡带
    tau_2 = gamma * omega_2

    for i in range(n):
        f = freqs[i]
        if f >= 0:
            # 低频滤波器（δ频段）
            if f <= omega_1 - tau_1:
                phi_gain = 1.0
            elif omega_1 - tau_1 < f <= omega_1 + tau_1:
                x_val = (f - (omega_1 - tau_1)) / (2 * tau_1)
                # 使用更陡峭的过渡函数
                beta_x = x_val ** 4 * (35 - 84 * x_val + 70 * x_val ** 2 - 20 * x_val ** 3)
                phi_gain = np.cos(0.5 * np.pi * beta_x)
            else:
                phi_gain = 0.0

            # 高频滤波器（4-40Hz）
            if (omega_1 - tau_1) <= f < (omega_1 + tau_1):
                x_val = (f - (omega_1 - tau_1)) / (2 * tau_1)
                beta_x = x_val ** 4 * (35 - 84 * x_val + 70 * x_val ** 2 - 20 * x_val ** 3)
                psi_gain = np.sin(0.5 * np.pi * beta_x)
            elif (omega_1 + tau_1) <= f < (omega_2 - tau_2):
                psi_gain = 1.0
            elif (omega_2 - tau_2) <= f < omega_2:
                x_val = (f - (omega_2 - tau_2)) / (2 * tau_2)
                beta_x = x_val ** 4 * (35 - 84 * x_val + 70 * x_val ** 2 - 20 * x_val ** 3)
                psi_gain = np.cos(0.5 * np.pi * beta_x)
            else:
                psi_gain = 0.0
        else:
            f_abs = abs(f)
            if f_abs <= omega_1 - tau_1:
                phi_gain = 1.0
            elif omega_1 - tau_1 < f_abs <= omega_1 + tau_1:
                x_val = (f_abs - (omega_1 - tau_1)) / (2 * tau_1)
                beta_x = x_val ** 4 * (35 - 84 * x_val + 70 * x_val ** 2 - 20 * x_val ** 3)
                phi_gain = np.cos(0.5 * np.pi * beta_x)
            else:
                phi_gain = 0.0

            if (omega_1 - tau_1) <= f_abs < (omega_1 + tau_1):
                x_val = (f_abs - (omega_1 - tau_1)) / (2 * tau_1)
                beta_x = x_val ** 4 * (35 - 84 * x_val + 70 * x_val ** 2 - 20 * x_val ** 3)
                psi_gain = np.sin(0.5 * np.pi * beta_x)
            elif (omega_1 + tau_1) <= f_abs < (omega_2 - tau_2):
                psi_gain = 1.0
            elif (omega_2 - tau_2) <= f_abs < omega_2:
                x_val = (f_abs - (omega_2 - tau_2)) / (2 * tau_2)
                beta_x = x_val ** 4 * (35 - 84 * x_val + 70 * x_val ** 2 - 20 * x_val ** 3)
                psi_gain = np.cos(0.5 * np.pi * beta_x)
            else:
                psi_gain = 0.0

        phi_filter[i] = phi_gain
        psi_filter[i] = psi_gain

    X_low = X * phi_filter
    X_high = X * psi_filter
    low_signal = np.fft.ifft(X_low).real
    high_signal = np.fft.ifft(X_high).real

    return low_signal, high_signal