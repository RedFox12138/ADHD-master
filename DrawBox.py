import os
import glob
import numpy as np
import matplotlib.pyplot as plt
from scipy.io import loadmat

from PreProcess import compute_power_ratio

# Get patient and healthy files
patient_files = glob.glob('D:/Matlab/bin/Ning/Prj_DATA/ADHD/*.mat')  # Note forward slashes for Python
healthy_files = glob.glob('D:/Matlab/bin/Ning/Prj_DATA/HT/*.mat')

# Define sampling rate and window parameters
Fs = 100  # Sampling rate 100Hz
window_length = 2 * Fs  # 2-second window (200 samples)
overlap = window_length // 2  # Half overlap

# Band definitions
theta_band = [4, 8]  # Theta band 4-8Hz
beta_band = [13, 21]  # Beta band 13-21Hz

# Storage arrays
all_patient_ratios = []  # To store patient power ratios (each row is a subject, columns are channels)
all_healthy_ratios = []  # To store healthy power ratios

# Process patient data
for i, file_path in enumerate(patient_files):
    print(f"Processing patient file {i + 1}/{len(patient_files)}")
    data = loadmat(file_path)
    eeg_data = data['data']  # Assuming EEG is stored in 'data' variable
    patient_temp = []

    # For each channel
    for ch in range(eeg_data.shape[0]):
        power_ratios = []

        # For each window
        for start_idx in range(0, eeg_data.shape[1] - window_length + 1, window_length - overlap):
            end_idx = start_idx + window_length
            window_data = eeg_data[ch, start_idx:end_idx]
            power_ratios.append(compute_power_ratio(window_data, Fs, theta_band, beta_band))

        # Store mean ratio for this channel
        patient_temp.append(np.mean(power_ratios))

    all_patient_ratios.append(patient_temp)

# Process healthy data
for i, file_path in enumerate(healthy_files):
    print(f"Processing healthy file {i + 1}/{len(healthy_files)}")
    data = loadmat(file_path)
    eeg_data = data['data']  # Assuming EEG is stored in 'data' variable
    healthy_temp = []

    # For each channel
    for ch in range(eeg_data.shape[0]):
        power_ratios = []

        # For each window
        for start_idx in range(0, eeg_data.shape[1] - window_length + 1, window_length - overlap):
            end_idx = start_idx + window_length
            window_data = eeg_data[ch, start_idx:end_idx]
            power_ratios.append(compute_power_ratio(window_data, Fs, theta_band, beta_band))

        # Store mean ratio for this channel
        healthy_temp.append(np.mean(power_ratios))

    all_healthy_ratios.append(healthy_temp)

# Convert to numpy arrays for easier handling
all_patient_ratios = np.array(all_patient_ratios)
all_healthy_ratios = np.array(all_healthy_ratios)

# Plot boxplots
n_channels = eeg_data.shape[0]
plt.figure(figsize=(15, 5))

for ch in range(n_channels):
    plt.subplot(1, n_channels, ch + 1)

    # Combine data for this channel
    combined_data = [all_patient_ratios[:, ch], all_healthy_ratios[:, ch]]

    # Create boxplot
    plt.boxplot(combined_data, labels=['Patient', 'Healthy'])
    plt.title(f'Channel {ch + 1}')
    plt.xlabel('Group')
    plt.ylabel('Theta/Beta Power Ratio')

plt.tight_layout()
plt.show()