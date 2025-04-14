import time

import numpy as np
import scipy.io as sio
from matplotlib import pyplot as plt
from scipy.signal import butter, filtfilt, welch
from scipy.stats import pearsonr

from CeemdanWave import ceemdan_eeg_artifact_removal
from PreProcess import preprocess
from SingleDenoise_pro import remove_eog_with_visualization2

"""
   该代码用于对公开数据集进行眼电去噪的方法对比与指标计算
"""


def compute_band_energy(f, Pxx, band_range):
    low, high = band_range
    mask = (f >= low) & (f <= high)
    return np.sum(Pxx[mask]) * (f[1] - f[0])

def get_ER(signal, fs):
    f, Pxx = welch(signal, fs=fs, nperseg=400, detrend='constant')
    bands = {
        'delta': (0.5, 4),
        'theta': (4, 8),
        'alpha': (8, 13),
        'beta': (13, 30),
        'gamma': (30, 40)
    }
    energies = {name: compute_band_energy(f, Pxx, band) for name, band in bands.items()}
    total = sum(energies.values())
    er_delta = energies['delta'] / total if total != 0 else 0
    return er_delta

def compute_mae_psd(clean_signal, result_signal, band_range, fs):
    f_clean, Pxx_clean = welch(clean_signal, fs=fs, nperseg=400, detrend='constant')
    f_result, Pxx_result = welch(result_signal, fs=fs, nperseg=400, detrend='constant')
    low, high = band_range
    mask = (f_clean >= low) & (f_clean <= high)
    return np.mean(np.abs(Pxx_clean[mask] - Pxx_result[mask]))


def bandpass_filter(signal, lowcut, highcut, fs, order=4):
    """
    巴特沃斯带通滤波器
    :param signal: 输入信号
    :param lowcut: 低频截止频率(Hz)
    :param highcut: 高频截止频率(Hz)
    :param fs: 采样频率(Hz)
    :param order: 滤波器阶数
    :return: 滤波后的信号
    """
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq

    # 设计巴特沃斯带通滤波器
    b, a = butter(order, [low, high], btype='band')

    # 使用零相位滤波
    return filtfilt(b, a, signal)

# 加载数据
mat_data = sio.loadmat('D:\\Matlab\\bin\\EOG\\Contaminated_Data.mat')
sample_names = [key for key in mat_data.keys()
                if not key.startswith('__') and key != 'sim2_resampled']
Clean_data = sio.loadmat('D:\\Matlab\\bin\\EOG\\Pure_Data.mat')
AllResult = sio.loadmat('D:\\Matlab\\bin\\EOG\\All_result.mat')['All_result']

fs = 200
results = []
i = 0

t = time.time()
# 遍历所有样本矩阵
for name in sample_names:
    print(f"Processing {name}...")
    # 加载污染信号和纯净信号
    contaminated_signal = mat_data[name][0, :]
    pure_signal = Clean_data[name[:-3] + "resampled"][0, :]

    # 预处理S
    contaminated_signal = preprocess(contaminated_signal, fs)
    pure_signal = preprocess(pure_signal, fs)

    # 去眼电伪迹（假设已实现）
    cleaned_signal, _ = remove_eog_with_visualization2(contaminated_signal, fs,0,1)
    # cleaned_signal = ceemdan_eeg_artifact_removal(contaminated_signal,200,sample_entropy_threshold=0.2,draw_flag=0)

    # cleaned_signal = np.squeeze(AllResult[i][0])
    # i = i+1

    # # # # 第一张图：含眼电伪迹信号 vs 去伪迹后信号
    # plt.figure(figsize=(10, 4))
    # plt.plot(contaminated_signal, label='Contaminated Signal (with EOG)', color='red', alpha=0.7)
    # plt.plot(cleaned_signal, label='Cleaned Signal', color='blue', linestyle='--')
    # plt.title('Comparison: Contaminated vs Cleaned EEG Signal (Fp1 Channel)')
    # plt.xlabel('Time (samples)')  # 假设采样率200Hz，可替换实际时间轴
    # plt.ylabel('Amplitude (μV)')  # 脑电信号常用单位
    # plt.legend()
    # plt.grid(True)
    #
    # # 第二张图：纯净信号 vs 去伪迹后信号
    # plt.figure(figsize=(10, 4))
    # plt.plot(pure_signal, label='Pure EEG Signal (no EOG)', color='green', alpha=0.7)
    # plt.plot(cleaned_signal, label='Cleaned Signal', color='blue', linestyle='--')
    # plt.title('Comparison: Pure vs Cleaned EEG Signal (Fp1 Channel)')
    # plt.xlabel('Time (samples)')
    # plt.ylabel('Amplitude (μV)')
    # plt.legend()
    # plt.grid(True)
    #
    # plt.tight_layout()  # 避免标签重叠
    # plt.show()


    # 计算评价指标
    # 1. 相关系数 (CC)
    cc = np.corrcoef(pure_signal, cleaned_signal)[0, 1]

    # 2. 相对均方根误差 (RRMSE)
    rrmse = np.sqrt(np.mean((pure_signal - cleaned_signal) ** 2)) / np.sqrt(np.mean(pure_signal ** 2))

    # 3. δ频段能量比变化 (ΔERδ)
    er_contaminated = get_ER(contaminated_signal, fs)
    er_cleaned = get_ER(cleaned_signal, fs)
    delta_er = (er_contaminated - er_cleaned) * 100  # 转换为百分比

    # 4. 各频段PSD平均绝对误差
    mae_delta = compute_mae_psd(pure_signal, cleaned_signal, (0.5, 4), fs)
    mae_theta = compute_mae_psd(pure_signal, cleaned_signal, (4, 8), fs)
    mae_alpha = compute_mae_psd(pure_signal, cleaned_signal, (8, 13), fs)
    mae_beta = compute_mae_psd(pure_signal, cleaned_signal, (13, 30), fs)

    results.append({
        'CC': cc,
        'RRMSE': rrmse,
        'Delta_ER': delta_er,
        'MAE_delta': mae_delta,
        'MAE_theta': mae_theta,
        'MAE_alpha': mae_alpha,
        'MAE_beta': mae_beta
    })

print(f'coast:{time.time() - t:.4f}s')

# 计算统计量
metrics = {
    'CC': {'mean': np.mean([res['CC'] for res in results]),
           'std': np.std([res['CC'] for res in results])},
    'RRMSE': {'mean': np.mean([res['RRMSE'] for res in results]),
              'std': np.std([res['RRMSE'] for res in results])},
    'Delta_ER': {'mean': np.mean([res['Delta_ER'] for res in results]),
                 'std': np.std([res['Delta_ER'] for res in results])},
    'MAE_delta': {'mean': np.mean([res['MAE_delta'] for res in results]),
                  'std': np.std([res['MAE_delta'] for res in results])},
    'MAE_theta': {'mean': np.mean([res['MAE_theta'] for res in results]),
                  'std': np.std([res['MAE_theta'] for res in results])},
    'MAE_alpha': {'mean': np.mean([res['MAE_alpha'] for res in results]),
                  'std': np.std([res['MAE_alpha'] for res in results])},
    'MAE_beta': {'mean': np.mean([res['MAE_beta'] for res in results]),
                 'std': np.std([res['MAE_beta'] for res in results])}
}

# 输出结果
print("\n最终评价指标（均值±标准差）：")
print(f"CC: {metrics['CC']['mean']:.4f} ± {metrics['CC']['std']:.4f}")
print(f"RRMSE: {metrics['RRMSE']['mean']:.4f} ± {metrics['RRMSE']['std']:.4f}")
print(f"ΔERδ (%): {metrics['Delta_ER']['mean']:.2f} ± {metrics['Delta_ER']['std']:.2f}")
print(f"MAE_delta: {metrics['MAE_delta']['mean']:.4f} ± {metrics['MAE_delta']['std']:.4f}")
print(f"MAE_theta: {metrics['MAE_theta']['mean']:.4f} ± {metrics['MAE_theta']['std']:.4f}")
print(f"MAE_alpha: {metrics['MAE_alpha']['mean']:.4f} ± {metrics['MAE_alpha']['std']:.4f}")
print(f"MAE_beta: {metrics['MAE_beta']['mean']:.4f} ± {metrics['MAE_beta']['std']:.4f}")

