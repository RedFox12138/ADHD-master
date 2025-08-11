import numpy as np
from scipy import signal
from scipy.signal import spectrogram
import matplotlib.pyplot as plt



# fs = 250  # 采样频率
# window_size = 6 * fs  # 滑动窗口长度（6秒数据）
# step_size = int(0.5 * fs)  # 滑动步长（0.5秒数据）
# nfft = 1024  # FFT点数
#
# # 定义波段范围
# band_ranges = {
#     'Delta': (0.5, 4),
#     'Theta': (4, 8),
#     'Alpha': (8, 13),
#     'Beta': (13, 30)
# }
#
# # 初始化存储变量
# time_points = []
# window_powers = {band: [] for band in band_ranges}  # 存储每个窗口的功率
#
# # 滑动窗口处理
# for i in range(0, len(eeg_data) - window_size + 1, step_size):
#     window_data = eeg_data[i:i + window_size]
#
#     # 计算当前窗口的STFT
#     f, t, S = spectrogram(window_data, fs=fs, window='hamming',
#                          nperseg=512, noverlap=256, nfft=nfft, mode='magnitude')
#
#     # 计算当前窗口各波段功率
#     for band, (low, high) in band_ranges.items():
#         band_mask = (f >= low) & (f <= high)
#         S_band = np.abs(S[band_mask, :]) ** 2
#         window_powers[band].append(np.mean(S_band))  # 直接存储当前窗口功率
#
#     # 记录时间点（窗口中间时刻）
#     time_points.append((i + window_size / 2) / fs)
#
# # 绘制各波段功率时序图
# plt.figure(figsize=(12, 8))
#
# for idx, (band, powers) in enumerate(window_powers.items(), 1):
#     plt.subplot(4, 1, idx)
#     plt.plot(time_points, powers)
#     plt.title(f'{band} Band ({band_ranges[band][0]}-{band_ranges[band][1]}Hz) Power')
#     plt.ylabel('Power')
#     if idx == 4:
#         plt.xlabel('Time (s)')
#
# plt.tight_layout()
# plt.show()
#
# # 保存功率数据
# power_data = np.column_stack([time_points] + [window_powers[band] for band in band_ranges])
# np.savetxt('band_power.txt', power_data,
#           header='Time(s) Delta Theta Alpha Beta', comments='')

#
import numpy as np
import matplotlib.pyplot as plt
from PreProcess import compute_power_ratio, compute_power_ratio2


def sliding_window_tbr(file_path, fs, window_length=6, step_size=0.5):
    """
    滑动窗口计算时序TBR

    参数:
        file_path: 信号文件路径
        fs: 采样频率
        window_length: 窗长(秒) - 固定6秒
        step_size: 滑动步长(秒) - 固定0.5秒

    返回:
        tbr_values: 时序TBR值
        time_points: 对应的时间点
    """
    # 读取信号数据
    signal = np.loadtxt(file_path)

    # 计算窗口参数
    window_samples = int(window_length * fs)
    step_samples = int(step_size * fs)  # 修正：直接使用步长计算
    total_samples = len(signal)

    # 初始化结果列表
    tbr_values = []
    time_points = []

    # 滑动窗口计算TBR
    for start in range(0, total_samples - window_samples + 1, step_samples):
        end = start + window_samples
        window_signal = signal[start:end]

        theta_band = [4, 8]
        beta_band = [13, 30]
        # 计算当前窗口的TBR
        tbr = compute_power_ratio2(window_signal, fs, theta_band, beta_band, None,False)

        # 记录结果
        tbr_values.append(tbr)
        time_points.append((start + end) / (2 * fs))  # 窗口中心点时间

    return np.array(tbr_values), np.array(time_points)

# 示例使用
if __name__ == "__main__":
    # 参数设置
    file_path = 'D:\\Pycharm_Projects\\ADHD-master\\data\\额头信号去眼电\\0526 SF 小程序_processed.txt'
    sampling_freq = 250

    # 计算时序TBR (6s窗长，0.5s步长)
    tbr_values, time_points = sliding_window_tbr(
        file_path,
        fs=sampling_freq,
        window_length=6,
        step_size=0.5  # 明确使用步长参数
    )

    # 显示结果
    plt.figure(figsize=(12, 6))

    # 绘制原始TBR曲线
    plt.plot(time_points, tbr_values, '-o', label='TBR')

    # 划分阶段并计算平均TBR
    rest_mask = (time_points <= 30) & (time_points >= 10)
    stim_mask = time_points > 30

    rest_avg = np.mean(tbr_values[rest_mask])
    stim_avg = np.mean(tbr_values[stim_mask])

    # 绘制阶段分割线
    plt.axvline(x=30, color='gray', linestyle='--', label='Phase Transition')

    # 绘制平均TBR虚线
    plt.hlines(rest_avg, xmin=1, xmax=30, colors='blue', linestyles='dashed', label='Rest Avg TBR')
    plt.hlines(stim_avg, xmin=30, xmax=max(time_points), colors='red', linestyles='dashed', label='Stim Avg TBR')

    # 添加阶段标注
    plt.text(15, max(tbr_values) * 0.9, 'Rest Phase', ha='center', bbox=dict(facecolor='white', alpha=0.8))
    plt.text((30 + max(time_points)) / 2, max(tbr_values) * 0.9, 'Stim Phase', ha='center',
             bbox=dict(facecolor='white', alpha=0.8))

    plt.xlabel('Time (s)')
    plt.ylabel('Theta/Beta Ratio')
    plt.title('Time-varying Theta/Beta Ratio with Phase Averages')
    plt.grid(True)
    plt.legend()
    plt.show()