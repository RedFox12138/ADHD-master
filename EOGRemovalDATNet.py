"""
DAT-Net 无监督EOG去除推理模块
封装用于ProcessRestAttentionDataset.py使用
"""
import os
import sys
import numpy as np
import torch
from torch.utils.data import Dataset, DataLoader

# 尝试导入DATNet模型
# 优先使用本地model.py，其次尝试从DAT-Net目录导入
try:
    from model import DATNet
except ImportError:
    # 如果本地没有，尝试从DAT-Net目录导入
    datnet_model_path = r'D:\Pycharm_Projects\EOG Remove\复现的方法\我自己的方法\DAT-Net'
    if os.path.isdir(datnet_model_path):
        sys.path.insert(0, datnet_model_path)
    try:
        from model import DATNet
    except ImportError:
        print("警告: 无法导入DATNet模型，请检查路径")
        DATNet = None


class EOGRemovalDATNet:
    """DAT-Net EOG去除推理器"""
    
    def __init__(self, model_path=None, device=None):
        """
        初始化DATNet推理器
        
        参数:
            model_path: 模型权重路径，默认使用预训练模型
            device: 计算设备 ('cuda' 或 'cpu')
        """
        if DATNet is None:
            raise ImportError("无法导入DATNet模型，请检查路径")
        
        # 设置设备
        if device is None:
            self.device = torch.device('cuda:0' if torch.cuda.is_available() else 'cpu')
        else:
            self.device = torch.device(device)
        
        # 默认模型路径
        if model_path is None:
            # 尝试从真实数据集训练的模型路径
            default_paths = [
                r'D:\Pycharm_Projects\EOG Remove\复现的方法\训练完的模型和数据\真实数据集\无监督模型\datnet_unsupervised_real_best_用于实时部署去眼电.pth'
            ]
            # r'D:\Pycharm_Projects\EOG Remove\复现的方法\训练完的模型和数据\真实数据集\无监督模型\datnet_unsupervised_real_best.pth'
            for path in default_paths:
                if os.path.exists(path):
                    model_path = path
                    break
        
        # 创建模型
        self.model = DATNet(in_channels=1, base_channels=32).to(self.device)
        
        # 加载模型权重
        if model_path and os.path.exists(model_path):
            self.model.load_state_dict(torch.load(model_path, map_location=self.device))
            print(f"✓ 已加载模型: {model_path}")
        else:
            print(f"⚠️ 未找到模型权重，使用随机初始化")
            if model_path:
                print(f"  期望路径: {model_path}")
        
        self.model.eval()
        
    def remove_eog_single(self, signal, fs=250, visualize=False):
        """
        去除单个信号的EOG伪影（兼容旧接口）
        
        参数:
            signal: 输入信号 (1D numpy数组)
            fs: 采样率 (Hz), 默认250
            visualize: 是否可视化（保留兼容性，不使用）
            
        返回:
            clean_signal: 去除EOG后的信号 (1D numpy数组)
        """
        # 归一化
        norm = np.max(np.abs(signal))
        if norm == 0:
            norm = 1.0
        signal_normalized = signal.astype('float32') / norm
        
        # 转换为torch张量
        with torch.no_grad():
            signal_tensor = torch.from_numpy(signal_normalized).float()
            signal_tensor = signal_tensor.unsqueeze(0).unsqueeze(0).to(self.device)  # (1, 1, L)
            
            # 模型推理
            eeg_clean, eog_artifact = self.model(signal_tensor * norm)
            
            # 转换回numpy
            clean_signal = eeg_clean.squeeze().cpu().numpy()
        
        return clean_signal
    
    def remove_eog_batch(self, signals, fs=250, batch_size=50):
        """
        批量去除EOG伪影（更高效）
        
        参数:
            signals: 输入信号列表或numpy数组 (N, L)
            fs: 采样率 (Hz), 默认250
            batch_size: 批处理大小
            
        返回:
            clean_signals: 去除EOG后的信号 (N, L)
            eog_artifacts: 提取的EOG伪影 (N, L)
        """
        if isinstance(signals, list):
            signals = np.array(signals)
        
        # 归一化每个信号
        norms = np.max(np.abs(signals), axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        signals_normalized = signals.astype('float32') / norms
        
        # 创建数据加载器
        dataset = SimpleDataset(signals_normalized, norms.flatten())
        loader = DataLoader(dataset, batch_size=batch_size, shuffle=False)
        
        # 批量推理
        eeg_preds = []
        eog_preds = []
        
        with torch.no_grad():
            for signal_batch, norm_batch in loader:
                signal_batch = signal_batch.float().unsqueeze(1).to(self.device)  # (B, 1, L)
                norm_batch = norm_batch.float().view(-1, 1, 1).to(self.device)  # (B, 1, 1)
                signal_scaled = signal_batch * norm_batch
                
                # 模型推理
                eeg_clean, eog_artifact = self.model(signal_scaled)
                
                eeg_preds.append(eeg_clean.squeeze(1).cpu().numpy())
                eog_preds.append(eog_artifact.squeeze(1).cpu().numpy())
        
        # 合并结果
        clean_signals = np.concatenate(eeg_preds, axis=0)
        eog_artifacts = np.concatenate(eog_preds, axis=0)
        
        return clean_signals, eog_artifacts


class SimpleDataset(Dataset):
    """简单数据集用于批量推理"""
    def __init__(self, signals, norms):
        self.signals = signals
        self.norms = norms
    
    def __len__(self):
        return len(self.signals)
    
    def __getitem__(self, idx):
        return self.signals[idx], self.norms[idx]


# 全局推理器实例（延迟初始化）
_global_remover = None

def get_eog_remover(model_path=None, device=None):
    """获取全局EOG去除器实例（单例模式）"""
    global _global_remover
    if _global_remover is None:
        _global_remover = EOGRemovalDATNet(model_path=model_path, device=device)
    return _global_remover


def eog_removal_datnet(signal, fs=250, visualize=False):
    """
    使用DATNet去除EOG伪影（兼容旧接口）
    
    参数:
        signal: 输入信号 (1D numpy数组)
        fs: 采样率 (Hz), 默认250
        visualize: 是否可视化（保留兼容性）
        
    返回:
        clean_signal: 去除EOG后的信号 (1D numpy数组)
    """
    remover = get_eog_remover()
    return remover.remove_eog_single(signal, fs=fs, visualize=visualize)


if __name__ == '__main__':
    # 测试代码
    print("="*70)
    print("DAT-Net EOG去除推理模块测试")
    print("="*70)
    
    # 创建测试信号
    fs = 250
    duration = 6  # 6秒
    t = np.linspace(0, duration, fs * duration)
    
    # 模拟EEG信号（10Hz alpha波）+ EOG伪影（眨眼，0.5Hz）
    eeg_clean = np.sin(2 * np.pi * 10 * t) * 50
    eog_artifact = np.sin(2 * np.pi * 0.5 * t) * 200
    signal = eeg_clean + eog_artifact + np.random.randn(len(t)) * 10
    
    print(f"\n测试信号:")
    print(f"  长度: {len(signal)} 样本 ({duration}秒)")
    print(f"  采样率: {fs} Hz")
    print(f"  信号范围: [{signal.min():.2f}, {signal.max():.2f}]")
    
    # 测试单信号去除
    print(f"\n[1] 测试单信号EOG去除...")
    try:
        clean = eog_removal_datnet(signal, fs=fs)
        print(f"  ✓ 成功!")
        print(f"  去噪信号范围: [{clean.min():.2f}, {clean.max():.2f}]")
    except Exception as e:
        print(f"  ✗ 失败: {e}")
    
    # 测试批量去除
    print(f"\n[2] 测试批量EOG去除...")
    try:
        remover = get_eog_remover()
        signals = np.array([signal, signal, signal])  # 3个相同信号
        clean_batch, eog_batch = remover.remove_eog_batch(signals, fs=fs, batch_size=2)
        print(f"  ✓ 成功!")
        print(f"  输入形状: {signals.shape}")
        print(f"  去噪信号形状: {clean_batch.shape}")
        print(f"  伪影形状: {eog_batch.shape}")
    except Exception as e:
        print(f"  ✗ 失败: {e}")
    
    print("\n" + "="*70)
    print("测试完成!")
    print("="*70)
