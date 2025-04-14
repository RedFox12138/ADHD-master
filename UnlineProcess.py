import sys
import time

from CeemdanWave import ceemdan_eeg_artifact_removal
from Entropy import SampleEntropy2
from PlotFreq import PlotFreq
from PreProcess import preprocess, compute_power_ratio
from SingleDenoise import remove_eog_with_visualization
from SingleDenoise_pro import remove_eog_with_visualization2
import scipy.io as sio
#python库的路径
sys.path.append('D:\\anaconda\\lib\\site-packages')
import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
import numpy as np
from scipy import signal
import matplotlib.pyplot as plt
import numpy as np
import pywt

"""
   该代码用于处理一次脑电实验的txt或者mat时序数据，展示功率比随着时间的变化
"""


# 定义频段
BANDS = ['delta', 'theta', 'alpha', 'beta']
BAND_RANGES = {
    'delta': (0.5, 4),
    'theta': (3, 11),
    'alpha': (8, 13),
    'beta': (10, 36)
}

def design_cheby2_bandpass(lowcut, highcut, fs, order=5, rs=40):
    """设计切比雪夫II型带通滤波器"""
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    b, a = signal.cheby2(order, rs, [low, high], btype='band')
    return b, a


def compute_band_power2(data, band, fs):
    """计算特定频段的功率"""
    lowcut, highcut = BAND_RANGES[band]
    b, a = design_cheby2_bandpass(lowcut, highcut, fs)
    # 应用滤波器
    filtered_data = signal.filtfilt(b, a, data)
    # power = SampleEntropy2(filtered_data,0.2)
    power = np.mean(filtered_data **  2)
    return power

def wave_packet_three_level(x):
    mother_wavelet = 'db4'
    wp = pywt.WaveletPacket(data=x, wavelet=mother_wavelet, maxlevel=5)
    rec_results = []
    for i in ['aaaaa', 'aaaad', 'aaadd', 'aaada','aad', 'add', 'ada','d']:
        new_wp = pywt.WaveletPacket(data=np.zeros(len(x)), wavelet=mother_wavelet,maxlevel=5)
        new_wp[i] = wp[i].data
        x_i = new_wp.reconstruct(update=True)
        rec_results.append(x_i)
        output = np.array(rec_results)
    return output

def compute_band_powers(data):
    """计算所有频段的功率"""
    powers = {}
    for band in BANDS:
        powers[band] = compute_band_power2(data, band, fs)
    # 计算theta/beta比值
    powers['theta_beta_ratio'] = powers['theta'] / powers['beta'] if powers['beta'] > 0 else 0
    return powers


# 加载数据
eeg = np.loadtxt('data/oksQL7aHWZ0qkXkFP-oC05eZugE8/0411 XY额头干电极3min 2.txt')
fs = 250  # 采样率


# eeg = np.squeeze(sio.loadmat('D:\\Matlab\\bin\\Ning\\Prj_DATA\\ADHD\\1.mat')['data'])
# eeg = eeg.astype(np.float64)  # 或者 np.float32
# fs = 100

window_size = fs * 2 # 2秒窗口（500个点）

# 分窗处理
num_windows = len(eeg) // window_size
band_power_history = {band: [] for band in BANDS}
band_power_history['theta_beta_ratio'] = []

sampleEntropy=[]
for i in range(num_windows):
    seg = eeg[i * window_size: (i + 1) * window_size]

    # seg ,_= preprocess1(seg, 250)
    seg= preprocess(seg, 250)


    t = time.time()
    seg,_ = remove_eog_with_visualization2(seg,250,0,0)
    # seg =  ceemdan_eeg_artifact_removal(seg,250,sample_entropy_threshold=0.2,draw_flag=1)
    print(f'coast:{time.time() - t:.4f}s')

    # powers = compute_band_powers(seg)
    powers = compute_power_ratio(seg,fs,[4, 8],[13, 21])
    # sampleEntropy.append(SampleEntropy2(seg,0.2))

    # 存储结果
    # for band in BANDS:
    #     band_power_history[band].append(powers[band])
    # band_power_history['theta_beta_ratio'].append(powers['theta_beta_ratio'])
    band_power_history['theta_beta_ratio'].append(powers)

# 可视化结果（5个子图垂直排列）
plt.figure(figsize=(12, 12))
colors = {'delta': 'blue', 'theta': 'green', 'alpha': 'orange', 'beta': 'red'}

# 绘制各频段功率
# for i, band in enumerate(BANDS):
#     plt.subplot(5, 1, i + 1)
#     plt.plot(band_power_history[band], '.-', color=colors[band])
#     plt.ylabel(f'{band} power (μV²)')
#     plt.title(f'{band} band ({BAND_RANGES[band][0]}-{BAND_RANGES[band][1]}Hz) power')
#     plt.grid(True)

# 添加θ/β比值到最后一个子图
band_power_history['theta_beta_ratio'] = band_power_history['theta_beta_ratio'][2:-2]

plt.figure()
x = np.arange(len(band_power_history['theta_beta_ratio']))
y = band_power_history['theta_beta_ratio']

# 绘制原始数据点
plt.plot(x, y, 'm.-', label='θ/β ratio')

if len(x) > 3:  # 确保有足够的数据点进行拟合
    x = np.array(x)
    y = np.array(y)

    # 计算残差
    coeffs = np.polyfit(x, y, 3)
    poly = np.poly1d(coeffs)
    y_pred = poly(x)
    residuals = y - y_pred

    # 计算 IQR 并筛选非离群点
    Q1 = np.percentile(residuals, 25)
    Q3 = np.percentile(residuals, 75)
    IQR = Q3 - Q1
    lower_bound = Q1 - 1.5 * IQR
    upper_bound = Q3 + 1.5 * IQR

    mask = (residuals >= lower_bound) & (residuals <= upper_bound)
    x_filtered = x[mask]  # 现在不会报错，因为 x 是 NumPy 数组
    y_filtered = y[mask]  # 同理

    # 重新拟合
    if len(x_filtered) > 3:
        coeffs = np.polyfit(x_filtered, y_filtered, 3)
        poly = np.poly1d(coeffs)
        y_fit = poly(x_filtered)
        plt.plot(x_filtered, y_fit, 'b-', linewidth=2, label='Trend')
        plt.scatter(x[~mask], y[~mask], color='red', marker='o', label='Outliers')
        plt.legend()

plt.ylabel('θ/β ratio')
plt.xlabel('Windows (time/2s)')
plt.title('Theta/Beta ratio')
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.show()