"""
处理mat文件中的静息和注意力数据
进行预处理、眼电去除和滑动窗口分割
每个mat文件单独处理，静息和注意力样本分别存储在cell中
"""

import numpy as np
import os
from scipy.io import loadmat, savemat
from PreProcess import preprocess3
from SingleDenoise_CORRECTED import eog_removal_corrected


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


def process_single_stage(signal, stage_name, fs=250, window_duration=6, step_duration=2):
    """
    处理单个阶段的信号（静息或注意力）
    :param signal: 输入信号
    :param stage_name: 阶段名称（用于日志输出）
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
    :return: 处理后的窗口列表
    """
    if len(signal) == 0:
        print(f"  {stage_name}阶段数据为空，跳过处理")
        return []
    
    print(f"  {stage_name}阶段长度: {len(signal)} 个点 ({len(signal)/fs:.2f}秒)")
    
    try:
        # 步骤1: 预处理
        print(f"    -> 正在进行预处理...")
        processed_signal, _ = preprocess3(signal, fs)
        
        # 步骤2: 眼电去除
        print(f"    -> 正在去除眼电...")
        cleaned_signal = eog_removal_corrected(processed_signal, fs, visualize=False)
        
        # 步骤3: 滑动窗口切分
        window_size = int(window_duration * fs)  # 6秒 * 250Hz = 1500个点
        step_size = int(step_duration * fs)      # 2秒 * 250Hz = 500个点
        
        print(f"    -> 正在进行滑动窗口切分...")
        windows = sliding_window_split(cleaned_signal, window_size, step_size)
        
        print(f"    -> {stage_name}阶段切分出 {len(windows)} 个窗口")
        
        return windows
        
    except Exception as e:
        print(f"  {stage_name}阶段处理失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return []


def process_and_save_mat_file(mat_path, output_folder, fs=250, window_duration=6, step_duration=2):
    """
    处理单个mat文件并保存为同名的新mat文件
    :param mat_path: 输入mat文件路径
    :param output_folder: 输出文件夹路径
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
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
    
    # 处理静息阶段
    print(f"  处理静息阶段...")
    rest_windows = process_single_stage(rest_stage, "静息", fs, window_duration, step_duration)
    
    # 处理注意力阶段
    print(f"  处理注意力阶段...")
    attention_windows = process_single_stage(attention_stage, "注意力", fs, window_duration, step_duration)
    
    # 保存到同名的mat文件
    if len(rest_windows) > 0 or len(attention_windows) > 0:
        # 获取原文件名
        filename = os.path.basename(mat_path)
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
        print(f"  已保存到: {output_path}")
        if len(rest_windows) > 0:
            print(f"    - 静息样本: {rest_samples.shape}")
        if len(attention_windows) > 0:
            print(f"    - 注意力样本: {attention_samples.shape}")
        
        return True
    else:
        print(f"  未生成任何样本，跳过保存")
        return False


def batch_process_rest_attention_dataset(input_folder, output_folder, fs=250, window_duration=6, step_duration=2):
    """
    批量处理文件夹中的所有mat文件
    每个mat文件单独保存为同名的新mat文件
    :param input_folder: 输入文件夹路径（包含原始mat文件）
    :param output_folder: 输出文件夹路径（保存处理后的mat文件）
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
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
    print(f"眼电去除方法: eog_removal_corrected")
    print(f"输入文件夹: {input_folder}")
    print(f"输出文件夹: {output_folder}")
    print("=" * 60)
    
    success_count = 0
    
    for idx, filename in enumerate(mat_files, 1):
        mat_path = os.path.join(input_folder, filename)
        print(f"\n[{idx}/{total_files}] 处理: {filename}")
        
        try:
            if process_and_save_mat_file(mat_path, output_folder, fs, window_duration, step_duration):
                success_count += 1
        except Exception as e:
            print(f"  处理失败: {str(e)}")
            import traceback
            traceback.print_exc()
    
    print("\n" + "=" * 60)
    print(f"处理完成！")
    print(f"成功处理文件数: {success_count}/{total_files}")
    print(f"输出文件保存在: {output_folder}")


# 使用示例
if __name__ == "__main__":
    # 配置参数
    input_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\总和\\总和的mat'  # 包含原始mat文件的文件夹
    output_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\躲避游戏脑电数据\\总和\\预处理处理后的mat'  # 输出文件夹
    
    # 采样率和窗口参数
    fs = 250  # 采样率 250Hz
    window_duration = 6  # 窗口时长 6秒
    step_duration = 2  # 步长 2秒
    
    # 批量处理
    batch_process_rest_attention_dataset(
        input_folder=input_folder,
        output_folder=output_folder,
        fs=fs,
        window_duration=window_duration,
        step_duration=step_duration
    )
