function pope_idx = calculatePopeIndex(signal, Fs, IAF)
% calculatePopeIndex - 计算Pope参与度指数
%
% Pope Index = β / (α + θ)
% 用途: 区分静息与注意状态的核心特征，注意态时Pope指数通常升高
%
% 输入:
%   signal - 时域信号
%   Fs     - 采样率 (Hz)
%   IAF    - 个体Alpha频率 (Hz, 可选)，默认为10 Hz
%
% 输出:
%   pope_idx - Pope参与度指数

    if nargin < 3 || isempty(IAF)
        IAF = 10;  % 默认Alpha峰值频率
    end
    
    % 基于IAF动态定义频带
    % Theta: IAF - 6 到 IAF - 2 Hz
    % Alpha: IAF - 2 到 IAF + 2 Hz  
    % Beta: IAF + 2 到 IAF + 18 Hz
    theta_band = [max(4, IAF - 6), IAF - 2];
    alpha_band = [IAF - 2, IAF + 2];
    beta_band = [IAF + 2, min(30, IAF + 18)];
    
    % 计算功率谱
    [pxx, f] = pwelch(signal, hamming(min(length(signal), Fs*2)), [], [], Fs);
    
    % 计算各频带的平均功率
    theta_power = mean(pxx(f >= theta_band(1) & f <= theta_band(2)));
    alpha_power = mean(pxx(f >= alpha_band(1) & f <= alpha_band(2)));
    beta_power = mean(pxx(f >= beta_band(1) & f <= beta_band(2)));
    
    % 计算Pope指数
    if (alpha_power + theta_power) > 0
        pope_idx = beta_power / (alpha_power + theta_power);
    else
        pope_idx = NaN;
    end
    
    % 检查结果
    if ~isfinite(pope_idx)
        pope_idx = NaN;
    end
end
