import os
import numpy as np
from scipy import io

from PreProcess import  preprocess
from SingleDenoise_pro import remove_eog_with_visualization2

"""
   该代码用于用python的预处理方法批量处理脑电信号并生成MAT格式的文件
"""

def process_txt_file(txt_path, output_folder, fs=250, window_size=2):
    """
    处理单个txt文件
    :param txt_path: txt文件路径
    :param output_folder: 输出文件夹
    :param fs: 采样频率(Hz)
    :param window_size: 窗口大小(秒)
    """
    # 读取txt文件中的数据
    data = np.loadtxt(txt_path)
    total_samples = len(data)
    samples_per_window = fs * window_size  # 每个窗口的样本数 = 500

    # 计算完整窗口数量
    num_windows = total_samples // samples_per_window

    # 初始化结果矩阵
    processed_features = []

    # 分窗处理
    for i in range(num_windows):
        start_idx = i * samples_per_window
        end_idx = start_idx + samples_per_window
        window = data[start_idx:end_idx]

        # 对每个窗口进行预处理
        features = preprocess(window,250)
        # features, _ = remove_eog_with_visualization2(features, 250, 0, 0)

        processed_features.append(features)

    # 转换为numpy数组 (num_windows × n)
    result_matrix = np.array(processed_features)

    # 生成输出文件名(与txt同名，但扩展名为.mat)
    filename = os.path.basename(txt_path)
    mat_filename = os.path.splitext(filename)[0] + '.mat'
    output_path = os.path.join(output_folder, mat_filename)

    # 保存为.mat文件
    io.savemat(output_path, {'processed_data': result_matrix})


def batch_process_txt_folder(input_folder, output_folder):
    """
    批量处理文件夹中的所有txt文件
    :param input_folder: 输入文件夹路径
    :param output_folder: 输出文件夹路径
    """
    # 确保输出文件夹存在
    os.makedirs(output_folder, exist_ok=True)

    # 遍历输入文件夹中的所有txt文件
    for filename in os.listdir(input_folder):
        if filename.endswith('.txt'):
            txt_path = os.path.join(input_folder, filename)
            print(f"Processing: {filename}")
            try:
                process_txt_file(txt_path, output_folder)
            except Exception as e:
                print(f"Error processing {filename}: {str(e)}")

    print("Batch processing completed.")


# 使用示例
if __name__ == "__main__":
    input_folder = 'D:\\pycharm Project\\ADHD-master\\data\\原信号'  # 替换为你的txt文件夹路径
    output_folder = 'D:\\pycharm Project\\ADHD-master\\data\\Python预处理去眼电'  # 替换为你想保存mat文件的文件夹

    batch_process_txt_folder(input_folder, output_folder)