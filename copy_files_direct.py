"""
查找并覆盖同名文件 - 直接执行版本
将源目录中的文件直接覆盖到目标目录中的同名文件
"""

import os
import shutil

# 配置路径
source_dir = r"D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat\8s"
target_dir = r"D:\Pycharm_Projects\ADHD-master\data\分类结果\用于配对t校验\分段\8s"

print("\n" + "="*70)
print("同名文件覆盖工具 - 直接执行模式")
print("="*70)
print(f"源目录: {source_dir}")
print(f"目标目录: {target_dir}")
print("-"*70)

# 检查目录是否存在
if not os.path.exists(source_dir):
    print(f"错误：源目录不存在: {source_dir}")
    exit(1)

if not os.path.exists(target_dir):
    print(f"错误：目标目录不存在: {target_dir}")
    exit(1)

# 获取目标目录中的所有文件
target_files = set()
for file in os.listdir(target_dir):
    file_path = os.path.join(target_dir, file)
    if os.path.isfile(file_path):
        target_files.add(file)

print(f"目标目录中共有 {len(target_files)} 个文件")

# 查找源目录中的同名文件并复制
matching_files = []
for file in os.listdir(source_dir):
    source_file_path = os.path.join(source_dir, file)
    
    # 跳过目录
    if os.path.isdir(source_file_path):
        continue
    
    # 检查是否在目标目录中存在同名文件
    if file in target_files:
        target_file_path = os.path.join(target_dir, file)
        matching_files.append((file, source_file_path, target_file_path))

print(f"找到 {len(matching_files)} 个同名文件")

if len(matching_files) == 0:
    print("没有找到同名文件，无需操作。")
    exit(0)

# 开始复制
print("\n开始复制文件...")
print("-"*70)

success_count = 0
fail_count = 0

for idx, (filename, source_path, target_path) in enumerate(matching_files, 1):
    try:
        # 复制文件（覆盖）
        shutil.copy2(source_path, target_path)
        print(f"[{idx}/{len(matching_files)}] ✓ {filename}")
        success_count += 1
    except Exception as e:
        print(f"[{idx}/{len(matching_files)}] ✗ {filename} - 错误: {e}")
        fail_count += 1

print("="*70)
print(f"复制完成！")
print(f"  成功: {success_count} 个文件")
print(f"  失败: {fail_count} 个文件")
print("="*70)
