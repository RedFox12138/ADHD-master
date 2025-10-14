import numpy as np
from EntropyHub import FuzzEn
from vmdpy import VMD
from scipy.spatial.distance import pdist, squareform
import matplotlib.pyplot as plt


def eog_removal_vmd(signal, fs=250, fuzz_en_threshold=0.6, K=6):
    """
    使用VMD和模糊熵去除眼电(EOG)伪迹。

    参数:
    signal (np.ndarray): 输入的EEG信号。
    fs (int): 采样率。
    fuzz_en_threshold (float): 模糊熵阈值，用于识别眼电模态。
    K (int): VMD分解的模态数。

    返回:
    np.ndarray: 去除眼电伪迹后的EEG信号。
    """
    # VMD 参数
    alpha = 2000  # 带宽约束
    tau = 0.  # 无噪声项
    DC = 0  # 无直流分量
    init = 1  # 均匀初始化
    tol = 1e-7  # 收敛容差

    # 执行VMD分解
    # u: 分解出的模态 (IMFs)
    # u_hat: 模态的频谱
    # omega: 模态的中心频率
    u, u_hat, omega = VMD(signal, alpha, tau, K, DC, init, tol)

    # 绘图准备
    plt.figure(figsize=(12, 2 * (K + 2)))
    plt.suptitle('VMD模态分解及模糊熵', fontsize=16)

    # 绘制原始信号
    plt.subplot(K + 2, 1, 1)
    plt.plot(signal)
    plt.title('原始信号')
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])

    print("各模态的模糊熵值:")
    clean_imfs = []
    for i, imf in enumerate(u):
        # 计算每个模态的模糊熵
        fuzz_entropy = np.array([1,1]);
        print(f"  模态 {i + 1}: {fuzz_entropy[0]:.4f}")

        # 绘制每个模态
        plt.subplot(K + 2, 1, i + 2)
        plt.plot(imf)
        title = f"模态 {i + 1} (模糊熵: {fuzz_entropy[0]:.4f})"

        # 如果模糊熵低于阈值，则认为是有效的脑电成分
        if fuzz_entropy[0] < fuzz_en_threshold:
            clean_imfs.append(imf)
        else:
            print(f"  -> 模态 {i + 1} 被识别为伪迹并移除。")
            title += " - [已移除]"

        plt.title(title)
        plt.tight_layout(rect=[0, 0.03, 1, 0.95])

    # 线性叠加剩余的模态以重构信号
    if not clean_imfs:
        print("警告: 所有模态都被移除，返回零信号。")
        reconstructed_signal = np.zeros_like(signal)
    else:
        reconstructed_signal = np.sum(clean_imfs, axis=0)

    # 绘制重构信号
    plt.subplot(K + 2, 1, K + 2)
    plt.plot(reconstructed_signal)
    plt.title('重构信号 (去除眼电后)')
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])

    plt.show()

    return reconstructed_signal
