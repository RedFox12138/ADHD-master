import numpy as np
import matplotlib.pyplot as plt
from scipy.fft import fft, ifft
from PyEMD import CEEMDAN

from Entropy import SampleEntropy2, sample_entropy
from PlotFreq import PlotFreq

"""
   该代码用于EWT和模态分解法进行眼电预处理
"""


def ewt_decomposition(signal, fs, cutoff_freq=12, transition_width=1.0):
    """
    Enhanced Empirical Wavelet Transform (EWT) decomposition with smooth transition

    Parameters:
        signal (array): Input EEG signal
        fs (float): Sampling frequency (Hz)
        cutoff_freq (float): Cutoff frequency in Hz (default=12)
        transition_width (float): Transition band width in Hz (default=1.0)

    Returns:
        tuple: (ewt_components, mfb) where:
            ewt_components: list of decomposed components [low_freq, high_freq]
            mfb: empirical wavelet filter bank
    """
    N = len(signal)
    if N == 0:
        raise ValueError("Input signal cannot be empty")

    # Generate frequency axis (correct for both even and odd N)
    f_actual = np.fft.fftfreq(N, 1 / fs)
    f_abs = np.abs(f_actual)

    # Compute FFT
    fft_signal = fft(signal)

    # Create smooth transition filters
    def smooth_transition(f, fc, bw):
        """Create smooth transition mask using raised cosine window"""
        return 0.5 * (1 + np.cos(np.pi * np.clip((f - fc) / bw + 0.5, 0, 1)))

    # Low-pass filter with smooth transition
    low_pass_mask = np.zeros_like(f_abs)
    transition_start = cutoff_freq - transition_width / 2
    transition_end = cutoff_freq + transition_width / 2

    # Apply smooth transitions
    idx_full_pass = f_abs <= transition_start
    idx_transition = (f_abs > transition_start) & (f_abs < transition_end)

    low_pass_mask[idx_full_pass] = 1.0
    low_pass_mask[idx_transition] = smooth_transition(
        f_abs[idx_transition], transition_start, transition_width)

    # High-pass filter is complement of low-pass
    high_pass_mask = 1 - low_pass_mask

    # Store filter bank
    mfb = [low_pass_mask, high_pass_mask]

    # Apply filter bank
    ewt_components = []
    for mask in mfb:
        filtered_fft = fft_signal * mask
        component = ifft(filtered_fft)
        ewt_components.append(np.real_if_close(component))

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