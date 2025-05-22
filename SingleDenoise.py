import numpy as np
import matplotlib.pyplot as plt
import pywt
from scipy.signal import firwin, lfilter


def eog_removal(eeg, fs=250, visualize=False):
    """
    单通道脑电信号眼电去除函数
    参数：
        eeg : 输入脑电信号（1D数组）
        fs : 采样率（默认512Hz）
        visualize : 是否显示处理过程（默认False）
    返回：
        clean_eeg : 去除眼电后的脑电信号
    """
    # ===== 第1步：长时差分计算 =====
    k = int(0.16 * fs)  # 160ms窗口
    diff_eeg = np.zeros_like(eeg)
    diff_eeg[k:] = eeg[k:] - eeg[:-k]

    # ===== 第2步：振幅包络提取 =====
    # 平方和降采样
    M = 8
    squared = diff_eeg ** 2 * 2
    downsampled = squared[::M]

    # 低通滤波（FIR滤波器）
    N = 21
    cutoff = 4 / (fs / M / 2)  # 4Hz截止频率
    h = firwin(N, cutoff, window='hamming')
    filtered = lfilter(h, 1, downsampled)

    # 延迟补偿和上采样可视化准备
    original_filtered = filtered.copy()
    delay = (N - 1) // 2
    filtered = np.roll(filtered, -delay)

    # 上采样恢复原始长度
    envelope = np.zeros_like(eeg)
    upsampled = np.repeat(filtered, M)[:len(eeg)]
    envelope = np.sqrt(upsampled)

    # ===== 第3步：双门限眼电检测 =====
    sigma = np.std(diff_eeg)

    #去眼电的TH为2 ，TL为0.5
    Th = 3 * sigma
    Tl = 1 * sigma

    # 寻找超过高阈值的区域,这个是去眼电的时候用的
    # thresholded = envelope > Th

    thresholded = diff_eeg > 2.5

    starts, ends = find_intervals(thresholded)

    # 扩展检测区间
    valid_intervals = []
    for s, e in zip(starts, ends):
        # 向后搜索
        new_s = s
        while new_s > 0 and envelope[new_s] > Tl:
            new_s -= 1
        # 向前搜索
        new_e = e
        while new_e < len(envelope) - 1 and envelope[new_e] > Tl:
            new_e += 1
        # 去除短于50ms的区间
        if (new_e - new_s) > 0.05 * fs:
            valid_intervals.append((new_s, new_e))

    # ===== 第4步：小波变换眼电分离 =====
    wavelet = 'sym5'
    level = 8  # 增加分解层数
    clean_eeg = eeg.copy()

    for s, e in valid_intervals:
        # 扩展处理区间（增加重叠区域）
        win_len = e - s
        overlap = win_len   # 增加重叠区域
        s_ext = max(0, s - overlap)
        e_ext = min(len(eeg), e + overlap)

        # 创建窗函数（余弦过渡）
        window = np.ones(e_ext - s_ext)
        transition = min(100, overlap)  # 过渡区长度
        window[:transition] = np.cos(np.linspace(np.pi / 2, 0, transition)) ** 2
        window[-transition:] = np.cos(np.linspace(0, np.pi / 2, transition)) ** 2

        # 小波分解与改进的阈值处理
        segment = eeg[s_ext:e_ext]
        coeffs = pywt.wavedec(segment, wavelet, level=level)

        # 改进的Birgé-Massart策略（更严格）
        L = len(coeffs[0])
        new_coeffs = [coeffs[0]]  # 保留近似系数

        for j in range(1, len(coeffs)):
            # 动态调整保留系数（更稀疏）
            alpha = 2.5 if j < 3 else 2.0  # 更激进的阈值
            n = int(L / (level + 2 - j) ** alpha)

            # 使用混合阈值策略
            coeff_abs = np.abs(coeffs[j])
            sigma = np.median(coeff_abs) / 0.6745
            universal_thr = sigma * np.sqrt(2 * np.log(len(coeff_abs)))

            # 取两者中的较小阈值
            sorted_coeff = np.sort(coeff_abs)[::-1]
            bm_thr = sorted_coeff[n] if n < len(sorted_coeff) else 0
            thr = min(bm_thr, universal_thr)

            new_c = coeffs[j] * (coeff_abs >= thr)
            new_coeffs.append(new_c)

        # 重构眼电信号（改进长度处理）
        eog = pywt.waverec(new_coeffs, wavelet)
        eog = eog[:len(segment)] if len(eog) > len(segment) else eog

        # 改进的边界处理
        clean_segment = (segment - eog) * window  # 应用过渡窗

        # 使用重叠保存法处理边界
        if s_ext > 0:
            left_overlap = clean_eeg[s_ext:s_ext + transition]
            blend = np.linspace(0, 1, transition)
            clean_segment[:transition] = blend * clean_segment[:transition] + (1 - blend) * left_overlap

        if e_ext < len(eeg):
            right_overlap = clean_eeg[e_ext - transition:e_ext]
            blend = np.linspace(1, 0, transition)
            clean_segment[-transition:] = blend * clean_segment[-transition:] + (1 - blend) * right_overlap

        # 更新信号（只修改中间部分）
        start = s_ext + transition // 2
        end = e_ext - transition // 2
        clean_eeg[start:end] = clean_segment[transition // 2: len(clean_segment) - transition // 2]

    # ===== 增强可视化 =====
    if visualize:
        plt.figure(figsize=(20, 18))  # 增加高度

        # 原始信号和长时差分
        plt.subplot(5, 1, 1)
        plt.plot(eeg, label='Original EEG')
        plt.legend(loc='upper right')
        plt.title('Step1: Raw EEG Signal', pad=20)  # 增加标题与图的间距

        # 长时差分信号
        plt.subplot(5, 1, 2)
        plt.plot(diff_eeg, color='orange', label='Long-term Differential')
        plt.title('Step2: Differential Signal (k={} samples)'.format(k), pad=20)
        plt.legend(loc='upper right')

        # 滤波过程可视化
        plt.subplot(5, 1, 3)
        time_downsampled = np.arange(len(downsampled)) * M
        plt.plot(time_downsampled, original_filtered, '--', label='Before delay compensation')
        plt.plot(time_downsampled, filtered[:len(downsampled)], label='After delay compensation')
        plt.title('Step3: Filtering Process (Delay={} samples)'.format(delay), pad=20)
        plt.legend(loc='upper right')

        # 振幅包络和阈值
        plt.subplot(5, 1, 4)
        plt.plot(envelope, label='Amplitude Envelope')
        plt.axhline(Th, color='r', linestyle='--', label='High Threshold (Th)')
        plt.axhline(Tl, color='g', linestyle='--', label='Low Threshold (Tl)')
        for s, e in valid_intervals:
            plt.axvspan(s, e, alpha=0.2, color='red')
        plt.title('Step4: Envelope with Dual Thresholds', pad=20)
        plt.legend(loc='upper right')

        # 最终结果
        plt.subplot(5, 1, 5)
        plt.plot(eeg, label='Raw EEG')
        plt.plot(clean_eeg, label='Cleaned EEG')
        plt.title('Step5: Final Result', pad=20)
        plt.legend(loc='upper right')

        # 调整子图间距
        plt.subplots_adjust(hspace=1)  # 增加子图间的垂直间距

        # 第二个图形
        plt.figure(figsize=(20, 5))
        plt.plot(eeg, label='Original')
        plt.plot(clean_eeg, label='Processed')
        plt.title('Original vs Processed EEG Signal')
        plt.xlabel('Samples')

        plt.show()
    return clean_eeg


def find_intervals(signal):
    """寻找连续True区间的起止点"""
    state = False
    starts = []
    ends = []

    for i, val in enumerate(signal):
        if val and not state:
            starts.append(i)
            state = True
        elif not val and state:
            ends.append(i - 1)
            state = False
    if state:
        ends.append(len(signal) - 1)

    return starts, ends


