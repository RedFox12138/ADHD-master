import numpy as np
from matplotlib import pyplot as plt
from scipy.signal import welch
from PreProcess import preprocess
"""
   该代码用于展示凝胶和干电极数据的对比，一般没什么用
"""

def plot_freq_psd(data, fs=300, label=None, ax=None, color=None):
    """计算并绘制信号的功率谱密度（dB）"""
    f, Pxx = welch(data, fs=fs, nperseg=1024)
    Pxx_db = 10 * np.log10(Pxx)  # 功率谱转换为dB

    if ax is None:
        ax = plt.gca()

    line = ax.plot(f, Pxx_db, label=label, color=color, alpha=0.8, linewidth=1.5)
    ax.set_xlabel('Frequency (Hz)')
    ax.set_ylabel('Power/frequency (dB/Hz)')
    ax.grid(True, alpha=0.3)
    return ax


# 加载数据
fs = 300
data1 = np.loadtxt('./0402/额头干电极.txt', dtype=np.float32)
data2 = np.loadtxt('./0402/额头凝胶1.txt', dtype=np.float32)
data3 = np.loadtxt('./0402/额头凝胶2.txt', dtype=np.float32)
data4 = np.loadtxt('./0402/额头凝胶3.txt', dtype=np.float32)

# 统一长度
lenmin = min(len(data1), len(data2), len(data3), len(data4)) - 17 * fs
data1 = data1[:lenmin]
data2 = data2[:lenmin]
data3 = data3[:lenmin]
data4 = data4[:lenmin]

# 预处理
processed_points1 = preprocess(data1, fs)
processed_points2 = preprocess(data2, fs)
processed_points3 = preprocess(data3, fs)
processed_points4 = preprocess(data4, fs)

# 创建时域和频域对比图
plt.figure(figsize=(14, 10))

# ===== 时域图 =====
plt.subplot(2, 1, 1)
offset = 50  # 信号间的垂直偏移量
time = np.arange(len(processed_points2)) / fs

# 绘制原始信号（半透明）
plt.plot(time, data1 + offset * 0, label='dry (raw)', color='blue', alpha=0.5)
plt.plot(time, data2 + offset * 1, label='gel1 (raw)', color='green', alpha=0.5)
plt.plot(time, data3 + offset * 2, label='gel2 (raw)', color='red', alpha=0.5)
plt.plot(time, data4 + offset * 3, label='gel3 (raw)', color='purple', alpha=0.5)

# 绘制处理后的信号（实线）
plt.plot(time, processed_points1 + offset * 0, label='dry (processed)', color='blue', linewidth=1.2)
plt.plot(time, processed_points2 + offset * 1, label='gel1 (processed)', color='green', linewidth=1.2)
plt.plot(time, processed_points3 + offset * 2, label='gel2 (processed)', color='red', linewidth=1.2)
plt.plot(time, processed_points4 + offset * 3, label='gel3 (processed)', color='purple', linewidth=1.2)

plt.legend(loc='upper right', ncol=2)
plt.xlabel('Time (s)')
plt.ylabel('Amplitude (with offset)')
plt.title('Time Domain Comparison')
plt.grid(True, alpha=0.3)

# ===== 频域图（Welch PSD）=====
plt.subplot(2, 1, 2)

# 绘制处理后的信号PSD
plot_freq_psd(processed_points1, fs=fs, label='dry', color='blue')
plot_freq_psd(processed_points2, fs=fs, label='gel1', color='green')
plot_freq_psd(processed_points3, fs=fs, label='gel2', color='red')
plot_freq_psd(processed_points4, fs=fs, label='gel3', color='purple')

plt.legend(loc='upper right')
plt.xlim(0, 50)  # 聚焦0-50Hz范围
plt.title('Power Spectral Density (Welch method)')

# 添加EEG频段标记
for freq, text in [(0.5, 'Delta'), (4, 'Theta'), (8, 'Alpha'),
                   (13, 'Beta'), (30, 'Gamma')]:
    plt.axvline(x=freq, color='gray', linestyle=':', alpha=0.5)
    plt.text(freq + 1, plt.ylim()[1] - 5, text, ha='left', color='gray')

plt.tight_layout()
plt.show()