function tbr_ratio = calculateTBR(eeg_signal, Fs)
    % 该函数计算给定EEG信号的Theta/Beta功率比（TBR）。
    %
    % 输入:
    %   eeg_signal : EEG信号向量（单通道）
    %   Fs         : 信号采样率 (Hz)
    %
    % 输出:
    %   tbr_ratio  : Theta/Beta功率比

    % 定义频带范围
    theta_band = [4, 8];
    beta_band = [13, 25];

    % 计算信号的功率谱密度 (PSD)
    % 使用 pwelch 函数，它是计算PSD的常用方法
    [Pxx, F] = pwelch(eeg_signal, [], [], [], Fs);

    % 找到Theta和Beta频段的频率索引
    theta_indices = find(F >= theta_band(1) & F <= theta_band(2));
    beta_indices = find(F >= beta_band(1) & F <= beta_band(2));

    % 计算Theta和Beta频段的平均功率
    theta_power = mean(Pxx(theta_indices));
    beta_power = mean(Pxx(beta_indices));

    % 避免除以零，如果Beta功率为零，TBR也设为零
    if beta_power == 0
        tbr_ratio = 0;
    else
        tbr_ratio = theta_power / beta_power;
    end
end