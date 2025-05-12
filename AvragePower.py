import numpy as np
from scipy import signal
from scipy.signal import spectrogram
import matplotlib.pyplot as plt

# 读取EEG数据
with open('D:\\Pycharm_Projects\\ADHD-master\\data\\额头信号去眼电\\0508 SF1_processed.txt', 'r') as f:
    eeg_data = np.loadtxt(f)

fs = 250  # 采样频率
window_size = 6*fs  # 滑动窗口长度（约4秒数据）
step_size = 125  # 滑动步长（1秒数据）
nfft = 1024  # FFT点数

# 定义波段范围
band_ranges = {
    'Delta': (0.5, 4),
    'Theta': (4, 8),
    'Alpha': (8, 13),
    'Beta': (13, 30)
}

# 初始化存储变量
time_points = []
cumulative_powers = {band: [] for band in band_ranges}
running_sums = {band: 0 for band in band_ranges}

# 滑动窗口处理
for i in range(0, len(eeg_data) - window_size + 1, step_size):
    window_data = eeg_data[i:i + window_size]

    # 计算当前窗口的STFT
    f, t, S = spectrogram(window_data, fs=fs, window='hamming',
                          nperseg=512, noverlap=256, nfft=nfft, mode='magnitude')

    # 计算当前窗口各波段平均功率
    current_powers = {}
    for band, (low, high) in band_ranges.items():
        band_mask = (f >= low) & (f <= high)
        S_band = np.abs(S[band_mask, :]) ** 2
        current_powers[band] = np.mean(S_band)  # 当前窗口的平均功率

    # 更新累积和（关键改进点）
    for band in band_ranges:
        running_sums[band] += current_powers[band]
        cumulative_powers[band].append(running_sums[band] / (i // step_size + 1))  # 累积平均

    # 记录时间点（窗口中间时刻）
    time_points.append((i + window_size / 2) / fs)

# 绘制累积平均功率时序图
plt.figure(figsize=(12, 8))

for idx, (band, powers) in enumerate(cumulative_powers.items(), 1):
    plt.subplot(4, 1, idx)
    plt.plot(time_points, powers)
    plt.title(f'{band} Band ({band_ranges[band][0]}-{band_ranges[band][1]}Hz) Cumulative Avg Power')
    plt.ylabel('Power')
    if idx == 4:
        plt.xlabel('Time (s)')

plt.tight_layout()
plt.show()

# 保存累积平均数据
cumulative_data = np.column_stack([time_points] + [cumulative_powers[band] for band in band_ranges])
np.savetxt('cumulative_power.txt', cumulative_data,
           header='Time(s) Delta Theta Alpha Beta', comments='')