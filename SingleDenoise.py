import numpy as np
import pywt
import scipy
from matplotlib import pyplot as plt
from matplotlib.gridspec import GridSpec
from scipy import signal, interpolate

"""
   该代码是双阈值去除眼电的方法
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


def find_local_minima(data, points, search_direction=-1):
    """
    对给定的点集，沿着指定方向搜索局部极小值点
    data: 原始信号
    points: 需要处理的点索引列表
    search_direction: -1表示向左搜索，1表示向右搜索
    返回: 更新后的点索引列表（极小值点位置）
    """
    minima_points = []
    slope = np.diff(data)  # 计算斜率

    for point in points:
        current = point
        found = False

        # 向左搜索（search_direction=-1）
        if search_direction == -1:
            while current > 0:
                # 如果当前点的斜率 >=0（即不再下降），说明找到了极小值点
                if slope[current - 1] >= 0:
                    found = True
                    break
                current -= 1
        # 向右搜索（search_direction=1）
        else:
            while current < len(slope) - 1:
                # 如果当前点的斜率 <=0（即不再下降），说明找到了极小值点
                if slope[current] <= 0:
                    found = True
                    break
                current += 1

        # 如果找到极小值点则使用，否则保留原值
        minima_points.append(current if found else point)

    return minima_points


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

    return reconstructed[:len(segment)]  # 确保输出长度匹配

def remove_eog_with_visualization(raw_signal, fs=250,Drawflag=0):
    """
    带可视化调试的眼电去除方法
    参数:
        raw_signal : 输入脑电信号(1D numpy数组)
        fs : 采样率(默认512Hz)
    返回:
        cleaned_eeg : 去噪后的脑电信号
        eog_estimate : 估计的眼电成分
    """
    # ===== 参数配置 =====
    k = int(0.05 * fs)  # 长时差分延迟(160ms)

    wavelet = 'sym5'  # 小波基
    J = 6  # 小波分解层数
    # wavelet = 'db4'  # 更适合生物信号的小波基
    # J = 5  # 减少分解层数以提高时间分辨率

    # ===== 2. 直接计算幅度 =====
    amplitude = raw_signal

    diff_signal = np.zeros_like(raw_signal)
    diff_signal[k:] = raw_signal[k:] - raw_signal[:-k]
    sigma = np.std(diff_signal)
    kurt = scipy.stats.kurtosis(raw_signal)  # 计算峰度
    adaptive_factor = np.clip(1 + 0.5 * (kurt - 3), -2, 2)  # 正态分布峰度为3
    high_threshold = 3
    low_threshold = 0.1* sigma * adaptive_factor

    # ===== 4. 检测眼电区间 =====
    def get_threshold_crossings(data, threshold):
        """获取连续超过阈值的区域边界（优化版）"""
        above = data > threshold if threshold > 0 else data < threshold
        transitions = np.diff(above.astype(int))

        rise = np.where(transitions == 1)[0] + 1
        fall = np.where(transitions == -1)[0]

        # 边界对齐逻辑
        if len(rise) == 0 and len(fall) == 0:
            return [] if not above[0] else [(0, len(data) - 1)]
        if len(rise) == 0:
            return [(0, fall[0])] if above[0] else []
        if len(fall) == 0:
            return [(rise[0], len(data) - 1)]

        # 确保起始点对齐
        if rise[0] > fall[0]:
            fall = fall[1:]
        return list(zip(rise[:len(fall)], fall))


    # 获取阈值区域
    high_regions = get_threshold_crossings(amplitude, high_threshold)
    low_regions = get_threshold_crossings(amplitude, low_threshold)


    eog_events = []
    used_points = set()

    # ===== 完整眼电检测 =====
    for h_start, h_end in high_regions:
        # 寻找包围高阈值区的双低阈值区
        prev_lows = [(l_s, l_e) for l_s, l_e in low_regions if l_e < h_start]
        next_lows = [(l_s, l_e) for l_s, l_e in low_regions if l_s > h_end]

        if len(prev_lows) == 0 or len(next_lows) == 0:
            continue

        # 选择最接近的低阈值区
        l1 = max(prev_lows, key=lambda x: x[1])  # 前导低区
        l2 = min(next_lows, key=lambda x: x[0])  # 后续低区

        # 验证时间约束（根据示意图结构）
        if (h_start - l1[1] > 0.1 * fs) or (l2[0] - h_end > 0.1 * fs):
            continue

        # 标记完整眼电区域（包含50ms扩展）
        event_start = max(0, l1[0] - int(0.05 * fs))
        event_end = min(len(amplitude) - 1, l2[1] + int(0.05 * fs))
        eog_events.append((event_start, event_end, 'complete'))

        # 记录已使用的点
        used_points.update(range(event_start, event_end + 1))

    # ===== 不完整眼电检测 =====
    # 获取未被使用的离散点
    high_points = [i for i in np.where(amplitude > high_threshold)[0] if i not in used_points]
    low_points = [i for i in np.where(amplitude < low_threshold)[0] if i not in used_points]



    # 动态配对逻辑
    for h in high_points:
        # 搜索前后时间窗内的低点
        valid_lows = []

        # 前向搜索（高→低）
        forward = [l for l in low_points if h < l <= h + int(0.3 * fs)]
        if forward:
            valid_lows.append(forward[0])

        # 反向搜索（低→高）
        backward = [l for l in low_points if h - int(0.3 * fs) <= l < h]
        if backward:
            valid_lows.append(backward[-1])

        # 验证时间约束
        for l in valid_lows:
            if abs(h - l) < int(0.05 * fs):
                continue

            # 边界扩展处理
            if l < int(0.2 * fs):  # 左边界
                eog_events.append((0, l, ''))
            elif (len(amplitude) - l) < int(0.2 * fs):  # 右边界
                eog_events.append((l, len(amplitude) - 1, ''))
            else:  # 正常情况
                eog_events.append((min(h, l), max(h, l), ''))

        # 步骤3：合并重叠事件
    eog_segments = []
    for event in sorted(eog_events, key=lambda x: x[0]):
        start, end, typ = event
        if eog_segments and start - eog_segments[-1][1] <= 0.1*fs:  # 检查间隔是否<=0.1秒
            last_start, last_end = eog_segments[-1]
            eog_segments[-1] = (last_start, max(last_end, end))
        else:
            eog_segments.append((start, end))

    # ===== 5. 标记眼电区间 =====
    eog_estimate = np.zeros_like(raw_signal)
    for seg in eog_segments:
        eog_estimate[seg[0]:seg[1]] = raw_signal[seg[0]:seg[1]]

    # ===== 6. 可视化结果 =====
    if Drawflag:
        plt.figure(figsize=(14, 7))
        ax = plt.subplot(211)
        plt.plot(np.arange(len(raw_signal)) / fs, raw_signal, label='Raw EEG', alpha=0.8)
        plt.plot(np.arange(len(amplitude)) / fs, amplitude, label='Amplitude', alpha=0.6)

        # 绘制高低阈值区域
        for h_start, h_end in high_regions:
            plt.axvspan(h_start / fs, h_end / fs, color='red', alpha=0.2,
                        label='High Threshold' if h_start == high_regions[0][0] else "")
        for l_start, l_end in low_regions:
            plt.axvspan(l_start / fs, l_end / fs, color='green', alpha=0.1,
                        label='Low Threshold' if l_start == low_regions[0][0] else "")

        plt.axhline(high_threshold, color='r', linestyle=':', alpha=0.5)
        plt.axhline(low_threshold, color='g', linestyle=':', alpha=0.5)
        plt.title("Threshold Regions Detection")
        plt.ylabel('Amplitude (μV)')
        plt.legend()

        # 绘制最终眼电事件
        ax = plt.subplot(212, sharex=ax)
        plt.plot(np.arange(len(raw_signal)) / fs, raw_signal, label='Raw EEG', alpha=0.8)
        for i, (start, end) in enumerate(eog_segments):
            plt.axvspan(start / fs, end / fs, color='orange', alpha=0.3,
                        label='EOG Event' if i == 0 else "")

        # 标记事件类型
        for event in eog_events:
            start, end, typ = event
            y_pos = np.max(amplitude[int(start):int(end)]) * 1.1
            plt.text((start + end) / 2 / fs, y_pos, typ[:1],
                     ha='center', va='bottom', color='darkred', fontweight='bold')

        plt.title("Detected EOG Events (C: complete, P: partial)")
        plt.xlabel('Time (s)')
        plt.ylabel('Amplitude (μV)')
        plt.legend()
        plt.tight_layout()
        plt.show()

    # ===== 5. 标记眼电区间 =====
    for seg in eog_segments:
        eog_estimate[seg[0]:seg[1]] = raw_signal[seg[0]:seg[1]]  # 保留眼电部分


    if not eog_segments:
        return raw_signal, eog_estimate

    # ===== 3. 眼电分离阶段 =====
    for seg_idx, seg in enumerate(eog_segments):
        start, end = seg
        for seg_idx, (start, end) in enumerate(eog_segments):
            ext_start = max(0, start - int(0.2 * fs))
            ext_end = min(len(raw_signal), end + int(0.2 * fs))
            segment = raw_signal[ext_start:ext_end]

            # 使用安全处理函数
            reconstructed = safe_wavelet_processing(segment, wavelet, J)

            # 应用过渡窗
            fade = int(0.05 * fs)
            window = np.ones(len(reconstructed))
            window[:fade] = np.linspace(0, 1, fade)
            window[-fade:] = np.linspace(1, 0, fade)
            reconstructed = reconstructed * window

            # 写入估计信号
            orig_start = start - ext_start
            orig_end = end - ext_start
            eog_estimate[start:end] = reconstructed[orig_start:orig_end]

    eog_estimate += low_freq_compensation(raw_signal,eog_estimate)

    # ===== 4. 信号校正 =====
    cleaned_eeg = raw_signal - eog_estimate

    # 端点修正(中值滤波)
    # 在信号校正阶段替换端点修正
    fade_length = int(0.1 * fs)  # 延长过渡窗
    for seg in eog_segments:
        start, end = seg

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
        # 最终结果可视化
        plt.figure(figsize=(12, 6))
        plt.subplot(3, 1, 1)
        plt.plot(np.arange(len(raw_signal)) / fs, raw_signal)
        plt.title("Raw Signal")
        plt.subplot(3, 1, 2)
        plt.plot(np.arange(len(eog_estimate)) / fs, eog_estimate, 'r')
        plt.title("eog_estimate")
        plt.subplot(3, 1, 3)
        plt.plot(np.arange(len(cleaned_eeg)) / fs, cleaned_eeg)
        plt.title("cleaned_eeg")
        plt.tight_layout()
        plt.show()
    return cleaned_eeg, eog_estimate


def low_freq_compensation(Insignal, eog_estimate, fs=250):
    """自适应低频补偿"""
    # 带通滤波提取更窄的低频成分
    sos = signal.butter(4, [1, 3], 'bandpass', fs=fs, output='sos')
    low_comp = signal.sosfiltfilt(sos, Insignal)

    # 动态匹配补偿幅度
    comp_scale = np.sqrt(np.mean(low_comp ** 2)) / (np.sqrt(np.mean(eog_estimate ** 2)) + 1e-6)
    return low_comp * np.clip(comp_scale, 0.05, 0.1)  # 缩小补偿范围