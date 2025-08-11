import numpy as np
import matplotlib.pyplot as plt
from PyEMD import EEMD
import pywt
from scipy import signal

from PreProcess import preprocess3

# 加载并预处理信号
fs = 250  # 采样率
signal_with_eog = np.loadtxt("D:\\Pycharm_Projects\\ADHD-master\\data\\额头信号\\1\\0417 XY额头风景画移动+心算1.txt")
signal_with_eog, _ = preprocess3(signal_with_eog[1500:10000], fs)

# 1. 进行5层Sym5小波分解
wavelet = 'sym5'
level = 5
coeffs = pywt.wavedec(signal_with_eog, wavelet, level=level)

# 获取各层细节系数和近似系数
cA5, cD5, cD4, cD3, cD2, cD1 = coeffs

# 重构各层分量
reconstructed_signal = []
for i in range(level + 1):
    coeff_list = [np.zeros_like(c) for c in coeffs]
    coeff_list[i] = coeffs[i]
    reconstructed_signal.append(pywt.waverec(coeff_list, wavelet))

# 绘制小波分解结果
plt.figure(figsize=(12, 10))
plt.subplot(6, 1, 1)
plt.plot(reconstructed_signal[0], 'r')  # A5
plt.title('Approximation A5')
plt.subplot(6, 1, 2)
plt.plot(reconstructed_signal[1], 'g')  # D5
plt.title('Detail D5')
plt.subplot(6, 1, 3)
plt.plot(reconstructed_signal[2], 'g')  # D4
plt.title('Detail D4')
plt.subplot(6, 1, 4)
plt.plot(reconstructed_signal[3], 'g')  # D3
plt.title('Detail D3')
plt.subplot(6, 1, 5)
plt.plot(reconstructed_signal[4], 'g')  # D2
plt.title('Detail D2')
plt.subplot(6, 1, 6)
plt.plot(reconstructed_signal[5], 'g')  # D1
plt.title('Detail D1')
plt.tight_layout()
plt.show()

# 2. 对A5、D5、D4进行EEMD分解并只去除IMF4-6
components_to_process = [0, 1, 2]  # A5, D5, D4的索引
processed_components = []

for comp_idx in components_to_process:
    component = reconstructed_signal[comp_idx]

    # 初始化EEMD
    eemd = EEMD()
    eemd.trials = 20  # 集成次数
    eemd.noise_width = 0.2  # 噪声幅度

    # 执行EEMD分解
    IMFs = eemd(component)
    nIMFs = IMFs.shape[0]

    # 绘制EEMD结果
    plt.figure(figsize=(12, 8))
    plt.subplot(nIMFs + 1, 1, 1)
    plt.plot(component, 'r')
    plt.title(f'Original component ({["A5", "D5", "D4"][comp_idx]})')

    for i in range(nIMFs):
        plt.subplot(nIMFs + 1, 1, i + 2)
        plt.plot(IMFs[i], 'g')
        plt.title('IMF {}'.format(i + 1))

    plt.tight_layout()
    plt.show()

    # 只去除IMF5-7（索引4-6），保留其他所有IMF
    if nIMFs >= 7:
        # 保留IMF1-4和IMF8+（如果有的话）
        imfs_to_keep = np.vstack([IMFs[:4], IMFs[7:]]) if nIMFs > 7 else IMFs[:4]
        clean_component = np.sum(imfs_to_keep, axis=0)
    elif nIMFs >= 5:
        # 如果只有5-6个IMF，只去除IMF5+
        clean_component = np.sum(IMFs[:4], axis=0)
    else:
        # 如果IMF数量不足5个，保留所有
        clean_component = np.sum(IMFs, axis=0)

    processed_components.append(clean_component)

# 3. 重新合成信号
# 创建新的系数列表
new_coeffs = [None] * len(coeffs)

# 处理A5、D5、D4
new_coeffs[0] = pywt.downcoef('a', processed_components[0], wavelet, level=5)  # A5
new_coeffs[1] = pywt.downcoef('d', processed_components[1], wavelet, level=5)  # D5
new_coeffs[2] = pywt.downcoef('d', processed_components[2], wavelet, level=4)  # D4

# 保留未处理的D3、D2、D1
new_coeffs[3] = coeffs[3]  # D3
new_coeffs[4] = coeffs[4]  # D2
new_coeffs[5] = coeffs[5]  # D1

# 重构信号
clean_eeg = pywt.waverec(new_coeffs, wavelet)

# 4. 绘制结果对比
plt.figure(figsize=(12, 6))
plt.subplot(2, 1, 1)
plt.plot(signal_with_eog, 'b')
plt.title('Original Signal with EOG')
plt.subplot(2, 1, 2)
plt.plot(clean_eeg, 'r')
plt.title('Clean EEG Signal (IMF4-6 removed from A5/D5/D4)')
plt.tight_layout()
plt.show()

# 绘制频谱对比
plt.figure(figsize=(12, 6))
f_orig = np.fft.rfftfreq(len(signal_with_eog), 1 / fs)
plt.plot(f_orig, np.abs(np.fft.rfft(signal_with_eog)), 'b', label='Original')
f_clean = np.fft.rfftfreq(len(clean_eeg), 1 / fs)
plt.plot(f_clean, np.abs(np.fft.rfft(clean_eeg)), 'r', label='Clean')
plt.xlim(0, 30)  # 重点关注0-30Hz
plt.title('Frequency Spectrum Comparison (0-30Hz)')
plt.xlabel('Frequency (Hz)')
plt.ylabel('Magnitude')
plt.legend()
plt.tight_layout()
plt.show()