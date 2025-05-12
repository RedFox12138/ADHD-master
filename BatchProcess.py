import numpy as np
import os

from PreProcess import preprocess3
from SingleDenoise import eog_removal



def process_txt_file(txt_path, output_folder, fs=250):
    """
    处理单个txt文件，对整个信号进行处理
    :param txt_path: txt文件路径
    :param output_folder: 输出文件夹
    :param fs: 采样频率(Hz)
    """
    # 读取txt文件中的数据
    data = np.loadtxt(txt_path)

    # 对整个信号进行预处理
    processed_signal,_ = preprocess3(data, fs)

    # processed_signal= optimized_dwt_eog_removal(processed_signal,visualize=True)
    processed_signal = eog_removal(processed_signal,250,True)

    # 生成输出文件名(与txt同名，但扩展名为_processed.txt)
    filename = os.path.basename(txt_path)
    output_filename = os.path.splitext(filename)[0] + '_processed.txt'
    output_path = os.path.join(output_folder, output_filename)

    # 保存为txt文件
    np.savetxt(output_path, processed_signal)


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
    input_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\额头信号'  # 替换为你的txt文件夹路径
    output_folder = 'D:\\Pycharm_Projects\\ADHD-master\\data\\额头信号去眼电'  # 替换为你想保存处理后的txt文件的文件夹

    batch_process_txt_folder(input_folder, output_folder)