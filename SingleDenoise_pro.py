import numpy as np
import pywt
import scipy
from matplotlib import pyplot as plt
from matplotlib.gridspec import GridSpec
from scipy import signal, interpolate
from scipy.signal import butter, sosfiltfilt, savgol_filter


"""
   该代码是单阈值去除眼电的方法
"""

def plot_step(step_name, signals, titles, fs=250):
    """通用绘图函数"""
    n_plots = len(signals)
    fig = plt.figure(figsize=(12, 2 * n_plots))
    gs = GridSpec(n_plots, 1, figure=fig)

    for i in range(n_plots):
        ax = fig.add_subplot(gs[i, 0])
        ax.plot(np.arange(len(signals[i])) / fs, signals[i])
        ax.set_title(titles[i])
        ax.set_xlabel('Time (s)')

    plt.suptitle(step_name, y=1.02)
    plt.tight_layout()
    plt.show()

def find_minima_direction(signal, point, direction):
    """沿指定方向寻找最近的极小值点"""
    min_idx = point
    step = -1 if direction == 'left' else 1

    while True:
        next_idx = min_idx + step
        # 边界检查
        if next_idx < 0 or next_idx >= len(signal):
            break
        # 找到极小值点时停止
        if signal[next_idx] < signal[min_idx]:
            min_idx = next_idx
        else:
            break
    return min_idx


def get_isolated_spike_range(signal, peak, min_dist=0.05 * 250):
    """处理孤立高阈值点：沿下坡方向寻找极小值点"""
    # 检查左侧是否为下坡
    left_down = (peak > 0) and (signal[peak - 1] > signal[peak])
    # 检查右侧是否为下坡
    right_down = (peak < len(signal) - 1) and (signal[peak + 1] > signal[peak])

    if left_down and right_down:  # 尖峰两侧都是下坡
        return (peak, peak)  # 无法确定方向，标记为无效
    elif left_down:
        min_left = find_minima_direction(signal, peak, 'left')
        return (min_left, peak + min_dist)  # 向右扩展固定距离
    elif right_down:
        min_right = find_minima_direction(signal, peak, 'right')
        return (peak - min_dist, min_right)  # 向左扩展固定距离
    else:  # 没有明显下坡方向
        return None

def safe_wavelet_processing(segment, wavelet, J):
    """安全的小波处理流程，保证系数形状匹配"""
    # 1. 确保信号长度合适
    min_len = pywt.Wavelet(wavelet).dec_len * (J + 1)
    if len(segment) < min_len:
        J = int(np.log2(len(segment) / pywt.Wavelet(wavelet).dec_len)) - 1
        J = max(1, J)  # 至少1层分解

    # 2. 使用pad信号确保整除
    orig_len = len(segment)
    pad_len = (orig_len // (2 ** J) + 1) * (2 ** J) - orig_len
    padded = np.pad(segment, (0, pad_len), mode='reflect')

    # 3. 分解时记录每层长度
    coeffs = pywt.wavedec(padded, wavelet, level=J)
    coeff_slices = [slice(None)] * (J + 1)

    # 4. 阈值处理（保持原始系数形状）
    new_coeffs = [coeffs[0]]  # 保留近似系数

    for j in range(1, J + 1):
        coeff = coeffs[j]
        sigma = np.median(np.abs(coeff)) / 0.6745
        threshold = sigma * np.sqrt(2 * np.log(len(coeff)))

        # 分频段处理
        if j <= min(2, J):  # 高频部分
            mask = np.abs(coeff) > threshold
            new_coeff = coeff * mask
        else:  # 低频部分
            new_coeff = pywt.threshold(coeff, threshold, mode='soft')

        new_coeffs.append(new_coeff)
        coeff_slices[j] = slice(0, len(new_coeff))  # 记录形状

    # 5. 安全重构
    try:
        reconstructed = pywt.waverec(new_coeffs, wavelet)
        reconstructed = reconstructed[:orig_len]  # 截断到原始长度
    except ValueError:
        # 如果仍然出错，使用系数填充法
        fixed_coeffs = []
        for c in new_coeffs:
            if len(c.shape) == 1:
                fixed_coeffs.append(c.reshape(-1, 1))
            else:
                fixed_coeffs.append(c)
        reconstructed = pywt.waverec(fixed_coeffs, wavelet)[:orig_len]

    return reconstructed[:len(segment)]


def remove_eog_with_visualization2(raw_signal, fs=250, Drawflag=0,smooth_flag=0):
    # ===== 参数配置 =====
    k = int(0.05 * fs)  # 长时差分延迟(160ms)

    min_spike_distance = int(0.1 * fs)  # 尖峰最小间距

    # ===== 1. 信号预处理 =====
    amplitude = raw_signal  # 使用原始信号绝对值简化处理

    # ===== 2. 动态阈值计算 =====
    diff_signal = np.zeros_like(raw_signal)
    diff_signal[k:] = raw_signal[k:] - raw_signal[:-k]
    sigma = np.std(diff_signal)

    #针对组里设备，下面的参数分别是2.5、0.1、0.1、sym5、6、0.1，无平滑
    #针对眼电数据集，下面的参数分别是2.5、0.5、0.1、sym5、7、0.1，平滑窗长选择101

    high_threshold = 2.5* sigma  # 高阈值
    windowsLen1 = int(0.1 *fs)
    windowsLen2 = int(0.1* fs)
    wavelet = 'sym5'  # 小波基
    J = 6 # 小波分解层数
    mid_filter_len = int(0.1*fs)

    high_threshold = 3

    # ===== 3. 高阈值点检测 =====
    high_points = np.where(amplitude > high_threshold)[0]

    # 合并邻近高阈值点
    clusters = []
    current_cluster = [high_points[0]] if len(high_points) > 0 else []
    for p in high_points[1:]:
        if p - current_cluster[-1] <= min_spike_distance:
            current_cluster.append(p)
        else:
            clusters.append(current_cluster)
            current_cluster = [p]
    if current_cluster:
        clusters.append(current_cluster)

    def smooth_signal(signal, window_length=101, polyorder=3):
        """使用Savitzky-Golay滤波器平滑信号"""
        return savgol_filter(signal, window_length, polyorder)

    if(smooth_flag==1):
    # 原始信号平滑处理
        smoothed_signal = smooth_signal(raw_signal)
    else:
        smoothed_signal = raw_signal


    # ===== 4. 眼电区间检测 =====
    eog_segments = []

    # 处理成对高阈值点
    for cluster in clusters:
        if len(cluster) >= 2:
            left_peak = cluster[0]
            right_peak = cluster[-1]

            # 左峰向左找极小值
            min_left = find_minima_direction(smoothed_signal, left_peak, 'left')
            # 右峰向右找极小值
            min_right = find_minima_direction(smoothed_signal, right_peak, 'right')

            if min_left != min_right:
                eog_segments.append((min_left, min_right))

    # 处理孤立高阈值点
    for cluster in clusters:
        if len(cluster) == 1:
            peak = cluster[0]
            spike_range = get_isolated_spike_range(smoothed_signal, peak,0.05*fs)
            if spike_range:
                eog_segments.append(spike_range)

    # ===== 5. 标记眼电区间 =====
    eog_estimate = np.zeros_like(raw_signal)

    if not eog_segments:
        return raw_signal, eog_estimate

    # ===== 1. 初始眼电标记 =====
    for seg in eog_segments:
        eog_estimate[int(seg[0]):int(seg[1])] = raw_signal[int(seg[0]):int(seg[1])]

    # ===== 2. 眼电分离阶段（优化版） =====
    for seg_idx, (start, end) in enumerate(eog_segments):
        # 扩展处理区域（前后各0.1秒）
        ext_start = max(0, start - windowsLen1)
        ext_end = min(len(raw_signal), end + windowsLen1)
        if(ext_start == 0 ):
            ext_end = ext_end + windowsLen1
        if (ext_end == 0):
            ext_start = ext_start - windowsLen1

        segment = raw_signal[int(ext_start):int(ext_end)]

        # 小波处理（建议safe_wavelet_processing返回与输入相同长度的信号）
        reconstructed = safe_wavelet_processing(segment, wavelet, J)

        # 改进的过渡窗口（使用汉宁窗更平滑）
        fade = windowsLen2  # 加长过渡区域
        window = np.ones(len(reconstructed))

        # 前过渡区（渐入）
        if fade > 0:
            window[:fade] = np.hanning(fade * 2)[:fade]

        # 后过渡区（渐出）
        if fade > 0:
            window[-fade:] = np.hanning(fade * 2)[-fade:]

        # 应用窗口
        reconstructed_windowed = reconstructed * window

        # ===== 关键改进：加权融合 =====
        # 计算当前处理区域在eog_estimate中的位置
        orig_start = start - ext_start
        orig_end = end - ext_start

        # 对扩展区域进行加权融合（避免突变）
        for i in range(len(reconstructed_windowed)):
            pos = ext_start + i
            if pos >= len(eog_estimate):
                break

            # 当前点是否在核心眼电区域内
            in_core = (i >= orig_start) and (i < orig_end)

            # 核心区域：完全使用重构信号
            if in_core:
                eog_estimate[int(pos)] = reconstructed_windowed[i]
            # 过渡区域：加权混合
            else:
                # 保留原始信号的低频成分
                blend_ratio = window[i]  # 使用窗口值作为混合权重
                eog_estimate[int(pos)] = blend_ratio * reconstructed_windowed[i] + \
                                    (1 - blend_ratio) * eog_estimate[int(pos)]


    eog_estimate = eog_estimate + low_freq_compensation(raw_signal,eog_estimate)
    # ===== 4. 最终信号生成 =====
    cleaned_eeg = raw_signal - eog_estimate

    # 端点修正(中值滤波)
    fade_length = mid_filter_len  # 延长过渡窗
    for seg in eog_segments:
        start, end = seg
        start = int(start)
        end = int(end)
        # 前向过渡
        if start > fade_length:
            transition = np.linspace(0, 1, fade_length)
            cleaned_eeg[start - fade_length:start] = (
                    transition * cleaned_eeg[start - fade_length:start] +
                    (1 - transition) * raw_signal[start - fade_length:start]
            )

        # 后向过渡
        if end < len(cleaned_eeg) - fade_length:
            transition = np.linspace(1, 0, fade_length)
            cleaned_eeg[end:end + fade_length] = (
                    transition * cleaned_eeg[end:end + fade_length] +
                    (1 - transition) * raw_signal[end:end + fade_length]
            )

    if (Drawflag == 1):

        # 创建可视化图形
        plt.figure(figsize=(15, 10))

        # 原始信号和高阈值点
        plt.subplot(3, 1, 1)
        plt.plot(np.arange(len(raw_signal)) / fs, raw_signal, label='Raw Signal', alpha=0.8)
        plt.scatter(np.array(high_points) / fs, raw_signal[high_points],
                    color='red', s=50, label='High Threshold Points', zorder=5)
        plt.axhline(high_threshold, color='r', linestyle='--', alpha=0.5, label='High Threshold')
        plt.title("Raw Signal with Detected High Threshold Points")
        plt.ylabel('Amplitude (μV)')
        plt.legend()

        # 检测到的眼电区域
        plt.subplot(3, 1, 2)
        plt.plot(np.arange(len(raw_signal)) / fs, raw_signal, label='Raw Signal', alpha=0.8)
        for i, (start, end) in enumerate(eog_segments):
            start = int(start)
            end = int(end)
            plt.axvspan(start / fs, end / fs, color='orange', alpha=0.3,
                        label='Detected EOG' if i == 0 else "")
            plt.scatter([start / fs, end / fs], [raw_signal[start], raw_signal[end]],
                        color='darkorange', s=40, zorder=5)
        plt.title("Detected EOG Regions")
        plt.ylabel('Amplitude (μV)')
        plt.legend()

        # 最终处理结果
        plt.subplot(3, 1, 3)
        plt.plot(np.arange(len(raw_signal)) / fs, raw_signal, label='Raw Signal', alpha=0.6)
        plt.plot(np.arange(len(cleaned_eeg)) / fs, cleaned_eeg, label='Cleaned EEG', alpha=0.9)
        plt.plot(np.arange(len(eog_estimate)) / fs, eog_estimate, 'r', label='EOG Estimate', alpha=0.7)
        plt.title("Final Processing Results")
        plt.xlabel('Time (s)')
        plt.ylabel('Amplitude (μV)')
        plt.legend()

        plt.tight_layout()
        plt.show()

    return cleaned_eeg, eog_estimate


def low_freq_compensation(Insignal, eog_estimate, fs=250):
    """自适应低频补偿"""
    # 带通滤波提取更窄的低频成分
    sos = signal.butter(6, [0.5, 4], 'bandpass', fs=fs, output='sos')
    low_comp = signal.sosfiltfilt(sos, Insignal)

    # 动态匹配补偿幅度
    comp_scale = np.sqrt(np.mean(low_comp ** 2)) / (np.sqrt(np.mean(eog_estimate ** 2)) + 1e-6)
    return low_comp * np.clip(comp_scale, 0.1, 0.3)  # 缩小补偿范围

