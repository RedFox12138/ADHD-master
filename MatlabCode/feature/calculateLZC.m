function lzc = calculateLZC(signal, threshold_type)
% calculateLZC - 计算Lempel-Ziv复杂度
%
% LZC: 通过二值化序列计算信号复杂度
% 用途: 反映信号的时间复杂性和不可预测性
%       注意态通常有更高的LZC值
%
% 输入:
%   signal         - 时域信号
%   threshold_type - 二值化阈值类型: 'mean' (默认) 或 'median'
%
% 输出:
%   lzc - Lempel-Ziv复杂度 (归一化值, 0-1之间)

    if nargin < 2 || isempty(threshold_type)
        threshold_type = 'median';
    end
    
    % 移除NaN和Inf
    signal = signal(~isnan(signal) & ~isinf(signal));
    
    if length(signal) < 10
        lzc = NaN;
        return;
    end
    
    % 二值化信号
    if strcmp(threshold_type, 'median')
        threshold = median(signal);
    else
        threshold = mean(signal);
    end
    
    binary_seq = signal >= threshold;
    
    % 计算Lempel-Ziv复杂度
    n = length(binary_seq);
    c = 1;  % 复杂度计数
    u = 1;  % 当前子序列长度
    v = 1;  % 前缀长度
    vmax = 1;  % 最大前缀长度
    
    while u + v <= n
        if binary_seq(u + v) == binary_seq(v)
            v = v + 1;
        else
            vmax = max(v, vmax);
            u = u + vmax;
            v = 1;
            vmax = 1;
            c = c + 1;
        end
    end
    
    if v ~= 1
        c = c + 1;
    end
    
    % 归一化复杂度
    % 理论最大复杂度约为 n / log2(n)
    if n > 1
        max_complexity = n / log2(n);
        lzc = c / max_complexity;
    else
        lzc = 0;
    end
    
    % 检查结果
    if ~isfinite(lzc)
        lzc = NaN;
    end
end
