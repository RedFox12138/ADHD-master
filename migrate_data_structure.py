"""
数据目录结构迁移脚本

将旧的数据目录结构迁移到新的统一结构：

旧结构：
data/{user_id}/
  ├── data/{date}/          # 脑电原始数据
  ├── result/{date}/        # 脑电分析结果
  ├── schulte_records/      # 舒尔特方格记录
  └── (其他文件夹)

新结构：
data/{user_id}/
  ├── eeg_data/{date}/      # 脑电原始数据（统一命名）
  ├── eeg_results/{date}/   # 脑电分析结果（统一命名）
  ├── schulte/              # 舒尔特方格记录（简化命名）
  ├── calibration/          # 标定数据（保持不变）
  └── game_records/         # 游戏记录（保持不变）

用法：
    python migrate_data_structure.py

注意：
    - 该脚本会复制数据到新位置，不会删除旧数据
    - 迁移完成后，请手动验证新数据的正确性
    - 验证无误后，可手动删除旧文件夹
"""

import os
import shutil
from pathlib import Path


def migrate_user_data(user_path):
    """迁移单个用户的数据"""
    user_id = os.path.basename(user_path)
    print(f"\n正在迁移用户: {user_id}")
    
    migrated = False
    
    # 1. 迁移 data -> eeg_data
    old_data_dir = os.path.join(user_path, 'data')
    new_data_dir = os.path.join(user_path, 'eeg_data')
    
    if os.path.exists(old_data_dir) and not os.path.exists(new_data_dir):
        print(f"  迁移: data -> eeg_data")
        shutil.copytree(old_data_dir, new_data_dir)
        migrated = True
    
    # 2. 迁移 result -> eeg_results
    old_result_dir = os.path.join(user_path, 'result')
    new_result_dir = os.path.join(user_path, 'eeg_results')
    
    if os.path.exists(old_result_dir) and not os.path.exists(new_result_dir):
        print(f"  迁移: result -> eeg_results")
        shutil.copytree(old_result_dir, new_result_dir)
        migrated = True
    
    # 3. 迁移 schulte_records -> schulte
    old_schulte_dir = os.path.join(user_path, 'schulte_records')
    new_schulte_dir = os.path.join(user_path, 'schulte')
    
    if os.path.exists(old_schulte_dir) and not os.path.exists(new_schulte_dir):
        print(f"  迁移: schulte_records -> schulte")
        shutil.copytree(old_schulte_dir, new_schulte_dir)
        migrated = True
    
    if migrated:
        print(f"  ✅ 用户 {user_id} 数据迁移完成")
    else:
        print(f"  ⏭️  用户 {user_id} 无需迁移或已迁移")
    
    return migrated


def main():
    """主函数：扫描所有用户并迁移数据"""
    data_root = 'data'
    
    if not os.path.exists(data_root):
        print(f"❌ 数据目录不存在: {data_root}")
        return
    
    print("=" * 60)
    print("开始迁移数据目录结构...")
    print("=" * 60)
    
    total_users = 0
    migrated_users = 0
    
    # 遍历所有用户目录
    for user_id in os.listdir(data_root):
        user_path = os.path.join(data_root, user_id)
        
        # 跳过非目录文件
        if not os.path.isdir(user_path):
            continue
        
        total_users += 1
        
        if migrate_user_data(user_path):
            migrated_users += 1
    
    print("\n" + "=" * 60)
    print(f"迁移完成！")
    print(f"  总用户数: {total_users}")
    print(f"  已迁移: {migrated_users}")
    print(f"  无需迁移: {total_users - migrated_users}")
    print("=" * 60)
    
    if migrated_users > 0:
        print("\n⚠️  重要提示：")
        print("  1. 请验证新数据目录的正确性")
        print("  2. 验证无误后，可手动删除以下旧目录：")
        print("     - data/{user_id}/data/")
        print("     - data/{user_id}/result/")
        print("     - data/{user_id}/schulte_records/")
        print("  3. 建议先备份后再删除旧数据")


if __name__ == '__main__':
    main()
