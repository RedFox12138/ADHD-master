function power_ratio = compute_power_ratio(eeg_data, Fs, theta_band, beta_band)
    % 切比雪夫II型滤波器参数
    Rp = 3;   % 通带波动（dB）
    Rs = 40;  % 阻带衰减（dB）
    
    % 设计theta波段的切比雪夫II型带通滤波器
    f1_theta = theta_band(1) / (Fs / 2);
    f2_theta = theta_band(2) / (Fs / 2);
    [n_theta, Wn_theta] = cheb2ord([f1_theta, f2_theta], [f1_theta*0.8, f2_theta*1.2], Rp, Rs);
    [b_theta, a_theta] = cheby2(n_theta, Rs, Wn_theta, 'bandpass');
    
    % 设计beta波段的切比雪夫II型带通滤波器
    f1_beta = beta_band(1) / (Fs / 2);
    f2_beta = beta_band(2) / (Fs / 2);
    [n_beta, Wn_beta] = cheb2ord([f1_beta, f2_beta], [f1_beta*0.8, f2_beta*1.2], Rp, Rs);
    [b_beta, a_beta] = cheby2(n_beta, Rs, Wn_beta, 'bandpass');
    
    % 对theta波段滤波
    theta_filtered = filter(b_theta, a_theta, eeg_data);
    % 计算theta波段功率（时域信号平方和）
    theta_power = sum(theta_filtered .^ 2);

    % 对beta波段滤波
    beta_filtered = filter(b_beta, a_beta, eeg_data);
    % 计算beta波段功率（时域信号平方和）
    beta_power = sum(beta_filtered .^ 2);

    % 计算theta和beta功率比
    if beta_power ~= 0
        power_ratio = theta_power / beta_power;
    else
        power_ratio = NaN;  % 防止除以零
    end
end