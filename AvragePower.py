import numpy as np
from scipy import signal
from scipy.signal import spectrogram
import matplotlib.pyplot as plt

# 读取txt文件中的EEG信号
# 假设txt文件中每行一个数据点，没有其他内容
with open('D:\\pycharm Project\\ADHD-master\\data\\额头信号去眼电\\0508 SF1_processed.txt', 'r') as f:
    eeg_data = np.loadtxt(f)

fs = 250  # 采样频率，根据实际情况修改

# 设置STFT参数
window = signal.windows.hamming(512)  # 窗函数
noverlap = 256  # 重叠点数
nfft = 1024  # FFT点数

# 计算STFT
f, t, S = spectrogram(eeg_data, fs=fs, window=window, noverlap=noverlap, nfft=nfft, mode='magnitude')

# 定义波段范围
delta_band = (f >= 0.5) & (f <= 4)    # Delta: 0.5-4Hz
theta_band = (f >= 4) & (f <= 8)       # Theta: 4-8Hz
alpha_band = (f >= 8) & (f <= 13)      # Alpha: 8-13Hz
beta_band = (f >= 13) & (f <= 30)      # Beta: 13-30Hz

# 提取各波段功率（幅度平方）
S_delta = np.abs(S[delta_band, :])**2
S_theta = np.abs(S[theta_band, :])**2
S_alpha = np.abs(S[alpha_band, :])**2
S_beta = np.abs(S[beta_band, :])**2

# 计算各波段瞬时功率（跨频率维度平均）
delta_power = np.mean(S_delta, axis=0)
theta_power = np.mean(S_theta, axis=0)
alpha_power = np.mean(S_alpha, axis=0)
beta_power = np.mean(S_beta, axis=0)

# 去掉前10个时间点（与MATLAB代码一致）
delta_power = delta_power[10:]
theta_power = theta_power[10:]
alpha_power = alpha_power[10:]
beta_power = beta_power[10:]
t = t[10:]

# 计算累积平均功率
delta_cumavg = np.cumsum(delta_power) / np.arange(1, len(delta_power)+1)
theta_cumavg = np.cumsum(theta_power) / np.arange(1, len(theta_power)+1)
alpha_cumavg = np.cumsum(alpha_power) / np.arange(1, len(alpha_power)+1)
beta_cumavg = np.cumsum(beta_power) / np.arange(1, len(beta_power)+1)

# 绘制累积平均功率时序图
plt.figure(figsize=(12, 8))

plt.subplot(4, 1, 1)
plt.plot(t, delta_cumavg)
plt.title('Delta Band (0.5-4Hz) Cumulative Average Power')
plt.ylabel('Power')

plt.subplot(4, 1, 2)
plt.plot(t, theta_cumavg)
plt.title('Theta Band (4-8Hz) Cumulative Average Power')
plt.ylabel('Power')

plt.subplot(4, 1, 3)
plt.plot(t, alpha_cumavg)
plt.title('Alpha Band (8-13Hz) Cumulative Average Power')
plt.ylabel('Power')

plt.subplot(4, 1, 4)
plt.plot(t, beta_cumavg)
plt.title('Beta Band (13-30Hz) Cumulative Average Power')
plt.xlabel('Time (s)')
plt.ylabel('Power')

plt.tight_layout()
plt.show()