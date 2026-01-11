# EEG特征提取函数库

本目录包含用于单通道EEG信号分析的所有特征提取函数。

## 目录结构

### 1. 熵与复杂度特征

#### 已实现的熵特征：
- **SampEn.m** - 样本熵 (Sample Entropy)
  - 反映信号的复杂度和不可预测性
  - 参数: m=2, r=0.2*std(data)

- **FuzzEn.m** - 模糊熵 (Fuzzy Entropy)
  - 对噪声更鲁棒的熵度量

- **HybridEn.m** - 混合熵 (Hybrid Entropy)
  
- **TrapezoidalSampEn.m** - 梯形样本熵 (Trapezoidal Sample Entropy)

- **MSEn.m** - 多尺度熵 (Multiscale Entropy)
  - 反映多时间尺度的复杂度
  - 返回复杂度指数(CI)

- **PermEn.m** - 排列熵 (Permutation Entropy) ⭐重点特征
  - 基于序数模式，反映时序规则性
  - 注意态通常下降
  - 参数: m=3~5, τ=1

#### 复杂度特征：
- **calculateLZC.m** - Lempel-Ziv复杂度
  - 反映时间复杂性和不可预测性
  - 注意态通常升高
  - 通过二值化序列计算

### 2. 分形特征

- **HigFracDim.m** - Higuchi分形维数 (HFD)
  - 反映信号的分形复杂度
  - 参数: k_max ≈ 10

- **calculateFD.m** - 分形维数计算（备用实现）

- **calculateFDD.m** - 分形维数分布 (FDD)
  - 使用滑动窗口计算HFD
  - 返回均值(Mean)和标准差(Std)
  - Mean: 反映整体分形复杂度
  - Std: 反映注意力波动程度

### 3. 频谱特征（支持IAF动态频带）

#### 比率特征：
- **calculateTBR.m** - Theta/Beta比率
  - ADHD的经典标记
  - TBR = θ / β

- **compute_power_ratio.m** - 通用功率比率计算

- **calculatePopeIndex.m** - Pope参与度指数 ⭐核心特征
  - Pope Index = β / (α + θ)
  - 区分静息与注意的核心特征
  - 注意态时通常升高

- **calculateBetaAlphaRatio.m** - Beta/Alpha比率
  - 反映注意力和警觉性
  - BA Ratio = P_β / P_α

- **calculateInverseAlpha.m** - 逆Alpha功率
  - Inverse Alpha = 1 / P_α
  - Alpha抑制指标，注意态时升高

#### 谱形态特征：
- **calculateSpectralSlope.m** - 功率谱1/f斜率 ⭐重要特征
  - 在log-log坐标下拟合功率谱
  - 反映大脑E/I(兴奋/抑制)平衡
  - 默认拟合范围: 1-30 Hz

### 4. Hjorth参数

- **calculateComplexity.m** - Hjorth复杂度参数
  - Activity: 信号功率
  - Mobility: 频率变化
  - Complexity: 波形复杂度

## IAF（个体Alpha频率）支持

频谱特征函数支持基于IAF的动态频带定义：
- **Theta**: IAF - 6 到 IAF - 2 Hz
- **Alpha**: IAF - 2 到 IAF + 2 Hz
- **Beta**: IAF + 2 到 IAF + 18 Hz

如未提供IAF，默认值为10 Hz。

## 使用方法

在主脚本中添加路径：
```matlab
addpath(fullfile(fileparts(mfilename('fullpath')), 'feature'));
```

调用示例：
```matlab
% 熵特征
[~, perm_norm, ~] = PermEn(signal, 'Norm', false);
lzc_val = calculateLZC(signal);

% 分形特征
hfd_val = HigFracDim(signal, 10);
[fdd_mean, fdd_std] = calculateFDD(signal);

% 频谱特征
pope_idx = calculatePopeIndex(signal, Fs);
slope = calculateSpectralSlope(signal, Fs);
ba_ratio = calculateBetaAlphaRatio(signal, Fs, IAF);
```

## 特征分类总结

### 线性频谱特征 (6个)
- TBR, Pope_Index, Inverse_Alpha, Beta_Alpha_Ratio, Spectral_Slope
- Complexity_Activity, Complexity_Mobility, Complexity_Complexity

### 非线性动力学特征 (11个)
- SampEn, FuzzEn, HybridEn, TrapezoidalSampEn, MSEn_CI
- PermEn, LZC
- HFD, FDD_Mean, FDD_Std

**总计: 18个特征**

## 注意事项

1. 所有函数都包含NaN/Inf检查，保证鲁棒性
2. 复杂算法（如PermEn, MSEn）使用try-catch保护
3. 建议信号长度 > 1000个样本点以获得稳定结果
4. 频谱特征需要足够的频率分辨率（建议采样率≥100Hz）
