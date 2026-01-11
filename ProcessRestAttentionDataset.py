"""
处理mat文件中的静息和注意力数据
进行预处理、眼电去除和滑动窗口分割
每个mat文件单独处理，静息和注意力样本分别存储在cell中

重要说明：
1. 眼电去除使用DATNet模型，该模型是全卷积网络（FCN），支持可变长度输入
2. 但要求输入长度必须能被8整除（因为有3次下采样：2^3=8）
3. 处理流程：完整信号预处理 → 眼电去除 → 多窗口分割
   这样眼电去除在完整信号上进行，效果更好
4. 不同窗口大小会自动保存到不同的子目录（2s, 4s, 6s, 8s）
"""

import numpy as np
import os
from scipy.io import loadmat, savemat
from PreProcess import preprocess3
from EOGRemovalDATNet import eog_removal_datnet
import matplotlib.pyplot as plt
from matplotlib import rcParams

from SingleDenoise_CORRECTED import eog_removal_corrected

# 设置中文字体和绘图风格
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun', 'KaiTi', 'FangSong']
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams['font.family'] = 'sans-serif'
try:
    plt.style.use('seaborn-v0_8-darkgrid')
except:
    plt.style.use('seaborn-darkgrid')


def plot_signal_comparison(original_signal, processed_signal, cleaned_signal, 
                           filename, stage_name, fs=250, output_folder='figures'):
    """
    保存原始信号和处理后信号到独立的mat文件，供MATLAB绘图
    :param original_signal: 原始信号
    :param processed_signal: 预处理后信号
    :param cleaned_signal: 去眼电后信号（实际上就是processed_signal）
    :param filename: 文件名
    :param stage_name: 阶段名称（静息/注意力）
    :param fs: 采样率(Hz)
    :param output_folder: mat文件保存文件夹
    """
    # 创建输出文件夹
    os.makedirs(output_folder, exist_ok=True)
    
    # 保存完整的信号数据（移除30秒限制）
    original_save = original_signal
    processed_save = processed_signal
    
    # 确保信号是float64类型，fs是float类型
    original_save = np.asarray(original_save, dtype=np.float64)
    processed_save = np.asarray(processed_save, dtype=np.float64)
    fs_value = float(fs)
    
    # 保存原始信号到mat文件
    base_name = os.path.splitext(filename)[0]
    original_mat = os.path.join(output_folder, f"{base_name}_{stage_name}_original.mat")
    savemat(original_mat, {'signal': original_save, 'fs': fs_value})
    
    # 保存处理后信号到mat文件
    processed_mat = os.path.join(output_folder, f"{base_name}_{stage_name}_processed.mat")
    savemat(processed_mat, {'signal': processed_save, 'fs': fs_value})
    
    print(f"    -> 原始信号已保存: {original_mat}")
    print(f"    -> 处理后信号已保存: {processed_mat}")


def sliding_window_split(signal, window_size, step_size):
    """
    使用滑动窗口切分信号
    :param signal: 输入信号
    :param window_size: 窗口大小（采样点数）
    :param step_size: 步长（采样点数）
    :return: 切分后的窗口列表
    
    注意：由于DATNet模型有3次下采样，窗口大小必须能被8整除
    """
    # 确保窗口大小能被8整除（DATNet要求）
    if window_size % 8 != 0:
        original_size = window_size
        window_size = (window_size // 8) * 8
        print(f"      警告: 窗口大小{original_size}不能被8整除，已调整为{window_size}")
    
    windows = []
    start = 0
    
    while start + window_size <= len(signal):
        window = signal[start:start + window_size]
        windows.append(window)
        start += step_size
    
    return windows


def process_single_stage(signal, stage_name, filename, fs=250, visualize=True, output_folder='figures'):
    """
    处理单个阶段的信号（静息或注意力）：预处理 + 眼电去除
    :param signal: 输入信号
    :param stage_name: 阶段名称（用于日志输出）
    :param filename: 文件名（用于图像保存）
    :param fs: 采样率(Hz)
    :param visualize: 是否生成可视化图像
    :param output_folder: 图像保存文件夹
    :return: 处理后的完整信号（去眼电后）
    """
    if len(signal) == 0:
        print(f"  {stage_name}阶段数据为空，跳过处理")
        return None
    
    print(f"  {stage_name}阶段长度: {len(signal)} 个点 ({len(signal)/fs:.2f}秒)")
    
    try:
        # 步骤1: 预处理
        print(f"    -> 正在进行预处理...")
        processed_signal, _ = preprocess3(signal, fs)
        

        print(f"    -> 正在去除眼电（DATNet无监督网络）...")
        # cleaned_signal = eog_removal_datnet(processed_signal, fs, visualize=False)
        cleaned_signal = eog_removal_corrected(processed_signal, fs, visualize=False)



        # 可视化对比
        if visualize:
            print(f"    -> 正在生成可视化图像...")
            plot_signal_comparison(signal, processed_signal, cleaned_signal,
                                 filename, stage_name, fs, output_folder)
        
        print(f"    -> 预处理和眼电去除完成")
        
        return cleaned_signal
        
    except Exception as e:
        print(f"  {stage_name}阶段处理失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return None


def process_and_save_mat_file(mat_path, output_folder, fs=250, window_durations=[2, 4, 6, 8], 
                             step_duration=2, visualize=True, figure_folder='figures'):
    """
    处理单个mat文件并保存为同名的新mat文件
    :param mat_path: 输入mat文件路径
    :param output_folder: 输出文件夹路径
    :param fs: 采样率(Hz)
    :param window_durations: 窗口时长列表(秒)，默认为[2, 4, 6, 8]
    :param step_duration: 步长时长(秒)
    :param visualize: 是否生成可视化图像
    :param figure_folder: 图像保存文件夹
    :return: 是否成功处理
    """
    # 读取mat文件
    try:
        mat_data = loadmat(mat_path)
        rest_stage = mat_data['rest_stage'].flatten()
        attention_stage = mat_data['attention_stage'].flatten()
    except Exception as e:
        print(f"读取文件失败 {mat_path}: {str(e)}")
        return False
    
    # 获取文件名
    filename = os.path.basename(mat_path)
    base_name = os.path.splitext(filename)[0]
    
    # 只处理一次预处理和眼电去除（对完整信号）
    print(f"  处理静息阶段...")
    rest_cleaned = process_single_stage(rest_stage, "静息", filename, fs, 
                                       visualize=visualize, output_folder=figure_folder)
    
    print(f"  处理注意力阶段...")
    attention_cleaned = process_single_stage(attention_stage, "注意力", filename, fs, 
                                            visualize=visualize, output_folder=figure_folder)
    
    # 保存预处理后的完整信号到根目录
    if rest_cleaned is not None or attention_cleaned is not None:
        full_output_path = os.path.join(output_folder, f"{base_name}_full.mat")
        full_save_dict = {}
        if rest_cleaned is not None:
            full_save_dict['rest_stage'] = rest_cleaned
        if attention_cleaned is not None:
            full_save_dict['attention_stage'] = attention_cleaned
        
        savemat(full_output_path, full_save_dict)
        print(f"  已保存预处理后完整信号到: {full_output_path}")
        if rest_cleaned is not None:
            print(f"    - 静息完整信号: {rest_cleaned.shape}")
        if attention_cleaned is not None:
            print(f"    - 注意力完整信号: {attention_cleaned.shape}")
    
    # 对每个窗口大小进行分割并保存到对应的子目录
    # 注意：步长固定为2秒（500个点），不随窗口大小变化
    any_success = False
    step_size = int(step_duration * fs)  # 固定步长：2秒 = 500个点
    
    for window_duration in window_durations:
        print(f"  \n  处理窗口大小: {window_duration}秒 (步长固定{step_duration}秒)")
        
        # 创建对应窗口大小的子目录
        window_folder = os.path.join(output_folder, f"{window_duration}s")
        os.makedirs(window_folder, exist_ok=True)
        
        # 计算窗口大小
        window_size = int(window_duration * fs)
        
        # 对预处理后的完整信号进行滑动窗口切分
        rest_windows = []
        attention_windows = []
        
        if rest_cleaned is not None:
            rest_windows = sliding_window_split(rest_cleaned, window_size, step_size)
            print(f"    -> 静息阶段切分出 {len(rest_windows)} 个窗口 (窗长{window_duration}s, 步长{step_duration}s)")
        
        if attention_cleaned is not None:
            attention_windows = sliding_window_split(attention_cleaned, window_size, step_size)
            print(f"    -> 注意力阶段切分出 {len(attention_windows)} 个窗口 (窗长{window_duration}s, 步长{step_duration}s)")
        
        # 保存分割后的样本
        if len(rest_windows) > 0 or len(attention_windows) > 0:
            output_path = os.path.join(window_folder, filename)
            
            # 转换为numpy矩阵
            rest_samples = np.array(rest_windows) if len(rest_windows) > 0 else np.array([])
            attention_samples = np.array(attention_windows) if len(attention_windows) > 0 else np.array([])
            
            # 保存为mat文件
            save_dict = {}
            if len(rest_windows) > 0:
                save_dict['rest_samples'] = rest_samples
            if len(attention_windows) > 0:
                save_dict['attention_samples'] = attention_samples
            
            savemat(output_path, save_dict)
            print(f"    -> 已保存到: {output_path}")
            if len(rest_windows) > 0:
                print(f"       静息样本: {rest_samples.shape}")
            if len(attention_windows) > 0:
                print(f"       注意力样本: {attention_samples.shape}")
            
            any_success = True
    
    return any_success


def batch_process_rest_attention_dataset(input_folder, output_folder, fs=250, 
                                        window_durations=[2, 4, 6, 8], step_duration=2, 
                                        visualize=True, figure_folder='figures'):
    """
    批量处理文件夹中的所有mat文件
    每个mat文件单独保存为同名的新mat文件，并按不同窗口大小保存到子目录
    :param input_folder: 输入文件夹路径（包含原始mat文件）
    :param output_folder: 输出文件夹路径（保存处理后的mat文件）
    :param fs: 采样率(Hz)
    :param window_durations: 窗口时长列表(秒)，默认为[2, 4, 6, 8]
    :param step_duration: 步长时长(秒)
    :param visualize: 是否生成可视化图像
    :param figure_folder: 图像保存文件夹
    """
    # 确保输出文件夹存在
    os.makedirs(output_folder, exist_ok=True)
    
    # 遍历文件夹中的所有mat文件
    mat_files = [f for f in os.listdir(input_folder) if f.endswith('.mat')]
    total_files = len(mat_files)
    
    if total_files == 0:
        print("未找到任何mat文件！")
        return
    
    print(f"找到 {total_files} 个mat文件")
    print(f"处理设置: 窗长={window_durations}秒, 步长={step_duration}秒")
    print(f"预处理方法: preprocess3")
    print(f"眼电去除方法: DATNet无监督网络 (eog_removal_datnet)")
    print(f"可视化: {'开启' if visualize else '关闭'}")
    if visualize:
        print(f"图像保存文件夹: {figure_folder}")
    print(f"输入文件夹: {input_folder}")
    print(f"输出文件夹: {output_folder}")
    print(f"将生成子目录: {[f'{w}s' for w in window_durations]}")
    print("=" * 60)
    
    success_count = 0
    
    for idx, filename in enumerate(mat_files, 1):
        mat_path = os.path.join(input_folder, filename)
        print(f"\n[{idx}/{total_files}] 处理: {filename}")
        
        try:
            if process_and_save_mat_file(mat_path, output_folder, fs, 
                                        window_durations, step_duration, 
                                        visualize, figure_folder):
                success_count += 1
        except Exception as e:
            print(f"  处理失败: {str(e)}")
            import traceback
            traceback.print_exc()
    
    print("\n" + "=" * 60)
    print(f"处理完成！")
    print(f"成功处理文件数: {success_count}/{total_files}")
    print(f"输出文件保存在: {output_folder}")
    if visualize:
        print(f"图像文件保存在: {figure_folder}")


# 使用示例
if __name__ == "__main__":
    # 配置参数
    input_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\总和\\总和的mat'  # 包含原始mat文件的文件夹
    output_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\总和\\总和的mat\\预处理处理后的mat'  # 输出文件夹
    figure_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\总和\\figures'  # 图像保存文件夹
    
    # 采样率和窗口参数
    fs = 250  # 采样率 250Hz
    
    # 窗口时长列表（秒）
    # 注意：DATNet模型要求输入长度能被8整除（3次下采样: 2^3=8）
    # - 2秒 = 500点 → 自动调整为 496点 (1.984秒)
    # - 4秒 = 1000点 → ✓ 可直接使用
    # - 6秒 = 1500点 → 自动调整为 1496点 (5.984秒)
    # - 8秒 = 2000点 → ✓ 可直接使用
    window_durations = [2, 4, 6, 8]
    
    step_duration = 2  # 步长 2秒
    visualize = True  # 可视化标志位: True=生成图像, False=不生成图像
    
    # 批量处理
    batch_process_rest_attention_dataset(
        input_folder=input_folder,
        output_folder=output_folder,
        fs=fs,
        window_durations=window_durations,
        step_duration=step_duration,
        visualize=visualize,
        figure_folder=figure_folder
    )
