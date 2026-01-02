"""
测试DATNet模型是否支持可变长度输入
"""
import numpy as np
import torch
from model import DATNet

# 创建模型
model = DATNet(in_channels=1, base_channels=32)
model.eval()

print("="*70)
print("测试DATNet模型对不同长度输入的支持")
print("="*70)

# 测试不同长度的输入
fs = 250
test_durations = [2, 4, 6, 8]  # 秒

for duration in test_durations:
    length = int(duration * fs)
    print(f"\n测试 {duration}秒 = {length} 个采样点:")
    
    # 检查是否能被8整除（3次下采样）
    if length % 8 != 0:
        print(f"  ⚠️ 警告: {length} 不能被8整除，可能导致尺寸不匹配")
        # 调整到最近的8的倍数
        length_adjusted = (length // 8) * 8
        print(f"  调整到: {length_adjusted} 个采样点")
        length = length_adjusted
    
    # 创建测试输入
    x = torch.randn(1, 1, length)
    
    try:
        with torch.no_grad():
            eeg_clean, eog_artifact = model(x)
        
        print(f"  ✓ 成功!")
        print(f"    输入形状: {x.shape}")
        print(f"    EEG输出形状: {eeg_clean.shape}")
        print(f"    EOG输出形状: {eog_artifact.shape}")
        
        # 验证输出长度是否与输入相同
        if eeg_clean.shape[-1] == x.shape[-1]:
            print(f"    ✓ 输出长度与输入一致")
        else:
            print(f"    ✗ 输出长度不一致! 期望{x.shape[-1]}, 得到{eeg_clean.shape[-1]}")
            
    except Exception as e:
        print(f"  ✗ 失败: {str(e)}")
        import traceback
        traceback.print_exc()

print("\n" + "="*70)
print("结论:")
print("  - 如果模型支持可变长度，则可以直接处理2s、4s、6s、8s的数据")
print("  - 如果不支持，需要对数据进行分段处理或重新训练模型")
print("="*70)
