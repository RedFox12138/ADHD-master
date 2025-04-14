import sys #python库的路径

from pyemd import EEMD, CEEMDAN
from numpy import std
from scipy.stats import stats, kurtosis
from sklearn.decomposition import FastICA

from Entropy import SampleEntropy2

sys.path.append('D:\\anaconda\\lib\\site-packages')
from matplotlib import pyplot as plt
from scipy import signal
import numpy as np
from scipy.signal import cheby2, filtfilt, welch

"""
   该代码存放了滤波的函数，减少了前后失真
"""

# 使用非交互式后端
plt.switch_backend('TkAgg')


# 预处理函数
# def preprocess1(OriginalSignal, fs=250):
#     # out = input.shape[0]
#     # step1: 滤波
#     d1 = OriginalSignal
#     b, a = signal.butter(6, 0.5 / (fs / 2), 'highpass')  # 0.5Hz 高通巴特沃斯滤波器
#     d1 = signal.filtfilt(b, a, d1)
#
#     b, a = signal.butter(6, [49 / (fs / 2), 51 / (fs / 2)], 'bandstop')  # 50Hz 工频干扰
#     d1 = signal.filtfilt(b, a, d1)
#
#     b, a = signal.butter(6, [99 / (fs / 2), 101 / (fs / 2)], 'bandstop')  # 50Hz 工频干扰
#     d1 = signal.filtfilt(b, a, d1)
#
#     b, a = signal.butter(6, 40/ (fs / 2), 'lowpass')  # 100Hz 低通
#     d1 = signal.filtfilt(b, a, d1)
#
#     theta_band = [4,8]
#     beta_band = [13,30]
#     power_ratio = compute_power_ratio(d1, fs, theta_band, beta_band)
#
#     return d1,power_ratio



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



def compute_power_ratio(eeg_data, Fs, theta_band, beta_band):
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

    # 对 theta 波段滤波
    theta_filtered = filtfilt(b_theta, a_theta, eeg_data.astype(float))
    # 对 beta 波段滤波
    beta_filtered = filtfilt(b_beta, a_beta, eeg_data.astype(float))

    # 计算 theta 和 beta 波段功率
    theta_power = np.sum(theta_filtered ** 2)
    beta_power = np.sum(beta_filtered ** 2)

    # 计算 theta 和 beta 功率比
    if beta_power != 0:
        power_ratio = theta_power / beta_power
    else:
        power_ratio = np.nan  # 防止除以零

    # # 绘制频谱对比图
    # plot_spectrum_comparison(eeg_data, theta_filtered, beta_filtered, Fs, theta_band, beta_band)

    return power_ratio

