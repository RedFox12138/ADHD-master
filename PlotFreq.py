import numpy as np
from matplotlib import pyplot as plt
from scipy.signal import welch

"""
   该代码用于画频谱图
"""
def PlotFreq(data, fs=250, label=None, ax=None, color=None):
    """计算并绘制信号的功率谱密度"""
    f, Pxx = welch(data, fs=fs, nperseg=256)
    Pxx_db = 10 * np.log10(Pxx)

    if ax is None:
        ax = plt.gca()

    ax.plot(f, Pxx_db, label=label, color=color)
    ax.set_xlabel('Frequency (Hz)')
    ax.set_ylabel('Power Spectral Density (dB)')
    ax.grid(True)
    return ax


