import os
import glob
import numpy as np
import matplotlib.pyplot as plt
from scipy.io import loadmat

from CeemdanWave import ceemdan_eeg_artifact_removal
from PlotFreq import PlotFreq
from PreProcess import compute_power_ratio, preprocess, compute_power_ratio2, preprocess3, preprocess1
from SingleDenoise_pro import remove_eog_with_visualization2

# Get patient and healthy files
# patient_files = glob.glob('D:/Matlab/bin/Ning/Prj_DATA/ADHD/*.mat')  # Note forward slashes for Python
# healthy_files = glob.glob('D:/Matlab/bin/Ning/Prj_DATA/HT/*.mat')
#
# # Define sampling rate and window parameters
# Fs = 100  # Sampling rate 100Hz
# window_length = 2 * Fs  # 2-second window (200 samples)
# overlap = window_length   # Half overlap
#
# # Band definitions
# theta_band = [4, 8]  # Theta band 4-8Hz
# beta_band = [13, 21]  # Beta band 13-21Hz
#
# # Storage arrays
# all_patient_ratios = []  # To store patient power ratios (each row is a subject, columns are channels)
# all_healthy_ratios = []  # To store healthy power ratios
#
# # Process patient data
# for i, file_path in enumerate(patient_files):
#     print(f"Processing patient file {i + 1}/{len(patient_files)}")
#     data = loadmat(file_path)
#     eeg_data = data['data']  # Assuming EEG is stored in 'data' variable
#     patient_temp = []
#
#     # For each channel
#     for ch in range(eeg_data.shape[0]):
#         power_ratios = []
#
#         # For each window
#         for start_idx in range(0, eeg_data.shape[1] - window_length + 1, overlap):
#             end_idx = start_idx + window_length
#             window_data = eeg_data[ch, start_idx:end_idx]
#             power_ratios.append(compute_power_ratio(window_data, Fs, theta_band, beta_band))
#
#         # Store mean ratio for this channel
#         patient_temp.append(np.mean(power_ratios))
#
#     all_patient_ratios.append(patient_temp)
#
# # Process healthy data
# for i, file_path in enumerate(healthy_files):
#     print(f"Processing healthy file {i + 1}/{len(healthy_files)}")
#     data = loadmat(file_path)
#     eeg_data = data['data']  # Assuming EEG is stored in 'data' variable
#     healthy_temp = []
#
#     # For each channel
#     for ch in range(eeg_data.shape[0]):
#         power_ratios = []
#
#         # For each window
#         for start_idx in range(0, eeg_data.shape[1] - window_length + 1, overlap):
#             end_idx = start_idx + window_length
#             window_data = eeg_data[ch, start_idx:end_idx]
#             power_ratios.append(compute_power_ratio(window_data, Fs, theta_band, beta_band))
#
#         # Store mean ratio for this channel
#         healthy_temp.append(np.mean(power_ratios))
#
#     all_healthy_ratios.append(healthy_temp)
#
# # Convert to numpy arrays for easier handling
# all_patient_ratios = np.array(all_patient_ratios)
# all_healthy_ratios = np.array(all_healthy_ratios)
#
# # Plot boxplots
# n_channels = eeg_data.shape[0]
# plt.figure(figsize=(15, 5))
#
# for ch in range(n_channels):
#     plt.subplot(1, n_channels, ch + 1)
#
#     # Combine data for this channel
#     combined_data = [all_patient_ratios[:, ch], all_healthy_ratios[:, ch]]
#
#     # Create boxplot
#     plt.boxplot(combined_data, labels=['Patient', 'Healthy'])
#     plt.title(f'Channel {ch + 1}')
#     plt.xlabel('Group')
#     plt.ylabel('Theta/Beta Power Ratio')
#
# plt.tight_layout()
# plt.show()


# Define file path (assuming single file now)
data_file = 'data/oksQL7aHWZ0qkXkFP-oC05eZugE8/0417/0417 XY头顶风景画移动+心算1.txt'
eeg_data = np.loadtxt(data_file)

# 参数设置
Fs = 250
window_length = 2 * Fs
overlap = window_length   # 50%重叠

# 频段定义
theta_band = [4, 8]
alpha_band = [8, 12]
beta_band = [13, 21]

# 阶段定义
phases = [
    {"name": "Phase 1", "start": 10, "end": 70},
    {"name": "Phase 2", "start": 80, "end": 140},
    {"name": "Phase 3", "start": 80, "end": 140},
    # {"name": "Phase 3", "start": 150, "end": 210}
]

# 存储结果
results = {
    "TBR": {phase["name"]: [] for phase in phases},
    "TAR": {phase["name"]: [] for phase in phases},
    "ABR": {phase["name"]: [] for phase in phases}
}

# eeg_data = preprocess(eeg_data, Fs)

# 处理数据
for phase in phases:
    start_idx = int(phase["start"] * Fs)
    end_idx = int(phase["end"] * Fs)

    for start in range(start_idx, end_idx - window_length + 1, overlap):
        window = eeg_data[start: start + window_length]
        # PlotFreq(window,250)
        window= preprocess(window, Fs)
        # PlotFreq(window, 250)
        # plt.show()
        # window, _ = remove_eog_with_visualization2(window, 250, 0, 0)
        # window =  ceemdan_eeg_artifact_removal(window,250,sample_entropy_threshold=0.2)

        # 计算各功率比
        results["TBR"][phase["name"]].append(compute_power_ratio(window, Fs, theta_band, beta_band))
        # results["TBR"][phase["name"]].append(compute_power_ratio2(window, Fs, theta_band, beta_band,alpha_band))
        results["TAR"][phase["name"]].append(compute_power_ratio2(window, Fs, theta_band, alpha_band,alpha_band))
        results["ABR"][phase["name"]].append(compute_power_ratio2(window, Fs, alpha_band, beta_band,alpha_band))

# 绘制箱型图
plt.figure(figsize=(15, 5))

# TBR
plt.subplot(1, 3, 1)
plt.boxplot([results["TBR"]["Phase 1"], results["TBR"]["Phase 2"], results["TBR"]["Phase 3"]],
            labels=["Phase 1", "Phase 2", "Phase 3"])
plt.title("Theta/Beta Ratio (TBR)")
plt.ylabel("Power Ratio")
plt.grid(True, linestyle='--', alpha=0.6)

# TAR
plt.subplot(1, 3, 2)
plt.boxplot([results["TAR"]["Phase 1"], results["TAR"]["Phase 2"], results["TAR"]["Phase 3"]],
            labels=["Phase 1", "Phase 2", "Phase 3"])
plt.title("Theta/Alpha Ratio (TAR)")
plt.grid(True, linestyle='--', alpha=0.6)

# ABR
plt.subplot(1, 3, 3)
plt.boxplot([results["ABR"]["Phase 1"], results["ABR"]["Phase 2"], results["ABR"]["Phase 3"]],
            labels=["Phase 1", "Phase 2", "Phase 3"])
plt.title("Alpha/Beta Ratio (ABR)")
plt.grid(True, linestyle='--', alpha=0.6)

plt.tight_layout()
plt.show()