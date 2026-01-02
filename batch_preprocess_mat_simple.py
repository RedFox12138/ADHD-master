"""简化版：批量预处理目录下的 .txt 信号文件（写死路径），并在相同目录保存预处理结果

将要处理的目录写死在 `INPUT_DIR` 变量中，脚本会遍历该目录下所有 .txt 文件，
把每个文件视为一维时间序列（每行或以空白分隔的数值），调用 `preprocess3(signal, fs)`，
并在同一目录输出名为 原名_preprocessed.txt 的文件，内容为预处理后的序列。
"""

import os
import numpy as np
from scipy.io import savemat
from PreProcess import preprocess3

# 请在此处写死要处理的目录（包含 .txt 文件）
INPUT_DIR = r"D:\Pycharm_Projects\EOG Remove\生成全模拟数据"
# 采样率，传给 preprocess3
FS = 250


def process_and_save_txt(txt_path, fs=FS):
    try:
        data = np.loadtxt(txt_path)
    except Exception as e:
        print(f"加载失败 {txt_path}: {e}")
        return False

    # 保证一维
    sig = np.asarray(data).flatten()

    try:
        processed, _ = preprocess3(sig, fs)
    except Exception as e:
        print(f"预处理失败 {txt_path}: {e}")
        return False

    out_path = os.path.splitext(txt_path)[0] + '_preprocessed.mat'
    try:
        # 保存为 mat 文件，键名为 processed
        savemat(out_path, {'processed': np.asarray(processed)})
        print(f"  已保存: {out_path}")
        return True
    except Exception as e:
        print(f"  保存失败 {out_path}: {e}")
        return False


def main():
    if not os.path.isdir(INPUT_DIR):
        print(f"输入目录不存在: {INPUT_DIR}")
        return

    files = [f for f in os.listdir(INPUT_DIR) if f.lower().endswith('.txt')]
    if not files:
        print(f"输入目录中未找到 .txt 文件: {INPUT_DIR}")
        return

    print(f"找到 {len(files)} 个 .txt 文件，开始处理（保存到同一目录，后缀 _preprocessed.txt）")
    for i, fname in enumerate(files, start=1):
        path = os.path.join(INPUT_DIR, fname)
        print(f"[{i}/{len(files)}] {fname}")
        process_and_save_txt(path, fs=FS)


if __name__ == '__main__':
    main()
