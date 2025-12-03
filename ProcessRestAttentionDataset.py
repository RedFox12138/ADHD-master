"""
处理mat文件中的静息和注意力数据
进行预处理、眼电去除和滑动窗口分割
分别存储静息和注意力样本到不同的cell中
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


def process_mat_file(mat_path, fs=250, window_duration=6, step_duration=2):
    """
    处理单个mat文件
    :param mat_path: mat文件路径
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
    :return: 字典，包含rest_samples和attention_samples
    """
    # 读取mat文件
    try:
        mat_data = loadmat(mat_path)
        rest_stage = mat_data['rest_stage'].flatten()
        attention_stage = mat_data['attention_stage'].flatten()
    except Exception as e:
        print(f"读取文件失败 {mat_path}: {str(e)}")
        return None
    
    result = {
        'rest_samples': [],
        'attention_samples': []
    }
    
    # 处理静息阶段
    print(f"  处理静息阶段...")
    rest_windows = process_single_stage(rest_stage, "静息", fs, window_duration, step_duration)
    result['rest_samples'] = rest_windows
    
    # 处理注意力阶段
    print(f"  处理注意力阶段...")
    attention_windows = process_single_stage(attention_stage, "注意力", fs, window_duration, step_duration)
    result['attention_samples'] = attention_windows
    
    return result


def batch_process_rest_attention_dataset(input_folder, output_file, fs=250, window_duration=6, step_duration=2):
    """
    批量处理文件夹中的所有mat文件
    分别存储静息和注意力样本到不同的cell中
    :param input_folder: 输入文件夹路径（包含mat文件）
    :param output_file: 输出mat文件路径
    :param fs: 采样率(Hz)
    :param window_duration: 窗口时长(秒)
    :param step_duration: 步长时长(秒)
    """
    all_rest_samples = []
    all_attention_samples = []
    file_count = 0
    
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
    print("=" * 60)
    
    for filename in mat_files:
        mat_path = os.path.join(input_folder, filename)
        print(f"\n[{file_count + 1}/{total_files}] 处理: {filename}")
        
        try:
            result = process_mat_file(mat_path, fs, window_duration, step_duration)
            
            if result is not None:
                # 添加到总样本中
                if len(result['rest_samples']) > 0:
                    all_rest_samples.extend(result['rest_samples'])
                
                if len(result['attention_samples']) > 0:
                    all_attention_samples.extend(result['attention_samples'])
                
                file_count += 1
                print(f"  累计静息样本数: {len(all_rest_samples)}")
                print(f"  累计注意力样本数: {len(all_attention_samples)}")
            else:
                print(f"  处理失败，跳过该文件")
                
        except Exception as e:
            print(f"  处理失败: {str(e)}")
            import traceback
            traceback.print_exc()
    
    print("\n" + "=" * 60)
    print(f"处理完成！")
    print(f"成功处理文件数: {file_count}/{total_files}")
    print(f"静息样本总数: {len(all_rest_samples)}")
    print(f"注意力样本总数: {len(all_attention_samples)}")
    
    # 保存为mat文件
    if len(all_rest_samples) > 0 or len(all_attention_samples) > 0:
        # 转换为numpy数组
        rest_dataset = np.array(all_rest_samples) if len(all_rest_samples) > 0 else np.array([])
        attention_dataset = np.array(all_attention_samples) if len(all_attention_samples) > 0 else np.array([])
        
        print(f"\n数据集形状:")
        print(f"  静息数据集: {rest_dataset.shape if len(all_rest_samples) > 0 else '(0,)'}")
        print(f"  注意力数据集: {attention_dataset.shape if len(all_attention_samples) > 0 else '(0,)'}")
        
        # 确保输出目录存在
        output_dir = os.path.dirname(output_file)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)
        
        # 保存到mat文件的不同变量中
        save_dict = {}
        if len(all_rest_samples) > 0:
            save_dict['rest_samples'] = rest_dataset
        if len(all_attention_samples) > 0:
            save_dict['attention_samples'] = attention_dataset
        
        savemat(output_file, save_dict)
        print(f"\n数据集已保存到: {output_file}")
        print(f"包含变量: {list(save_dict.keys())}")
    else:
        print("\n警告: 没有生成任何样本，未保存文件")


# 使用示例
if __name__ == "__main__":
    # 配置参数
    input_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\额头信号'  # 包含mat文件的文件夹
    output_file = 'D:\\Pycharm_Projects\\ADHD-master\\data\\rest_attention_dataset.mat'  # 输出的数据集文件
    
    # 采样率和窗口参数
    fs = 250  # 采样率 250Hz
    window_duration = 6  # 窗口时长 6秒
    step_duration = 2  # 步长 2秒
    
    # 批量处理
    batch_process_rest_attention_dataset(
        input_folder=input_folder,
        output_file=output_file,
        fs=fs,
        window_duration=window_duration,
        step_duration=step_duration
    )
