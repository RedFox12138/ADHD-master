import os
import glob
import numpy as np
import matplotlib.pyplot as plt
from scipy.io import loadmat

from PreProcess import compute_power_ratio

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
data_file = 'data/oksQL7aHWZ0qkXkFP-oC05eZugE8/0409 XY额头干电极3min 1.txt'  # Or .mat if still using mat files

# Define sampling rate and window parameters
Fs = 250  # Sampling rate 100Hz
window_length = 2 * Fs  # 2-second window (200 samples)
overlap = window_length  # Half overlap

# Band definitions
theta_band = [4, 8]  # Theta band 4-8Hz
beta_band = [13, 21]  # Beta band 13-21Hz

# 阶段定义（单位：秒）
phases = [
    {"name": "Phase 1", "start": 5, "end": 65},  # 10-70秒
    {"name": "Phase 2", "start": 70, "end": 130},  # 80-140秒
    {"name": "Phase 3", "start": 135, "end": 195}  # 150-210秒
]

# 加载TXT数据（假设是单列时序数据）
eeg_data = np.loadtxt(data_file)  # 如果数据是多列，可能需要调整

# 存储每个阶段的功率比
phase_ratios = {phase["name"]: [] for phase in phases}

# 处理每个阶段
for phase in phases:
    start_idx = int(phase["start"] * Fs)
    end_idx = int(phase["end"] * Fs)

    # 滑动窗口计算功率比
    for start in range(start_idx, end_idx - window_length + 1, overlap):
        window = eeg_data[start: start + window_length]
        ratio = compute_power_ratio(window, Fs, theta_band, beta_band)
        phase_ratios[phase["name"]].append(ratio)

# 绘制箱型图对比三个阶段
plt.figure(figsize=(8, 5))
plt.boxplot([phase_ratios["Phase 1"], phase_ratios["Phase 2"], phase_ratios["Phase 3"]],
            labels=["Phase 1", "Phase 2", "Phase 3"])
plt.title("Theta/Beta Power Ratio Comparison (Single Channel)")
plt.xlabel("Experimental Phase")
plt.ylabel("Power Ratio (Theta/Beta)")
plt.grid(True, linestyle='--', alpha=0.6)
plt.tight_layout()
plt.show()