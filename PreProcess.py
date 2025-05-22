import sys #python库的路径

import pywt

sys.path.append('D:\\anaconda\\lib\\site-packages')
from matplotlib import pyplot as plt
from scipy import signal
import numpy as np
from scipy.signal import cheby2, filtfilt, welch, medfilt

"""
   该代码存放了滤波的函数，减少了前后失真
"""

# 使用非交互式后端
plt.switch_backend('TkAgg')


# 预处理函数
def preprocess1(OriginalSignal, fs=250):
    # out = input.shape[0]
    # step1: 滤波
    d1 = OriginalSignal
    b, a = signal.butter(6, 0.5 / (fs / 2), 'highpass')  # 0.5Hz 高通巴特沃斯滤波器
    d1 = signal.filtfilt(b, a, d1)

    b, a = signal.butter(6, [49 / (fs / 2), 51 / (fs / 2)], 'bandstop')  # 50Hz 工频干扰
    d1 = signal.filtfilt(b, a, d1)

    b, a = signal.butter(6, [99 / (fs / 2), 101 / (fs / 2)], 'bandstop')  # 50Hz 工频干扰
    d1 = signal.filtfilt(b, a, d1)

    b, a = signal.butter(6, 40/ (fs / 2), 'lowpass')  # 100Hz 低通
    d1 = signal.filtfilt(b, a, d1)

    theta_band = [4,8]
    beta_band = [13,30]
    power_ratio = compute_power_ratio(d1, fs, theta_band, beta_band)

    return d1,power_ratio


def preprocess3(x, Fs):
    d1 = IIR(x,Fs,50)
    d1 = IIR(d1, Fs, 100)
    d1 = d1 - medfilt(d1, kernel_size=125)
    d1 = HPF(d1, Fs, 0.5);
    d1 = LPF(d1, Fs, 80);
    theta_band = [4, 8]
    beta_band = [13, 30]
    power_ratio = compute_power_ratio(d1, Fs, theta_band, beta_band)
    return d1,power_ratio

def preprocess(raw_signal, fs=250, visualize=False):
    """完整的眼电信号预处理流程"""
    # ===== 1. 智能延拓 =====
    max_filter_len = 3 * 71  # 取FIR滤波器长度的3倍
    pad_len = int(1.5 * max_filter_len)

    # 镜像延拓 + 汉宁窗过渡
    padded = np.pad(raw_signal, (pad_len, pad_len), mode='reflect')
    window = np.concatenate([
        np.hanning(2 * pad_len)[:pad_len],
        np.ones(len(padded) - 2 * pad_len),
        np.hanning(2 * pad_len)[pad_len:]
    ])
    padded = padded * window

    # ===== 2. 滤波器设计 =====
    # 0.5Hz高通 (Butterworth)
    sos_high = signal.butter(6, 0.5, 'highpass', fs=fs, output='sos')


    # 50Hz带阻 (Notch)
    def design_notch(f0, Q=30):
        nyq = fs / 2
        w0 = f0 / nyq
        b, a = signal.iirnotch(w0, Q)
        return b, a

    # 40Hz低通 (FIR)
    fir_low = signal.firls(71, [0, 38, 42, fs / 2], [1, 1, 0, 0], fs=fs)

    # ===== 3. 零相位滤波链 =====
    filtered = signal.sosfiltfilt(sos_high, padded)  # 高通
    for f0 in [50, 100]:  # 消除基波和谐波
        b, a = design_notch(f0)
        filtered = signal.filtfilt(b, a, filtered)
    filtered = signal.filtfilt(fir_low, [1.0], filtered)  # 低通

    # ===== 4. 精准截断 =====
    result = filtered[pad_len:-pad_len]

    return result


import numpy as np
from scipy.signal import cheby2, cheb2ord, filtfilt

import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import welch, cheby2, cheb2ord, filtfilt


def compute_power_ratio(eeg_data, Fs, theta_band, beta_band, show_plots=False):
    """
    Compute the theta/beta power ratio of EEG data with optional visualization

    Parameters:
        eeg_data : array_like
            Input EEG signal (1D array)
        Fs : float
            Sampling frequency in Hz
        theta_band : list
            Theta frequency band [low, high] in Hz
        beta_band : list
            Beta frequency band [low, high] in Hz
        show_plots : bool
            Whether to display visualization plots (default: False)

    Returns:
        float: Theta/beta power ratio
    """
    # Chebyshev Type II filter parameters
    Rp = 3  # Passband ripple (dB)
    Rs = 40  # Stopband attenuation (dB)

    # Design theta band Chebyshev Type II bandpass filter
    f1_theta = theta_band[0] / (Fs / 2)
    f2_theta = theta_band[1] / (Fs / 2)
    n_theta, Wn_theta = cheb2ord([f1_theta, f2_theta],
                                 [f1_theta * 0.8, f2_theta * 1.2],
                                 Rp, Rs)
    b_theta, a_theta = cheby2(n_theta, Rs, Wn_theta, 'bandpass')

    # Design beta band Chebyshev Type II bandpass filter
    f1_beta = beta_band[0] / (Fs / 2)
    f2_beta = beta_band[1] / (Fs / 2)
    n_beta, Wn_beta = cheb2ord([f1_beta, f2_beta],
                               [f1_beta * 0.8, f2_beta * 1.2],
                               Rp, Rs)
    b_beta, a_beta = cheby2(n_beta, Rs, Wn_beta, 'bandpass')

    # Filter theta band (using filtfilt for zero-phase filtering)
    theta_filtered = filtfilt(b_theta, a_theta, eeg_data)
    theta_power = np.sum(theta_filtered ** 2)

    # Filter beta band (using filtfilt for zero-phase filtering)
    beta_filtered = filtfilt(b_beta, a_beta, eeg_data)
    beta_power = np.sum(beta_filtered ** 2)

    # Compute theta/beta power ratio
    power_ratio = theta_power / beta_power if beta_power != 0 else np.nan

    # Visualization (only if requested)
    if show_plots:
        plt.figure(figsize=(15, 10))

        # Time domain plots
        t = np.arange(len(eeg_data)) / Fs
        plt.subplot(3, 1, 1)
        plt.plot(t, eeg_data, label='Original')
        plt.plot(t, theta_filtered, label='Theta filtered')
        plt.plot(t, beta_filtered, label='Beta filtered')
        plt.xlabel('Time (s)')
        plt.ylabel('Amplitude')
        plt.title('Original and Filtered Signals')
        plt.legend()
        plt.grid(True)

        # Frequency domain plots
        freqs, psd = welch(eeg_data, fs=Fs, nperseg=1024)
        _, theta_psd = welch(theta_filtered, fs=Fs, nperseg=1024)
        _, beta_psd = welch(beta_filtered, fs=Fs, nperseg=1024)

        plt.subplot(3, 1, 2)
        plt.semilogy(freqs, psd, label='Original')
        plt.semilogy(freqs, theta_psd, label='Theta band')
        plt.semilogy(freqs, beta_psd, label='Beta band')
        plt.xlabel('Frequency (Hz)')
        plt.ylabel('Power Spectral Density')
        plt.title('Power Spectral Density')
        plt.legend()
        plt.grid(True)

        # Band power comparison
        plt.subplot(3, 1, 3)
        bands = ['Theta', 'Beta']
        powers = [theta_power, beta_power]
        plt.bar(bands, powers)
        plt.ylabel('Power')
        plt.title(f'Band Power Comparison (TBR = {power_ratio:.2f})')
        plt.grid(True)

        plt.tight_layout()
        plt.show()

    return power_ratio


def compute_power_ratio2(eeg_data, Fs, theta_band, beta_band,alpha_band):
    """
    计算 theta 波段和 beta 波段的功率比，并绘制频谱对比图

    参数:
    eeg_data: 输入的 EEG 信号（一维数组）
    Fs: 采样频率
    theta_band: theta 波段范围 [f1_theta, f2_theta]
    beta_band: beta 波段范围 [f1_beta, f2_beta]

    返回:
    power_ratio: theta 和 beta 波段的功率比
    """

    # 切比雪夫 II 型滤波器参数
    Rs = 20  # 阻带衰减（dB）

    # 设计 theta 波段的切比雪夫 II 型带通滤波器
    f1_theta = theta_band[0] / (Fs / 2)
    f2_theta = theta_band[1] / (Fs / 2)
    Wn_theta = [f1_theta, f2_theta]
    b_theta, a_theta = cheby2(6, Rs, Wn_theta, btype='bandpass')  # 8 是滤波器阶数

    # 设计 beta 波段的切比雪夫 II 型带通滤波器
    f1_beta = beta_band[0] / (Fs / 2)
    f2_beta = beta_band[1] / (Fs / 2)
    Wn_beta = [f1_beta, f2_beta]
    b_beta, a_beta = cheby2(6, Rs, Wn_beta, btype='bandpass')  # 8 是滤波器阶数

    f1_alpha = alpha_band[0] / (Fs / 2)
    f2_alpha = alpha_band[1] / (Fs / 2)
    Wn_alpha = [f1_alpha, f2_alpha]
    b_alpha, a_alpha = cheby2(6, Rs, Wn_alpha, btype='bandpass')  # 8 是滤波器阶数


    # 对 theta 波段滤波
    theta_filtered = filtfilt(b_theta, a_theta, eeg_data.astype(float))
    # 对 beta 波段滤波
    beta_filtered = filtfilt(b_beta, a_beta, eeg_data.astype(float))

    alpha_filtered = filtfilt(b_alpha, a_alpha, eeg_data.astype(float))

    # 计算 theta 和 beta 波段功率
    theta_power = np.sum(theta_filtered ** 2)
    beta_power = np.sum(beta_filtered ** 2)
    alpha_power = np.sum(alpha_filtered ** 2)

    # 计算 theta 和 beta 功率比
    if beta_power != 0:
        power_ratio = (theta_power +alpha_power)/ beta_power
    else:
        power_ratio = np.nan  # 防止除以零

    return power_ratio

from typing import Tuple, List, Optional


def bior68_wavelet_denoise(
    signal: np.ndarray,
    fs: int = 250,
    wavelet: str = 'bior6.8',
    level: Optional[int] = None,
    threshold_mode: str = 'adaptive',
    hard_threshold: bool = False,
    noise_std: Optional[float] = None
) -> np.ndarray:
    """
    增强版小波去噪（可调节去噪力度）

    参数:
        signal: 输入信号
        fs: 采样频率
        wavelet: 小波类型（默认bior6.8）
        level: 分解层数（自动计算若为None）
        threshold_mode: 阈值模式 ('adaptive', 'universal', 'manual')
        hard_threshold: 是否使用硬阈值（默认软阈值）
        noise_std: 手动指定噪声标准差（可选）

    返回:
        去噪后的信号
    """
    # 1. 自动计算最佳分解层数（比标准更激进）
    if level is None:
        level = min(8, int(np.log2(len(signal))) - 3)
        level = max(level, 1)  # 至少1层

    # 2. 小波分解
    coeffs = pywt.wavedec(signal, wavelet, level=level)

    # 3. 噪声估计
    if noise_std is None:
        noise_std = np.median(np.abs(coeffs[-1])) / 0.6745

    # 4. 增强阈值策略
    detail_coeffs = coeffs[1:]
    for i, detail in enumerate(detail_coeffs):
        N = len(detail)

        if threshold_mode == 'adaptive':
            # 层自适应阈值（更激进的系数衰减）
            threshold = noise_std * np.sqrt(2 * np.log(N)) / np.log2(i + 2)
        elif threshold_mode == 'universal':
            threshold = noise_std * np.sqrt(2 * np.log(N))
        else:  # manual
            threshold = noise_std * 1.5  # 手动调整系数

        # 应用阈值
        if hard_threshold:
            detail_coeffs[i] = pywt.threshold(detail, threshold, mode='hard')
        else:
            # 增强型软阈值（更激进）
            abs_val = np.abs(detail)
            sign = np.sign(detail)
            detail_coeffs[i] = sign * np.where(
                abs_val > threshold,
                abs_val - threshold * 1.2,  # 增加衰减力度
                0
            )

    # 5. 重构信号
    coeffs[1:] = detail_coeffs
    return pywt.waverec(coeffs, wavelet)[:len(signal)]


import numpy as np
import math


def IIR(data, rate, frequency):
    """
    IIR notch filter implementation

    Parameters:
    data (array-like): Input signal data
    rate (float): Sampling rate in Hz
    frequency (float): Notch frequency to filter out

    Returns:
    numpy.ndarray: Filtered output signal
    """
    LL = len(data)  # Data length

    # First 50 Hz notch filter pass
    fh = frequency
    fs = rate
    wh = fh * math.pi / fs
    Q = math.tan(wh)  # Angular frequency
    p = 5  # Quality factor
    A = 1
    m = 1.0 + Q / p + Q * Q
    a0 = (1 + Q * Q) * A / m
    a1 = 2.0 * (Q * Q - 1.0) * A / m
    a2 = (Q * Q + 1.0) * A / m
    b1 = 2.0 * (Q * Q - 1.0) / m
    b2 = (1.0 - Q / p + Q * Q) / m

    # Initialize filter states
    y1 = data[0]
    y2 = data[1]
    x1 = a0 * y1
    x2 = a0 * y2 + a1 * y1 - b1 * x1

    I2 = np.zeros(LL)
    I2[0] = x1
    I2[1] = x2

    for i in range(2, LL):
        y3 = data[i]
        y2 = data[i - 1]
        y1 = data[i - 2]
        x3 = a0 * y3 + a1 * y2 + a2 * y1 - b1 * x2 - b2 * x1
        I2[i] = x3
        x1, x2 = x2, x3

    data = I2

    # Second 50 Hz notch filter pass (same coefficients as first pass)
    # Re-initialize filter states
    y1 = data[0]
    y2 = data[1]
    x1 = a0 * y1
    x2 = a0 * y2 + a1 * y1 - b1 * x1

    I2 = np.zeros(LL)
    I2[0] = x1
    I2[1] = x2

    for i in range(2, LL):
        y3 = data[i]
        y2 = data[i - 1]
        y1 = data[i - 2]
        x3 = a0 * y3 + a1 * y2 + a2 * y1 - b1 * x2 - b2 * x1
        I2[i] = x3
        x1, x2 = x2, x3

    output = I2
    return output


def HPF(data, rate, frequency):
    """
    High Pass Filter implementation

    Parameters:
    data (array-like): Input signal data
    rate (float): Sampling rate in Hz
    frequency (float): Cutoff frequency for the high pass filter

    Returns:
    numpy.ndarray: Filtered output signal
    """
    LL = len(data)  # Data length

    # First high pass filter pass
    fh = frequency
    fs = rate
    wh = fh * math.pi / fs
    Q = math.tan(wh)  # Angular frequency
    p = 0.707  # Quality factor
    m = 1.0 + Q / p + Q * Q
    a = 1 / m
    b1 = 2.0 * (Q * Q - 1.0) / m
    b2 = (1.0 - Q / p + Q * Q) / m

    # Initialize filter states
    y1 = data[0]
    y2 = data[1]
    x1 = a * y1
    x2 = a * (y2 - 2.0 * y1) - b1 * x1

    I3 = np.zeros(LL)
    I3[0] = x1
    I3[1] = x2

    for i in range(2, LL):
        y3 = data[i]
        y2 = data[i - 1]
        y1 = data[i - 2]
        x3 = a * (y3 - 2.0 * y2 + y1) - b1 * x2 - b2 * x1
        I3[i] = x3
        x1, x2 = x2, x3

    data = I3

    # Second high pass filter pass (same coefficients as first pass)
    # Re-initialize filter states
    y1 = data[0]
    y2 = data[1]
    x1 = a * y1
    x2 = a * (y2 - 2.0 * y1) - b1 * x1

    I3 = np.zeros(LL)
    I3[0] = x1
    I3[1] = x2

    for i in range(2, LL):
        y3 = data[i]
        y2 = data[i - 1]
        y1 = data[i - 2]
        x3 = a * (y3 - 2.0 * y2 + y1) - b1 * x2 - b2 * x1
        I3[i] = x3
        x1, x2 = x2, x3

    output = I3
    return output


def LPF(data, rate, frequency):
    """
    Low Pass Filter implementation with delay compensation

    Parameters:
    data (array-like): Input signal data
    rate (float): Sampling rate in Hz
    frequency (float): Cutoff frequency for the low pass filter

    Returns:
    numpy.ndarray: Filtered output signal with delay compensation
    """
    LL = len(data)

    # Filter coefficients calculation
    fh = frequency
    fs = rate
    wh = fh * math.pi / fs
    Q = math.tan(wh)  # Angular frequency
    p = 0.707  # Quality factor (Butterworth response)
    m = 1.0 + Q / p + Q * Q
    a = 1.414 * Q * Q / m
    b1 = 2.0 * (Q * Q - 1.0) / m
    b2 = (1.0 - Q / p + Q * Q) / m

    # Initialize filter states
    y1 = data[0]
    y2 = data[1]
    x1 = a * y1
    x2 = a * (y2 + 2.0 * y1) - b1 * x1

    data2 = np.zeros(LL)
    data2[0] = x1
    data2[1] = x2

    # Apply low pass filter
    for i in range(2, LL):
        y3 = data[i]
        y2 = data[i - 1]
        y1 = data[i - 2]
        x3 = a * (y3 + 2.0 * y2 + y1) - b1 * x2 - b2 * x1
        data2[i] = x3
        x1, x2 = x2, x3

    # Compensate for filter delay by shifting the output
    delay = 30  # Fixed delay compensation
    output_length = len(data2) - delay
    output_args = np.zeros(output_length)

    for i in range(output_length):
        output_args[i] = data2[i + delay]

    return output_args

