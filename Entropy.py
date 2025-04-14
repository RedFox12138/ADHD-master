import EntropyHub as EH
import numpy as np


"""
   该程序实现了两种样本熵的计算方式
"""

def SampleEntropy2(Datalist, r, m=2):
    th = r * np.std(Datalist)  # 容限阈值
    return EH.SampEn(Datalist, m, r=th)

def sample_entropy(time_series, m, r):

    N = len(time_series)
    # 数据标准化
    mean = np.mean(time_series)
    std = np.std(time_series)
    time_series = (time_series - mean) / std
    def _phi(m):
        x = np.array([time_series[i:i + m] for i in range(N - m + 1)])
        C = np.sum(np.max(np.abs(x[:, np.newaxis] - x[np.newaxis, :]), axis=2) <= r, axis=0) - 1
        return np.sum(C) / (N - m + 1)
    return -np.log(_phi(m + 1) / _phi(m))

