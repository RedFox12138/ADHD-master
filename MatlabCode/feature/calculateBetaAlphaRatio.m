function ba_ratio = calculateBetaAlphaRatio(signal, Fs, IAF)
% calculateBetaAlphaRatio - 计算Beta/Alpha比率
%
% Beta/Alpha Ratio = P_β / P_α
% 用途: 反映注意力和警觉性，注意态时该比率通常升高
%
% 输入:
%   signal - 时域信号
%   Fs     - 采样率 (Hz)
%   IAF    - 个体Alpha频率 (Hz, 可选)，默认为10 Hz
%
% 输出:
%   ba_ratio - Beta/Alpha比率

    if nargin < 3 || isempty(IAF)
        IAF = 10;  % 默认Alpha峰值频率
    end
    
    % 基于IAF动态定义频带
    alpha_band = [IAF - 2, IAF + 2];
    beta_band = [IAF + 2, min(30, IAF + 18)];
    
    % 计算功率谱
    [pxx, f] = pwelch(signal, hamming(min(length(signal), Fs*2)), [], [], Fs);
    
    % 计算各频带的平均功率
    alpha_power = mean(pxx(f >= alpha_band(1) & f <= alpha_band(2)));
    beta_power = mean(pxx(f >= beta_band(1) & f <= beta_band(2)));
    
    % 计算Beta/Alpha比率
    if alpha_power > 0
        ba_ratio = beta_power / alpha_power;
    else
        ba_ratio = NaN;
    end
    
    % 检查结果
    if ~isfinite(ba_ratio)
        ba_ratio = NaN;
    end
end
