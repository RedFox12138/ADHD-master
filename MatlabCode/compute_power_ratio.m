function power_ratio = compute_power_ratio(eeg_data, Fs, delta_band, theta_band, beta_band)
    % 参数设置
    nfft = min(1024, length(eeg_data)); % FFT点数
    window = hamming(min(256, length(eeg_data)/4)); % 窗函数
    noverlap = round(length(window)/2); % 重叠点数
    
    % 计算功率谱密度 (PSD)
    [pxx, f] = pwelch(eeg_data, window, noverlap, nfft, Fs);
    
    % 计算各频段功率（单位：μV²/Hz）
    delta_power = bandpower(pxx, f, delta_band, 'psd');
    theta_power = bandpower(pxx, f, theta_band, 'psd');
    beta_power  = bandpower(pxx, f, beta_band, 'psd');
    
%     % 调试输出
%     fprintf('Delta: %.2e, Theta: %.2e, Beta: %.2e\n',...
%             delta_power, theta_power, beta_power);
    
    % 计算功率比（添加极小量防止除以0）
    epsilon = 1e-12;
    power_ratio = (delta_power + theta_power) / (beta_power + epsilon);
    
%     % 可视化功率谱（调试用）
%     figure;
%     plot(f, 10*log10(pxx));
%     xlabel('Frequency (Hz)');
%     ylabel('Power/frequency (dB/Hz)');
%     title('Power Spectral Density');
%     grid on;
%     xlim([0 40]);
end
% 
% function power_ratio = compute_power_ratio(eeg_data, Fs, delta_band, theta_band, beta_band)
%     % 切比雪夫II型滤波器参数
%     Rp = 3;   % 通带波动（dB）
%     Rs = 40;  % 阻带衰减（dB）
%     
%     % 设计delta波段的切比雪夫II型带通滤波器
%     f1_delta = delta_band(1) / (Fs / 2);
%     f2_delta = delta_band(2) / (Fs / 2);
%     [n_delta, Wn_delta] = cheb2ord([f1_delta, f2_delta], [f1_delta*0.8, f2_delta*1.2], Rp, Rs);
%     [b_delta, a_delta] = cheby2(n_delta, Rs, Wn_delta, 'bandpass');
%     
%     % 设计theta波段的切比雪夫II型带通滤波器
%     f1_theta = theta_band(1) / (Fs / 2);
%     f2_theta = theta_band(2) / (Fs / 2);
%     [n_theta, Wn_theta] = cheb2ord([f1_theta, f2_theta], [f1_theta*0.8, f2_theta*1.2], Rp, Rs);
%     [b_theta, a_theta] = cheby2(n_theta, Rs, Wn_theta, 'bandpass');
%     
%     % 设计beta波段的切比雪夫II型带通滤波器
%     f1_beta = beta_band(1) / (Fs / 2);
%     f2_beta = beta_band(2) / (Fs / 2);
%     [n_beta, Wn_beta] = cheb2ord([f1_beta, f2_beta], [f1_beta*0.8, f2_beta*1.2], Rp, Rs);
%     [b_beta, a_beta] = cheby2(n_beta, Rs, Wn_beta, 'bandpass');
%     
%     % 对delta波段滤波
%     delta_filtered = filter(b_delta, a_delta, eeg_data);
%     % 计算delta波段功率（时域信号平方和）
%     delta_power = sum(delta_filtered .^ 2);
%     
%     % 对theta波段滤波
%     theta_filtered = filter(b_theta, a_theta, eeg_data);
%     % 计算theta波段功率（时域信号平方和）
%     theta_power = sum(theta_filtered .^ 2);
% 
%     % 对beta波段滤波
%     beta_filtered = filter(b_beta, a_beta, eeg_data);
%     % 计算beta波段功率（时域信号平方和）
%     beta_power = sum(beta_filtered .^ 2);
%     
%     
%     
%     % 计算(delta+theta)/beta功率比
%     if beta_power ~= 0
%         power_ratio = (delta_power/10000 + theta_power) / beta_power;
%     else
%         power_ratio = NaN;  % 防止除以零
%     end
% end