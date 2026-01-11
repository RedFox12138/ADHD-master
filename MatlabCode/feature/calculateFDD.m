function [fdd_mean, fdd_std] = calculateFDD(signal, k_max, window_size, overlap)
% calculateFDD - 计算分形维数分布 (Fractal Dimension Distribution)
%
% FDD: 使用滑动窗口计算Higuchi分形维数的均值和标准差
% 用途: 
%   - fdd_mean: 反映信号的整体分形复杂度
%   - fdd_std: 反映注意力波动程度，注意态时波动通常更小(更稳定)
%
% 输入:
%   signal      - 时域信号
%   k_max       - Higuchi算法的最大k值，默认10
%   window_size - 滑动窗口大小（样本点数），默认为信号长度的1/10
%   overlap     - 窗口重叠比例 (0-1)，默认0.5
%
% 输出:
%   fdd_mean - HFD均值
%   fdd_std  - HFD标准差

    if nargin < 2 || isempty(k_max)
        k_max = 10;
    end
    
    if nargin < 3 || isempty(window_size)
        window_size = max(100, floor(length(signal) / 10));
    end
    
    if nargin < 4 || isempty(overlap)
        overlap = 0.5;
    end
    
    % 移除NaN和Inf
    signal = signal(~isnan(signal) & ~isinf(signal));
    
    if length(signal) < window_size
        fdd_mean = NaN;
        fdd_std = NaN;
        return;
    end
    
    % 计算滑动窗口参数
    step_size = round(window_size * (1 - overlap));
    num_windows = floor((length(signal) - window_size) / step_size) + 1;
    
    if num_windows < 2
        % 如果窗口数太少，直接计算整段信号的HFD
        try
            hfd_value = HigFracDim(signal, k_max);
            fdd_mean = hfd_value;
            fdd_std = 0;
        catch
            fdd_mean = NaN;
            fdd_std = NaN;
        end
        return;
    end
    
    % 使用滑动窗口计算HFD
    hfd_values = zeros(1, num_windows);
    
    for i = 1:num_windows
        start_idx = (i - 1) * step_size + 1;
        end_idx = start_idx + window_size - 1;
        
        window_data = signal(start_idx:end_idx);
        
        try
            hfd_values(i) = HigFracDim(window_data, k_max);
        catch
            hfd_values(i) = NaN;
        end
    end
    
    % 移除NaN值
    hfd_values = hfd_values(~isnan(hfd_values) & ~isinf(hfd_values));
    
    if isempty(hfd_values)
        fdd_mean = NaN;
        fdd_std = NaN;
    else
        fdd_mean = mean(hfd_values);
        fdd_std = std(hfd_values);
    end
    
    % 检查结果
    if ~isfinite(fdd_mean)
        fdd_mean = NaN;
    end
    if ~isfinite(fdd_std)
        fdd_std = NaN;
    end
end
