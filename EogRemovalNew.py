import numpy as np
import pywt
import matplotlib.pyplot as plt
from scipy import signal
from scipy.io import loadmat

from CeemdanWave import ewt_decomposition


def load_eeg_data(file_path):
    """加载EEG数据"""
    data = loadmat(file_path)
    eeg = data['eeg_data'].flatten()  # 假设数据存储在'eeg_data'字段中
    return eeg


def plot_signals(original, processed, title, fs=250):
    """绘制原始和处理后的信号"""
    plt.figure(figsize=(15, 6))

    # 时间轴
    t = np.arange(len(original)) / fs

    plt.subplot(2, 1, 1)
    plt.plot(t, original)
    plt.title(f'Original Signal - {title}')
    plt.xlabel('Time (s)')
    plt.ylabel('Amplitude (μV)')

    plt.subplot(2, 1, 2)
    plt.plot(t, processed)
    plt.title(f'Processed Signal - {title}')
    plt.xlabel('Time (s)')
    plt.ylabel('Amplitude (μV)')

    plt.tight_layout()
    plt.show()


import numpy as np
import matplotlib.pyplot as plt
import pywt
from scipy import signal

#去眼电的系数是 level 6    low 0.6   high 1.5  thresh两个值是1.5 2.5
def optimized_dwt_eog_removal(eeg_signal, fs=250, wavelet='coif3', level=10,
                              low_threshold_scale=0.8, high_threshold_scale=1.2,
                              visualize=False):
    """
    使用优化的DWT方法去除眼电伪迹，基于文献研究结果改进
    首先使用EWT将信号分解为低频和高频部分，对低频部分进行小波去噪，
    对高频部分进行轻微去噪，最后再合成

    参数:
        eeg_signal: 输入的EEG信号
        fs: 采样频率(Hz)
        wavelet: 使用的小波基(推荐'coif3'或'bior4.4')
        level: 分解层数(推荐8层以覆盖0.25-64Hz)
        low_threshold_scale: 低频部分阈值缩放因子
        high_threshold_scale: 高频部分阈值缩放因子(更宽松)
        visualize: 是否可视化中间步骤

    返回:
        denoised_signal: 去除眼电后的EEG信号
        metrics: 包含各种性能指标的字典
    """
    # 保存原始信号用于后续计算
    raw_signal = eeg_signal.copy()

    # 1. 使用EWT分解信号为低频和高频部分
    ewt_components, _ = ewt_decomposition(eeg_signal, fs)
    low_freq = ewt_components[0]  # 低频部分
    high_freq = ewt_components[1]  # 高频部分

    # 可视化EWT分解结果
    if visualize:
        plt.figure(figsize=(15, 6))
        plt.subplot(2, 1, 1)
        plt.plot(raw_signal)
        plt.plot(low_freq)
        plt.title('EWT Low Frequency Component')
        plt.xlabel('Samples')
        plt.ylabel('Amplitude (μV)')

        plt.subplot(2, 1, 2)
        plt.plot(high_freq)
        plt.title('EWT High Frequency Component')
        plt.xlabel('Samples')
        plt.ylabel('Amplitude (μV)')
        plt.tight_layout()
        plt.show()

    # 2. 对低频部分进行小波去噪
    # 参数校验
    if len(low_freq) < 2 ** level:
        raise ValueError(f"信号长度({len(low_freq)})不足以支持{level}层分解(需要至少{2 ** level}点)")

    # 小波分解
    coeffs = pywt.wavedec(low_freq, wavelet, level=level)

    # 计算统计阈值(ST)并应用
    processed_coeffs = [coeffs[0]]  # 保留近似系数

    for i in range(1, len(coeffs)):
        # 计算统计阈值(ST)
        if i >= 3:  # 只对level 3及以上(8-16Hz)的细节系数应用更严格的阈值
            thresh = 3 * np.std(coeffs[i]) * low_threshold_scale
        else:  # 对高频部分(16-64Hz)应用更宽松的阈值
            thresh = 4 * np.std(coeffs[i]) * low_threshold_scale

        # 应用硬阈值(文献表明硬阈值效果更好)
        processed_coeff = pywt.threshold(coeffs[i], thresh, mode='hard')
        processed_coeffs.append(processed_coeff)

    # 小波重构
    denoised_low_freq = pywt.waverec(processed_coeffs, wavelet)
    denoised_low_freq = denoised_low_freq[:len(low_freq)]  # 确保长度一致

    # 3. 对高频部分进行轻微的小波去噪
    # 使用较少的分解层数和更宽松的阈值
    high_level = min(5, level - 2)  # 减少分解层数
    if len(high_freq) < 2 ** high_level:
        high_level = int(np.log2(len(high_freq))) - 1

    if high_level > 0:
        # 小波分解
        high_coeffs = pywt.wavedec(high_freq, wavelet, level=high_level)

        # 计算统计阈值(ST)并应用 - 使用更宽松的阈值
        processed_high_coeffs = [high_coeffs[0]]  # 保留近似系数

        for i in range(1, len(high_coeffs)):
            thresh = np.std(high_coeffs[i]) * high_threshold_scale
            # 应用软阈值(对高频部分更温和)
            processed_coeff = pywt.threshold(high_coeffs[i], thresh, mode='soft')
            processed_high_coeffs.append(processed_coeff)

        # 小波重构
        denoised_high_freq = pywt.waverec(processed_high_coeffs, wavelet)
        denoised_high_freq = denoised_high_freq[:len(high_freq)]  # 确保长度一致
    else:
        denoised_high_freq = high_freq.copy()

    # 4. 将去噪后的低频部分与去噪后的高频部分重新合成
    final_signal = raw_signal - denoised_low_freq -denoised_high_freq

    # # 5. 计算性能指标
    # removed_artifacts = raw_signal - final_signal
    #
    # # 计算相关系数(CC)
    # cc = np.corrcoef(raw_signal, final_signal)[0, 1]
    #
    # # 计算信号伪迹比(SAR)
    # sar = 10 * np.log10(np.std(raw_signal) ** 2 / np.std(removed_artifacts) ** 2)
    #
    # # 计算归一化均方误差(NMSE)
    # nmse = 20 * np.log10(np.sum((raw_signal - final_signal) ** 2) / np.sum(raw_signal ** 2))
    #
    # metrics = {
    #     'correlation_coefficient': cc,
    #     'signal_to_artifact_ratio': sar,
    #     'normalized_mse': nmse
    # }

    # 6. 可视化结果
    if visualize:
        # 绘制处理前后信号对比
        plt.figure(figsize=(15, 10))

        # 原始信号和去噪信号
        plt.subplot(4, 1, 1)
        plt.plot(raw_signal, label='Original')
        plt.plot(final_signal, label='Processed')
        plt.title('Original vs Processed EEG Signal')
        plt.xlabel('Samples')
        plt.ylabel('Amplitude (μV)')
        plt.legend()

        # # 去除的伪迹
        # plt.subplot(4, 1, 2)
        # plt.plot(removed_artifacts)
        # plt.title('Removed Artifacts (EOG components)')
        # plt.xlabel('Samples')
        # plt.ylabel('Amplitude (μV)')

        # 频谱对比
        plt.subplot(4, 1, 3)
        f_orig, Pxx_orig = signal.welch(raw_signal, fs=fs, nperseg=1024)
        f_proc, Pxx_proc = signal.welch(final_signal, fs=fs, nperseg=1024)
        plt.semilogy(f_orig, Pxx_orig, label='Original')
        plt.semilogy(f_proc, Pxx_proc, label='Processed')
        plt.title('Power Spectrum Comparison')
        plt.xlabel('Frequency [Hz]')
        plt.ylabel('Power Spectral Density [V**2/Hz]')
        plt.xlim([0, 30])
        plt.grid()
        plt.legend()

        # 高频部分去噪前后对比
        plt.subplot(4, 1, 4)
        plt.plot(high_freq, label='Original High Freq')
        plt.plot(denoised_high_freq, label='Denoised High Freq')
        plt.title('High Frequency Component Before/After Denoising')
        plt.xlabel('Samples')
        plt.ylabel('Amplitude (μV)')
        plt.legend()

        plt.figure()
        plt.plot(raw_signal, label='Original')
        plt.plot(final_signal, label='Processed')
        plt.title('Original vs Processed EEG Signal')
        plt.xlabel('Samples')
        plt.ylabel('Amplitude (mV)')
        plt.legend()

        plt.tight_layout()
        plt.show()

        # # 打印性能指标
        # print("Performance Metrics:")
        # print(f"Correlation Coefficient: {cc:.4f}")
        # print(f"Signal-to-Artifact Ratio (SAR): {sar:.2f} dB")
        # print(f"Normalized MSE: {nmse:.2f} dB")

    return final_signal

