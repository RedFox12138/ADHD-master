import os

import scipy.io as sio
import numpy as np
from matplotlib import pyplot as plt

from SingleDenoise_pro import remove_eog_with_visualization2


def process_eog_removal(input_mat, output_mat):
    """
    处理去除眼电的主函数

    参数:
        input_mat: 输入的MAT文件路径
        output_mat: 输出的MAT文件路径
    """
    # 1. 读取MAT文件
    data = sio.loadmat(input_mat)
    filtered_data = data['filteredData']

    # 获取数据维度 (注意: 原代码中num_samples和num_windows可能有误，根据实际情况调整)
    num_windows, window_samples = filtered_data.shape  # 假设第一个维度是窗口数

    # 2. 预分配结果矩阵
    eog_removed_data = np.zeros_like(filtered_data)

    # 3. 对每个窗口进行处理
    for i in range(num_windows):
        window_signal = filtered_data[i, :]

        # 调用去眼电函数
        cleaned_signal, _ = remove_eog_with_visualization2(window_signal, 250, 0, 0)


        # 存储处理后的数据
        eog_removed_data[i, :] = cleaned_signal

    # 4. 保存结果到MAT文件
    sio.savemat(output_mat, {'eog_removed_data': eog_removed_data})
    print(f"处理完成，结果已保存到: {output_mat}")


def batch_process_eog_removal(input_folder, output_folder):
    """
    批量处理文件夹中的所有.mat文件

    参数:
        input_folder: 输入文件夹路径
        output_folder: 输出文件夹路径
    """
    # 确保输出文件夹存在
    os.makedirs(output_folder, exist_ok=True)

    # 获取所有.mat文件
    mat_files = [f for f in os.listdir(input_folder) if f.endswith('.mat')]

    # 处理每个文件
    for mat_file in mat_files:
        input_path = os.path.join(input_folder, mat_file)


        # 生成输出文件名 (保持原名，可以添加后缀)
        output_filename = f"{os.path.splitext(mat_file)[0]}_eog_removed.mat"
        output_path = os.path.join(output_folder, output_filename)

        print(f"正在处理文件: {mat_file}")
        process_eog_removal(input_path, output_path)


# 使用示例
if __name__ == "__main__":
    input_file = "D:\\pycharm Project\\ADHD-master\\data\\Matlab预处理"  # MATLAB处理后的输入文件
    output_file = "D:\\pycharm Project\\ADHD-master\\data\\Matlab预处理去眼电"  # 去除眼电后的输出文件
    batch_process_eog_removal(input_file, output_file)