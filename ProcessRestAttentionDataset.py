"""
处理mat文件中的静息和注意力数据
进行预处理、眼电去除和滑动窗口分割
每个mat文件单独处理，静息和注意力样本分别存储在cell中
"""

import numpy as np
import os
from scipy.io import loadmat, savemat
from PreProcess import preprocess3
from EOGRemovalDATNet import eog_removal_datnet
import matplotlib.pyplot as plt
from matplotlib import rcParams

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
    
    # 只保存前30秒的数据（如果数据超过30秒）
    max_display_duration = 30  # 秒
    max_samples = int(max_display_duration * fs)
    
    if len(original_signal) > max_samples:
        original_save = original_signal[:max_samples]
        processed_save = processed_signal[:max_samples]
    else:
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
    """
    windows = []
    start = 0
    
    while start + window_size <= len(signal):
        window = signal[start:start + window_size]
        windows.append(window)
        start += step_size
    
    return windows


def process_single_stage(signal, stage_name, filename, fs=250, window_duration=6, 
                        step_duration=2, visualize=True, output_folder='figures'):
    """
    处理单个阶段的信号（静息或注意力）
    :param signal: 输入信号
    :param stage_name: 阶段名称（用于日志输出）
    :param filename: 文件名（用于图像保存）
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
    :param visualize: 是否生成可视化图像
    :param output_folder: 图像保存文件夹
    :return: (处理后的完整信号, 处理后的窗口列表)
    """
    if len(signal) == 0:
        print(f"  {stage_name}阶段数据为空，跳过处理")
        return None, []
    
    print(f"  {stage_name}阶段长度: {len(signal)} 个点 ({len(signal)/fs:.2f}秒)")
    
    try:
        # 步骤1: 预处理
        print(f"    -> 正在进行预处理...")
        processed_signal, _ = preprocess3(signal, fs)
        
        # 步骤2: 眼电去除（使用DATNet无监督方法）
        print(f"    -> 正在去除眼电（DATNet无监督网络）...")
        cleaned_signal = eog_removal_datnet(processed_signal, fs, visualize=False)
        
        # 可视化对比
        if visualize:
            print(f"    -> 正在生成可视化图像...")
            plot_signal_comparison(signal, processed_signal, cleaned_signal,
                                 filename, stage_name, fs, output_folder)
        
        # 步骤3: 滑动窗口切分
        window_size = int(window_duration * fs)  # 6秒 * 250Hz = 1500个点
        step_size = int(step_duration * fs)      # 2秒 * 250Hz = 500个点
        
        print(f"    -> 正在进行滑动窗口切分...")
        windows = sliding_window_split(cleaned_signal, window_size, step_size)
        
        print(f"    -> {stage_name}阶段切分出 {len(windows)} 个窗口")
        
        return cleaned_signal, windows
        
    except Exception as e:
        print(f"  {stage_name}阶段处理失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return None, []


def process_and_save_mat_file(mat_path, output_folder, fs=250, window_duration=6, 
                             step_duration=2, visualize=True, figure_folder='figures'):
    """
    处理单个mat文件并保存为同名的新mat文件
    :param mat_path: 输入mat文件路径
    :param output_folder: 输出文件夹路径
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
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
    
    # 处理静息阶段
    print(f"  处理静息阶段...")
    rest_cleaned, rest_windows = process_single_stage(rest_stage, "静息", filename, fs, 
                                       window_duration, step_duration, 
                                       visualize, figure_folder)
    
    # 处理注意力阶段
    print(f"  处理注意力阶段...")
    attention_cleaned, attention_windows = process_single_stage(attention_stage, "注意力", filename, fs, 
                                            window_duration, step_duration, 
                                            visualize, figure_folder)
    
    # 保存预处理后的完整信号到同名mat文件
    base_name = os.path.splitext(filename)[0]
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
    
    # 保存分割后的样本到同名的mat文件
    if len(rest_windows) > 0 or len(attention_windows) > 0:
        # 获取原文件名
        output_path = os.path.join(output_folder, filename)
        
        # 转换为numpy矩阵 (N x 1500)，每行是一个窗口样本
        rest_samples = np.array(rest_windows) if len(rest_windows) > 0 else np.array([])
        attention_samples = np.array(attention_windows) if len(attention_windows) > 0 else np.array([])
        
        # 保存为mat文件（直接保存为矩阵，不使用cell）
        save_dict = {}
        if len(rest_windows) > 0:
            save_dict['rest_samples'] = rest_samples
        if len(attention_windows) > 0:
            save_dict['attention_samples'] = attention_samples
        
        savemat(output_path, save_dict)
        print(f"  已保存分割后样本到: {output_path}")
        if len(rest_windows) > 0:
            print(f"    - 静息样本: {rest_samples.shape}")
        if len(attention_windows) > 0:
            print(f"    - 注意力样本: {attention_samples.shape}")
        
        return True
    else:
        print(f"  未生成任何样本，跳过保存")
        return False


def batch_process_rest_attention_dataset(input_folder, output_folder, fs=250, 
                                        window_duration=6, step_duration=2, 
                                        visualize=True, figure_folder='figures'):
    """
    批量处理文件夹中的所有mat文件
    每个mat文件单独保存为同名的新mat文件
    :param input_folder: 输入文件夹路径（包含原始mat文件）
    :param output_folder: 输出文件夹路径（保存处理后的mat文件）
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
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
    print(f"处理设置: 窗长={window_duration}秒, 步长={step_duration}秒")
    print(f"预处理方法: preprocess3")
    print(f"眼电去除方法: DATNet无监督网络 (eog_removal_datnet)")
    print(f"可视化: {'开启' if visualize else '关闭'}")
    if visualize:
        print(f"图像保存文件夹: {figure_folder}")
    print(f"输入文件夹: {input_folder}")
    print(f"输出文件夹: {output_folder}")
    print("=" * 60)
    
    success_count = 0
    
    for idx, filename in enumerate(mat_files, 1):
        mat_path = os.path.join(input_folder, filename)
        print(f"\n[{idx}/{total_files}] 处理: {filename}")
        
        try:
            if process_and_save_mat_file(mat_path, output_folder, fs, 
                                        window_duration, step_duration, 
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
    input_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\微信小程序\\裁剪好的MAT'  # 包含原始mat文件的文件夹
    output_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\微信小程序\\裁剪好的MAT\\预处理后'  # 输出文件夹
    figure_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\总和\\figures'  # 图像保存文件夹
    
    # 采样率和窗口参数
    fs = 250  # 采样率 250Hz
    window_duration = 6  # 窗口时长 6秒
    step_duration = 2  # 步长 2秒
    visualize = True  # 可视化标志位: True=生成图像, False=不生成图像
    
    # 批量处理
    batch_process_rest_attention_dataset(
        input_folder=input_folder,
        output_folder=output_folder,
        fs=fs,
        window_duration=window_duration,
        step_duration=step_duration,
        visualize=visualize,
        figure_folder=figure_folder
    )
