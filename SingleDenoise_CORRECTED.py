import numpy as np
import matplotlib.pyplot as plt
import pywt
from scipy.signal import firwin, lfilter, filtfilt
from scipy.ndimage import gaussian_filter1d


def find_intervals(binary_array):
    """查找二值数组中的连续True区间"""
    diff = np.diff(np.concatenate(([False], binary_array, [False])).astype(int))
    starts = np.where(diff == 1)[0]
    ends = np.where(diff == -1)[0]
    return starts, ends


def eog_removal_corrected(eeg, fs=250, visualize=False, removal_ratio=0.85):
    """
    单通道脑电信号眼电去除函数 - 改进版（平滑去除）
    
    参考文献: 《单通道脑电信号中眼电干扰的自动分离方法》
    
    参数：
        eeg : 输入脑电信号（1D数组）
        fs : 采样率（默认250Hz）
        visualize : 是否显示处理过程（默认False）
        removal_ratio : 眼电去除比例，0-1之间，默认0.72（去除72%）
    返回：
        clean_eeg : 去除眼电后的脑电信号
    """
    # ===== 第1步：长时差分计算 =====
    # 文献: k = 0.2*fs (约200ms窗口)
    k = int(0.2 * fs)
    diff_eeg = np.zeros_like(eeg)
    diff_eeg[k:] = eeg[k:] - eeg[:-k]

    # ===== 第2步：振幅包络提取 =====
    # 平方和降采样
    M = 8  # 文献中的降采样因子
    squared = diff_eeg ** 2
    downsampled = squared[::M]

    # 低通滤波（FIR滤波器，零相位）
    # 文献: 21阶FIR滤波器, 4Hz截止频率
    N = 21
    cutoff = 4 / (fs / M / 2)  # 归一化截止频率
    h = firwin(N, cutoff, window='hamming')
    
    # 使用零相位滤波
    filtered = filtfilt(h, [1.0], downsampled)

    # 上采样恢复原始长度并开方
    upsampled = np.repeat(np.maximum(filtered, 0), M)[:len(eeg)]
    envelope = np.sqrt(upsampled)

    # ===== 第3步：双门限眼电检测 =====
    # 文献: 使用中位数绝对偏差(MAD)计算阈值
    env_med = np.median(envelope)
    env_mad = np.median(np.abs(envelope - env_med))
    
    # 标准化MAD
    sigma = env_mad / 0.6745 if env_mad > 0 else np.std(envelope)
    
    # 文献中的阈值设置
    Th = env_med + 3.0 * sigma  # 高阈值
    Tl = env_med + 0.5 * sigma  # 低阈值
    
    print(f"[阈值检测] 中位数:{env_med:.4f}, σ:{sigma:.4f}, Th:{Th:.4f}, Tl:{Tl:.4f}")

    # ⚠️ 修正1: 使用高阈值Th进行初检,而不是固定值1
    thresholded = envelope > Th  # ✅ 修正
    starts, ends = find_intervals(thresholded)

    # 扩展检测区间（使用低阈值Tl）
    valid_intervals = []
    for s, e in zip(starts, ends):
        # 向前扩展
        new_s = s
        while new_s > 0 and envelope[new_s] > Tl:
            new_s -= 1
        
        # 向后扩展
        new_e = e
        while new_e < len(envelope) - 1 and envelope[new_e] > Tl:
            new_e += 1
        
        # 文献: 去除持续时间短于50ms的区间
        if (new_e - new_s) > int(0.05 * fs):
            valid_intervals.append((new_s, new_e))

    # 合并相邻区间（间隔<200ms）
    def merge_intervals(intervals, max_gap):
        if not intervals:
            return []
        intervals = sorted(intervals, key=lambda x: x[0])
        merged = []
        cur_s, cur_e = intervals[0]
        for ns, ne in intervals[1:]:
            if ns - cur_e <= max_gap:
                cur_e = max(cur_e, ne)
            else:
                merged.append((cur_s, cur_e))
                cur_s, cur_e = ns, ne
        merged.append((cur_s, cur_e))
        return merged

    final_intervals = merge_intervals(valid_intervals, max_gap=int(0.2 * fs))
    print(f"[区间检测] 检测到 {len(final_intervals)} 个眼电伪迹区间")

    # ===== 第4步：小波变换眼电分离 =====
    wavelet = 'sym5'  # 文献使用sym5小波
    desired_level = 8  # 文献: 8层分解
    clean_eeg = eeg.copy()

    w = pywt.Wavelet(wavelet)

    for idx, (s, e) in enumerate(final_intervals):
        win_len = e - s
        # 增加更大的重叠以改善边界平滑度
        overlap = min(int(0.5 * fs), max(int(0.3 * win_len), int(0.1 * fs)))
        s_ext = max(0, s - overlap)
        e_ext = min(len(eeg), e + overlap)

        segment = eeg[s_ext:e_ext]
        N_segment = len(segment)

        # 计算最大分解层数
        max_level = pywt.dwt_max_level(N_segment, w.dec_len)
        if max_level < 1:
            print(f"[警告] 区间{idx+1}太短,跳过处理")
            continue
        
        level = min(desired_level, max_level)

        # 小波分解
        coeffs = pywt.wavedec(segment, w, level=level)

        # 文献核心算法: 通过硬阈值提取眼电成分
        new_coeffs = [coeffs[0]]  # 保留近似系数
        
        for j in range(1, len(coeffs)):
            # 文献公式(4): α = 2.5 (j<3), α = 2.0 (j≥3)
            # 调整alpha使其更保守
            alpha = 2.0 if j < 3 else 1.5
            
            # 文献公式(3) - n应该用原始信号长度N
            n = int(N_segment / (level + 2 - j) ** alpha)
            n = max(0, min(n, len(coeffs[j]) - 1))

            # 计算通用阈值 (文献公式5)
            coeff_abs = np.abs(coeffs[j])
            sigma_j = np.median(coeff_abs) / 0.6745 if np.any(coeff_abs != 0) else 0.0
            # 降低通用阈值系数，从sqrt(2*log(n))降低到1.5倍sigma
            universal_thr = sigma_j * 1.5

            # 计算BM阈值 (Birgé-Massart阈值,文献公式3)
            sorted_coeff = np.sort(coeff_abs)[::-1]
            bm_thr = sorted_coeff[n] if n < len(sorted_coeff) else 0.0
            
            # 取两者最小值，并再降低20%使其更保守
            thr = min(bm_thr, universal_thr) * 0.8

            # 使用软阈值替代硬阈值，使过渡更平滑
            new_c = pywt.threshold(coeffs[j], value=thr, mode='soft') if sigma_j > 0 else coeffs[j]
            new_coeffs.append(new_c)
            
            print(f"  区间{idx+1} 层{j}: n={n}, σ={sigma_j:.4f}, BM_thr={bm_thr:.4f}, U_thr={universal_thr:.4f}, 采用={thr:.4f}")

        # 重构得到眼电伪迹估计
        eog_estimate = pywt.waverec(new_coeffs, w)
        
        # 长度对齐
        if len(eog_estimate) > len(segment):
            eog_estimate = eog_estimate[:len(segment)]
        elif len(eog_estimate) < len(segment):
            eog_estimate = np.pad(eog_estimate, (0, len(segment) - len(eog_estimate)), mode='edge')

        # ===== 改进的边界平滑处理 =====
        # 1. 创建平滑的Tukey窗（余弦渐变窗），边缘更平滑
        taper_ratio = min(0.5, overlap / len(segment))  # 渐变区域占比
        taper_len = int(taper_ratio * len(segment))
        
        # Tukey窗：中间为1，两端为余弦渐变
        taper_window = np.ones(len(segment))
        if taper_len > 0:
            # 左侧渐变：从0到1
            left_taper = 0.5 * (1 + np.cos(np.linspace(np.pi, 2*np.pi, taper_len)))
            # 右侧渐变：从1到0  
            right_taper = 0.5 * (1 + np.cos(np.linspace(0, np.pi, taper_len)))
            
            taper_window[:taper_len] = left_taper
            taper_window[-taper_len:] = right_taper

        # 2. 自适应眼电去除强度：根据包络强度调整去除比例
        # 在核心区域(s到e)完全去除，边界区域逐渐减弱
        removal_strength = np.ones(len(segment))
        
        # 计算当前段相对于起止位置的去除强度
        core_start = s - s_ext  # 核心区域起点（相对segment）
        core_end = e - s_ext    # 核心区域终点
        
        # 在重叠区域创建渐变的去除强度
        for i in range(len(segment)):
            if i < core_start:
                # 左侧渐变区：强度从0到1
                removal_strength[i] = i / max(core_start, 1)
            elif i > core_end:
                # 右侧渐变区：强度从1到0
                removal_strength[i] = max(0, (len(segment) - i) / max(len(segment) - core_end, 1))
            # else: 核心区域保持1
        
        # 平滑去除强度曲线
        if len(removal_strength) > 5:
            from scipy.ndimage import gaussian_filter1d
            removal_strength = gaussian_filter1d(removal_strength, sigma=min(20, len(removal_strength)//10))
        
        # 3. 应用自适应眼电去除
        # clean = original - (eog_estimate * removal_ratio * removal_strength * taper)
        # 只去除部分眼电，而不是全部，使结果更自然
        clean_segment = segment - (eog_estimate * removal_ratio * removal_strength * taper_window)

        # 3.5 对去除后的片段进行平滑处理，消除尖峰
        # 使用轻微的移动平均滤波，只在核心处理区域应用
        from scipy.signal import savgol_filter
        if len(clean_segment) > 50:
            # 使用Savitzky-Golay滤波器进行平滑，保持信号形状
            # 减小窗口长度，降低平滑强度
            window_length = min(21, len(clean_segment) if len(clean_segment) % 2 == 1 else len(clean_segment) - 1)
            if window_length >= 5:
                # 创建一个平滑权重：只在核心区域轻微应用平滑
                smooth_weight = np.zeros(len(segment))
                # 降低平滑强度到0.3，保留更多原始信号特征
                smooth_weight[core_start:core_end] = 0.3
                
                # 在边界区域渐变
                transition_len = min(taper_len // 2, 30)
                if transition_len > 0:
                    # 左边界渐入
                    left_start = max(0, core_start - transition_len)
                    smooth_weight[left_start:core_start] = np.linspace(0, 0.3, core_start - left_start)
                    # 右边界渐出
                    right_end = min(len(segment), core_end + transition_len)
                    smooth_weight[core_end:right_end] = np.linspace(0.3, 0, right_end - core_end)
                
                # 应用Savitzky-Golay滤波
                try:
                    smoothed = savgol_filter(clean_segment, window_length, polyorder=2)
                    # 混合原始和平滑的信号，只应用30%的平滑
                    clean_segment = clean_segment * (1 - smooth_weight) + smoothed * smooth_weight
                except:
                    pass  # 如果滤波失败，保持原样

        # 4. 改进的边界融合：使用交叉淡入淡出
        # 计算实际需要替换的区域
        actual_start = max(0, s_ext)
        actual_end = min(len(eeg), e_ext)
        seg_len = actual_end - actual_start
        
        if seg_len > 0 and seg_len <= len(clean_segment):
            # 提取对应的清洁片段
            clean_to_apply = clean_segment[:seg_len]
            
            # 创建融合权重：边界处平滑过渡
            blend_weight = np.ones(seg_len)
            fade_len = min(taper_len, seg_len // 4)
            
            if fade_len > 0:
                # 左边界淡入
                if actual_start > 0:
                    blend_weight[:fade_len] = np.linspace(0, 1, fade_len)
                # 右边界淡出
                if actual_end < len(eeg):
                    blend_weight[-fade_len:] = np.linspace(1, 0, fade_len)
            
            # 应用融合
            clean_eeg[actual_start:actual_end] = (
                clean_to_apply * blend_weight + 
                clean_eeg[actual_start:actual_end] * (1 - blend_weight)
            )

    # ===== 可视化 =====
    if visualize:
        plt.figure(figsize=(20, 16))

        # 1. 原始信号
        plt.subplot(5, 1, 1)
        plt.plot(eeg, label='Original EEG', linewidth=1)
        plt.title('Step 1: Original EEG Signal', fontsize=14, pad=15)
        plt.ylabel('Amplitude (μV)')
        plt.legend(loc='upper right')
        plt.grid(alpha=0.3)

        # 2. 长时差分
        plt.subplot(5, 1, 2)
        plt.plot(diff_eeg, color='orange', label=f'Long-term Differential (k={k})', linewidth=1)
        plt.title('Step 2: Long-term Differential Signal', fontsize=14, pad=15)
        plt.ylabel('Amplitude')
        plt.legend(loc='upper right')
        plt.grid(alpha=0.3)

        # 3. 振幅包络
        plt.subplot(5, 1, 3)
        plt.plot(envelope, label='Amplitude Envelope (4Hz LPF)', linewidth=1.5, color='purple')
        plt.title('Step 3: Amplitude Envelope', fontsize=14, pad=15)
        plt.ylabel('Envelope')
        plt.legend(loc='upper right')
        plt.grid(alpha=0.3)

        # 4. 双门限检测
        plt.subplot(5, 1, 4)
        plt.plot(envelope, label='Envelope', linewidth=1, color='purple')
        plt.axhline(Th, color='r', linestyle='--', linewidth=2, label=f'High Threshold (Th={Th:.2f})')
        plt.axhline(Tl, color='g', linestyle='--', linewidth=2, label=f'Low Threshold (Tl={Tl:.2f})')
        
        # 标注检测区间
        for idx, (s, e) in enumerate(final_intervals):
            plt.axvspan(s, e, alpha=0.3, color='red', label='EOG Artifact' if idx == 0 else '')
        
        plt.title('Step 4: Dual-Threshold EOG Detection', fontsize=14, pad=15)
        plt.ylabel('Envelope')
        plt.legend(loc='upper right')
        plt.grid(alpha=0.3)

        # 5. 最终结果对比
        plt.subplot(5, 1, 5)
        plt.plot(eeg, label='Original EEG', alpha=0.6, linewidth=1)
        plt.plot(clean_eeg, label='Cleaned EEG', linewidth=1.5, color='green')
        
        # 标注处理区间
        for s, e in final_intervals:
            plt.axvspan(s, e, alpha=0.2, color='yellow')
        
        plt.title('Step 5: Final Result (Original vs Cleaned)', fontsize=14, pad=15)
        plt.xlabel('Samples')
        plt.ylabel('Amplitude (μV)')
        plt.legend(loc='upper right')
        plt.grid(alpha=0.3)

        plt.tight_layout()
        plt.show()

    return clean_eeg


# 辅助函数
def compare_implementations(eeg, fs=250):
    """对比原实现和修正后的实现"""
    from SingleDenoise import eog_removal
    
    print("="*60)
    print("对比原实现 vs 修正实现")
    print("="*60)
    
    print("\n[原实现]")
    result_old = eog_removal(eeg, fs, visualize=False)
    
    print("\n[修正实现]")
    result_new = eog_removal_corrected(eeg, fs, visualize=False)
    
    # 计算差异
    diff = np.abs(result_old - result_new)
    print(f"\n[差异统计]")
    print(f"  最大差异: {np.max(diff):.4f}")
    print(f"  平均差异: {np.mean(diff):.4f}")
    print(f"  差异标准差: {np.std(diff):.4f}")
    
    # 可视化对比
    plt.figure(figsize=(15, 8))
    
    plt.subplot(3, 1, 1)
    plt.plot(eeg, label='Original', alpha=0.7)
    plt.plot(result_old, label='Old Implementation', alpha=0.7)
    plt.title('Original Implementation')
    plt.legend()
    plt.grid(alpha=0.3)
    
    plt.subplot(3, 1, 2)
    plt.plot(eeg, label='Original', alpha=0.7)
    plt.plot(result_new, label='Corrected Implementation', alpha=0.7)
    plt.title('Corrected Implementation')
    plt.legend()
    plt.grid(alpha=0.3)
    
    plt.subplot(3, 1, 3)
    plt.plot(diff, label='Absolute Difference', color='red')
    plt.title('Difference between Two Implementations')
    plt.xlabel('Samples')
    plt.ylabel('Amplitude')
    plt.legend()
    plt.grid(alpha=0.3)
    
    plt.tight_layout()
    plt.show()
    
    return result_old, result_new


if __name__ == '__main__':
    # 测试代码
    print("单通道眼电去除算法 - 文献修正版")
    print("加载测试数据...")
    
    # 你可以用自己的数据替换
    # eeg = np.load('your_eeg_data.npy')
    
    # 或者生成模拟数据
    fs = 250
    t = np.arange(0, 10, 1/fs)
    eeg = np.sin(2*np.pi*10*t) + 0.5*np.random.randn(len(t))
    
    # 添加模拟眼电伪迹
    eeg[500:700] += 5 * np.sin(2*np.pi*2*t[500:700])
    
    print(f"信号长度: {len(eeg)} 采样点 ({len(eeg)/fs:.1f}秒)")
    print(f"采样率: {fs} Hz")
    
    # 运行修正算法
    clean_eeg = eog_removal_corrected(eeg, fs, visualize=True)
    
    print("\n处理完成!")
