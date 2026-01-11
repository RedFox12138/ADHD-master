function inv_alpha = calculateInverseAlpha(signal, Fs, IAF)
% calculateInverseAlpha - 计算逆Alpha功率
%
% Inverse Alpha = 1 / P_α
% 用途: Alpha功率的倒数，注意态时alpha抑制，该值升高
%
% 输入:
%   signal - 时域信号
%   Fs     - 采样率 (Hz)
%   IAF    - 个体Alpha频率 (Hz, 可选)，默认为10 Hz
%
% 输出:
%   inv_alpha - 逆Alpha功率

    if nargin < 3 || isempty(IAF)
        IAF = 10;  % 默认Alpha峰值频率
    end
    
    % 基于IAF动态定义Alpha频带
    alpha_band = [IAF - 2, IAF + 2];
    
    % 计算功率谱
    [pxx, f] = pwelch(signal, hamming(min(length(signal), Fs*2)), [], [], Fs);
    
    % 计算Alpha频带的平均功率
    alpha_power = mean(pxx(f >= alpha_band(1) & f <= alpha_band(2)));
    
    % 计算逆Alpha
    if alpha_power > 0
        inv_alpha = 1 / alpha_power;
    else
        inv_alpha = NaN;
    end
    
    % 检查结果
    if ~isfinite(inv_alpha)
        inv_alpha = NaN;
    end
end
