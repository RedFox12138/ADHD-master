"""
眼电数据集预处理与分割工具
处理通过data_selection_tool.m生成的mat文件
使用滑动窗口切分数据，生成统一的数据集
"""

import numpy as np
import os
from scipy.io import loadmat, savemat
from PreProcess import preprocess3


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


def process_mat_file(mat_path, fs=250, window_duration=6, step_duration=2):
    """
    处理单个mat文件
    :param mat_path: mat文件路径
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
    :return: 所有窗口的列表
    """
    # 读取mat文件
    try:
        mat_data = loadmat(mat_path)
        rest_stage = mat_data['rest_stage'].flatten()
        attention_stage = mat_data['attention_stage'].flatten()
    except Exception as e:
        print(f"读取文件失败 {mat_path}: {str(e)}")
        return []
    
    # 计算窗口大小和步长（采样点数）
    window_size = int(window_duration * fs)  # 6秒 * 250Hz = 1500个点
    step_size = int(step_duration * fs)      # 2秒 * 250Hz = 500个点
    
    all_windows = []
    
    # 处理静息阶段
    if len(rest_stage) > 0:
        print(f"  静息阶段长度: {len(rest_stage)} 个点 ({len(rest_stage)/fs:.2f}秒)")
        
        # 预处理
        try:
            processed_rest, _ = preprocess3(rest_stage, fs)
            
            # 滑动窗口切分
            rest_windows = sliding_window_split(processed_rest, window_size, step_size)
            print(f"  静息阶段切分出 {len(rest_windows)} 个窗口")
            all_windows.extend(rest_windows)
        except Exception as e:
            print(f"  静息阶段处理失败: {str(e)}")
    
    # 处理注意力阶段
    if len(attention_stage) > 0:
        print(f"  注意力阶段长度: {len(attention_stage)} 个点 ({len(attention_stage)/fs:.2f}秒)")
        
        # 预处理
        try:
            processed_attention, _ = preprocess3(attention_stage, fs)
            
            # 滑动窗口切分
            attention_windows = sliding_window_split(processed_attention, window_size, step_size)
            print(f"  注意力阶段切分出 {len(attention_windows)} 个窗口")
            all_windows.extend(attention_windows)
        except Exception as e:
            print(f"  注意力阶段处理失败: {str(e)}")
    
    return all_windows


def batch_process_eog_dataset(input_folder, output_file, fs=250, window_duration=6, step_duration=2):
    """
    批量处理文件夹中的所有mat文件，生成统一的数据集
    :param input_folder: 输入文件夹路径（包含mat文件）
    :param output_file: 输出mat文件路径
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
    """
    all_samples = []
    file_count = 0
    
    # 遍历文件夹中的所有mat文件
    mat_files = [f for f in os.listdir(input_folder) if f.endswith('.mat')]
    total_files = len(mat_files)
    
    if total_files == 0:
        print("未找到任何mat文件！")
        return
    
    print(f"找到 {total_files} 个mat文件")
    print(f"窗口设置: 窗长={window_duration}秒, 步长={step_duration}秒")
    print("-" * 60)
    
    for filename in mat_files:
        mat_path = os.path.join(input_folder, filename)
        print(f"\n[{file_count + 1}/{total_files}] 处理: {filename}")
        
        try:
            windows = process_mat_file(mat_path, fs, window_duration, step_duration)
            
            if len(windows) > 0:
                all_samples.extend(windows)
                file_count += 1
                print(f"  累计样本数: {len(all_samples)}")
            else:
                print(f"  未生成任何样本")
                
        except Exception as e:
            print(f"  处理失败: {str(e)}")
    
    print("\n" + "=" * 60)
    print(f"处理完成！")
    print(f"成功处理文件数: {file_count}/{total_files}")
    print(f"总样本数: {len(all_samples)}")
    
    if len(all_samples) > 0:
        # 转换为numpy数组
        dataset = np.array(all_samples)
        print(f"数据集形状: {dataset.shape}")
        
        # 保存为mat文件
        output_dir = os.path.dirname(output_file)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)
        
        savemat(output_file, {'eog_dataset': dataset})
        print(f"数据集已保存到: {output_file}")
    else:
        print("警告: 没有生成任何样本，未保存文件")


# 使用示例
if __name__ == "__main__":
    # 配置参数
    input_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\额头信号'  # 包含mat文件的文件夹
    output_file = 'D:\\Pycharm_Projects\\ADHD-master\\data\\eog_dataset.mat'  # 输出的数据集文件
    
    # 采样率和窗口参数
    fs = 250  # 采样率 250Hz
    window_duration = 6  # 窗口时长 6秒
    step_duration = 2  # 步长 2秒
    
    # 批量处理
    batch_process_eog_dataset(
        input_folder=input_folder,
        output_file=output_file,
        fs=fs,
        window_duration=window_duration,
        step_duration=step_duration
    )
