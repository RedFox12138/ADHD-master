import numpy as np
import matplotlib.pyplot as plt
from scipy.fft import fft, ifft
from pyemd import CEEMDAN

from Entropy import SampleEntropy2, sample_entropy
from PlotFreq import PlotFreq

"""
   该代码用于EWT和模态分解法进行眼电预处理
"""


def ewt_decomposition(signal, fs, cutoff_freq=4):
    """
    Empirical Wavelet Transform (EWT) decomposition with improved frequency handling

    Parameters:
        signal (array): Input EEG signal
        fs (float): Sampling frequency
        cutoff_freq (float): Cutoff frequency in Hz (default=4)

    Returns:
        tuple: (ewt_components, mfb) where:
            ewt_components: list of decomposed components
            mfb: empirical wavelet filter bank
    """
    N = len(signal)
    f_actual = np.fft.fftfreq(N, 1/fs)  # Correct frequency axis including negative frequencies

    # Compute FFT of the signal
    fft_signal = fft(signal)

    # Initialize filter bank using actual frequencies
    mfb = []
    # Low-pass filter (|f| <= cutoff_freq)
    low_pass_mask = (np.abs(f_actual) <= cutoff_freq).astype(float)
    mfb.append(low_pass_mask)
    # High-pass filter (|f| > cutoff_freq)
    high_pass_mask = (np.abs(f_actual) > cutoff_freq).astype(float)
    mfb.append(high_pass_mask)

    # Apply filter bank
    ewt_components = []
    for k in range(2):
        # Frequency domain filtering
        filtered_fft = fft_signal * mfb[k]

        # Inverse FFT to get time domain signal (ensure real output)
        component = ifft(filtered_fft)
        ewt_components.append(np.real(component))

    return ewt_components, mfb

    # # Visualization (optional)
    # plt.figure(figsize=(10, 8))
    #
    # plt.subplot(3, 1, 1)
    # plt.plot(np.arange(N) / fs, signal)
    # plt.title('Original Signal')
    # plt.xlabel('Time (s)')
    # plt.ylabel('Amplitude')
    #
    # plt.subplot(3, 1, 2)
    # plt.plot(np.arange(N) / fs, ewt_components[0])
    # plt.title(f'0-{cutoff_freq} Hz Component')
    # plt.xlabel('Time (s)')
    # plt.ylabel('Amplitude')
    #
    # plt.subplot(3, 1, 3)
    # plt.plot(np.arange(N) / fs, ewt_components[1])
    # plt.title(f'>{cutoff_freq} Hz Component')
    # plt.xlabel('Time (s)')
    # plt.ylabel('Amplitude')
    #
    # plt.tight_layout()
    # plt.show()

    return ewt_components, mfb


def ceemdan_eeg_artifact_removal(raw_eeg, fs, cutoff_freq=4,
                                 sample_entropy_threshold=0.4,
                                 Nstd=0.2, NR=500, MaxIter=10,draw_flag=0):
    """
    EEG artifact removal using EWT, CEEMDAN, and Sample Entropy

    Parameters:
        raw_eeg (array): Raw EEG signal
        fs (float): Sampling frequency
        cutoff_freq (float): EWT cutoff frequency (default=4Hz)
        sample_entropy_threshold (float): Threshold for identifying artifacts (default=0.4)
        Nstd (float): Noise standard deviation for CEEMDAN (default=0.2)
        NR (int): Number of realizations for CEEMDAN (default=500)
        MaxIter (int): Maximum iterations for CEEMDAN (default=2000)

    Returns:
        array: Cleaned EEG signal
    """
    # Step 1: EWT Decomposition
    ewt_components, _ = ewt_decomposition(raw_eeg, fs, cutoff_freq)
    low_freq_component = ewt_components[0]  # 0-4Hz component
    high_freq_component = ewt_components[1]  # >4Hz component

    # Step 2: CEEMDAN Decomposition of low frequency component
    ceemdan = CEEMDAN()
    imfs = ceemdan.ceemdan(low_freq_component, max_imf=MaxIter)

    num_modes = imfs.shape[0]

    if(draw_flag==1):
        # Optional visualization of IMFs with sample entropy in legend
        plt.figure(figsize=(10, 8))
        plt.subplot(num_modes + 2, 1, 1)
        plt.plot(raw_eeg)
        plt.title('Original EEG Signal')
        plt.ylabel('Amplitude')

        plt.subplot(num_modes + 2, 1, 2)
        plt.plot(low_freq_component)
        plt.title('0-4Hz Low Frequency Component')
        plt.ylabel('Amplitude')

    # Pre-calculate sample entropy for all IMFs before plotting
    sampen_values = []
    for i in range(num_modes):
        # sampen_result = SampleEntropy2(imfs[i], r=0.2)
        sampen_result = sample_entropy(imfs[i],2,0.2)
        sampen_values.append(sampen_result)

    if(draw_flag==1):
        for i in range(num_modes):
            plt.subplot(num_modes + 2, 1, 3 + i)
            plt.plot(imfs[i], label=f'SampEn: {sampen_values[i]:.4f}')
            plt.title(f'IMF {i + 1}')
            plt.ylabel('Amplitude')
            plt.legend(loc='upper right')  # Add legend with sample entropy value

        plt.xlabel('Samples')
        plt.tight_layout()
        plt.show()

    # Step 3: Calculate sample entropy for each IMF and identify artifacts
    clean_imfs = []
    for i in range(num_modes):
        samp_en = sampen_values[i]  # Use pre-calculated values

        print(f'IMF {i + 1} Sample Entropy: {samp_en:.4f}')

        # If sample entropy > threshold, keep the IMF
        if samp_en > sample_entropy_threshold:
            clean_imfs.append(imfs[i])
        else:
            print(f'IMF {i + 1} identified as artifact and removed')

    # Step 4: Reconstruct the signal
    # Reconstruct low frequency component (after artifact removal)
    if clean_imfs:
        reconstructed_low = np.sum(clean_imfs, axis=0)
    else:
        reconstructed_low = np.zeros_like(low_freq_component)
        print('Warning: All low frequency IMFs identified as artifacts')

    # Combine with high frequency component for final result
    result = reconstructed_low + high_freq_component

    if (draw_flag == 1):
        # Final visualization
        plt.figure(figsize=(10, 8))

        plt.subplot(3, 1, 1)
        plt.plot(raw_eeg)
        plt.title('Original EEG Signal')
        plt.ylabel('Amplitude')

        plt.subplot(3, 1, 2)
        plt.plot(low_freq_component - reconstructed_low)
        plt.title('Identified Artifacts')
        plt.ylabel('Amplitude')

        plt.subplot(3, 1, 3)
        plt.plot(result)
        plt.title('Cleaned EEG Signal')
        plt.xlabel('Samples')
        plt.ylabel('Amplitude')

        plt.tight_layout()
        plt.show()

    return result