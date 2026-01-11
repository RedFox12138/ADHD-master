function slope = calculateSpectralSlope(signal, Fs, freq_range)
% calculateSpectralSlope - 计算功率谱的1/f斜率
%
% Spectral Slope: 在log-log坐标下拟合功率谱的线性斜率
% 用途: 反映大脑E/I(兴奋/抑制)平衡，斜率变化与认知状态相关
%       更陡的斜率(更负)通常与更强的抑制性活动相关
%
% 输入:
%   signal     - 时域信号
%   Fs         - 采样率 (Hz)
%   freq_range - 拟合频率范围 [f_min, f_max]，默认 [1, 30] Hz
%
% 输出:
%   slope - 1/f斜率 (负值)

    if nargin < 3 || isempty(freq_range)
        freq_range = [1, 30];  % 默认1-30 Hz范围
    end
    
    % 计算功率谱
    [pxx, f] = pwelch(signal, hamming(min(length(signal), Fs*2)), [], [], Fs);
    
    % 选择指定频率范围
    idx = f >= freq_range(1) & f <= freq_range(2);
    f_fit = f(idx);
    pxx_fit = pxx(idx);
    
    % 移除零值或负值（log需要正值）
    valid_idx = pxx_fit > 0 & f_fit > 0;
    f_fit = f_fit(valid_idx);
    pxx_fit = pxx_fit(valid_idx);
    
    if length(f_fit) < 3
        slope = NaN;
        return;
    end
    
    % 在log-log空间拟合线性模型
    % log(P) = slope * log(f) + intercept
    log_f = log10(f_fit);
    log_pxx = log10(pxx_fit);
    
    % 线性拟合
    p = polyfit(log_f, log_pxx, 1);
    slope = p(1);  % 斜率
    
    % 检查结果
    if ~isfinite(slope)
        slope = NaN;
    end
end
