%% 绘制全模拟数据集脚本
% 用途：绘制纯净脑电片段在不同信噪比下叠加眨眼干扰、眼动干扰、混合噪声的图
% 不实际生成数据，只是模拟数据生成过程并画图展示

clear; close all; clc;

%% 配置参数
fs = 250; % 采样率 (Hz)
duration_sec = 6; % 信号持续时间(秒)
t = 0:1/fs:duration_sec-1/fs;
numSamples = length(t);

% 定义信噪比等级（与Create_EEG_Multi_SNR.m保持一致）
snr_blink_levels = [4, 0, -6, -10, -14, -18, -20, -22];  % 眨眼信噪比 (dB)
snr_eog_levels = [4, 0, -2, -4, -6, -10, -12, -14];      % 眼动信噪比 (dB)

fprintf('========================================\n');
fprintf('开始绘制全模拟数据集图例\n');
fprintf('========================================\n');

%% 1. 生成一个纯净脑电片段
fprintf('\n========== 生成纯净脑电片段 ==========\n');

% 1.1 生成 1/f 粉红噪声背景
white_noise = randn(1, numSamples);
fft_white = fft(white_noise);
n_fft = length(fft_white);
freqs_fft = (0:n_fft-1) * fs / n_fft;

% 创建 1/f 功率谱密度衰减
pink_filter = ones(1, n_fft);
for k = 2:n_fft
    freq = freqs_fft(k);
    if freq > 0
        pink_filter(k) = 1 / sqrt(freq);
    end
end

fft_pink = fft_white .* pink_filter;
pink_noise = real(ifft(fft_pink));
pink_noise = pink_noise / std(pink_noise);

% 1.2 生成周期性震荡成分
num_oscillations = 8;
oscillation_signal = zeros(1, numSamples);

for f = 1:num_oscillations
    freq = 4 + rand() * 26; % 4-30 Hz
    phase = 2 * pi * rand();
    
    if freq < 13
        amplitude = 0.8 + 0.7 * rand();
    else
        amplitude = 0.4 + 0.6 * rand();
    end
    
    oscillation_signal = oscillation_signal + amplitude * sin(2 * pi * freq * t + phase);
end

if std(oscillation_signal) > 0
    oscillation_signal = oscillation_signal / std(oscillation_signal);
end

% 1.3 混合背景噪声和震荡成分
pure_eeg = 0.7 * oscillation_signal + 0.3 * pink_noise;

% 幅度归一化
rms_eeg = sqrt(mean(pure_eeg.^2));
if rms_eeg > 0
    pure_eeg = pure_eeg / rms_eeg;
end
pure_eeg = pure_eeg * 20; % 乘以20微伏

fprintf('纯净脑电片段生成完成。\n');

% 绘制纯净脑电
figure('Position', [100, 100, 1000, 600], 'Color', 'white', 'Name', '纯净脑电信号');
plot(t, pure_eeg, 'b', 'LineWidth', 2.5);
set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
ylabel('Amplitude (μV)', 'FontSize', 28, 'FontWeight', 'bold');
xlim([0, max(t)]);
ylim([-500, 500]);
grid on;

%% 2. 生成标准眼动伪影（用于不同SNR的缩放）
fprintf('\n========== 生成标准眼动伪影 ==========\n');

eog_artifact = zeros(1, numSamples);
num_eog_events = 2; % 生成2个眼动事件
occupied_ranges = [];
min_interval_samples = round(1.5 * fs);

for i = 1:num_eog_events
    eog_duration = 0.5 + 1.5 * rand();
    eog_samples = round(eog_duration * fs);
    
    % 简化：直接按顺序放置
    if i == 1
        pos = round(0.5 * fs); % 0.5秒处开始
    else
        pos = round(3.5 * fs); % 3.5秒处开始
    end
    
    end_pos = min(pos + eog_samples - 1, numSamples);
    
    % 创建方波
    amplitude = 0.6 * (0.8 + 0.4 * rand());
    eog_artifact(pos:end_pos) = amplitude;
    
    % 随机极性
    if rand() > 0.5
        eog_artifact(pos:end_pos) = -eog_artifact(pos:end_pos);
    end
end

% 归一化到最大值为1
if max(abs(eog_artifact)) > 0
    eog_artifact = eog_artifact / max(abs(eog_artifact));
end

fprintf('标准眼动伪影生成完成。\n');

%% 3. 生成标准眨眼伪影（用于不同SNR的缩放）
fprintf('\n========== 生成标准眨眼伪影 ==========\n');

blink_artifact = zeros(1, numSamples);
num_blinks = 2; % 生成2个眨眼事件

% 设计1-3 Hz带通滤波器
low_freq = 1;
high_freq = 3;
filter_order = 4;
nyquist_freq = fs / 2;
[b_blink, a_blink] = butter(filter_order, [low_freq high_freq] / nyquist_freq, 'bandpass');

for i = 1:num_blinks
    blink_duration = 0.5 + 1.5 * rand();
    blink_samples = round(blink_duration * fs);
    
    % 简化：直接按顺序放置
    if i == 1
        pos = round(1.5 * fs); % 1.5秒处开始
    else
        pos = round(4.5 * fs); % 4.5秒处开始
    end
    
    end_pos = min(pos + blink_samples - 1, numSamples);
    actual_samples = end_pos - pos + 1;
    
    % 生成带通滤波的白噪声
    white_noise = randn(1, actual_samples);
    filtered_noise = filtfilt(b_blink, a_blink, white_noise);
    
    % 应用包络
    envelope = sin(pi * (0:actual_samples-1) / actual_samples);
    blink_waveform = filtered_noise .* envelope;
    
    % 归一化
    if max(abs(blink_waveform)) > 0
        blink_waveform = blink_waveform / max(abs(blink_waveform));
    end
    
    blink_artifact(pos:end_pos) = blink_artifact(pos:end_pos) + blink_waveform;
end

% 归一化到最大值为1
if max(abs(blink_artifact)) > 0
    blink_artifact = blink_artifact / max(abs(blink_artifact));
end

fprintf('标准眨眼伪影生成完成。\n');

%% 4. 计算纯净信号的RMS
rms_pure = sqrt(mean(pure_eeg.^2));

%% 5. 绘制每个SNR等级的完整图例（6个子图）
fprintf('\n========== 绘制不同SNR等级的完整图例 ==========\n');

for i = 1:length(snr_blink_levels)
    target_snr_blink = snr_blink_levels(i);
    target_snr_eog = snr_eog_levels(i);
    
    % 计算眨眼lambda
    blink_abs = abs(blink_artifact);
    blink_threshold = 0.1 * max(blink_abs);
    blink_valid_mask = blink_abs > blink_threshold;
    
    if sum(blink_valid_mask) > 0
        rms_blink = sqrt(mean(blink_artifact(blink_valid_mask).^2));
        if rms_blink > 0
            lambda_blink = rms_pure / (rms_blink * 10^(target_snr_blink / 20));
        else
            lambda_blink = 0;
        end
    else
        lambda_blink = 0;
    end
    
    % 计算眼动lambda
    eog_abs = abs(eog_artifact);
    eog_threshold = 0.1 * max(eog_abs);
    eog_valid_mask = eog_abs > eog_threshold;
    
    if sum(eog_valid_mask) > 0
        rms_eog = sqrt(mean(eog_artifact(eog_valid_mask).^2));
        if rms_eog > 0
            lambda_eog = rms_pure / (rms_eog * 10^(target_snr_eog / 20));
        else
            lambda_eog = 0;
        end
    else
        lambda_eog = 0;
    end
    
    % 缩放伪影
    scaled_blink = lambda_blink * blink_artifact;
    scaled_eog = lambda_eog * eog_artifact;
    
    % 生成各种组合
    contaminated_blink = pure_eeg + scaled_blink;      % 纯净+眨眼
    contaminated_eog = pure_eeg + scaled_eog;          % 纯净+眼动
    contaminated_mixed = pure_eeg + scaled_blink + scaled_eog; % 混合
    
    % 创建包含6个子图的大图
    fig_name = sprintf('SNR等级%d: 眨眼SNR=%ddB, 眼动SNR=%ddB', i, target_snr_blink, target_snr_eog);
    figure('Position', [50, 50, 1800, 1200], 'Color', 'white', 'Name', fig_name);
    
    % 子图1: 纯净脑电
    subplot(3, 2, 1);
    plot(t, pure_eeg, 'b', 'LineWidth', 2.5);
    set(gca, 'Color', 'none', 'FontSize', 20, 'LineWidth', 1.5);
    xlabel('Time (s)', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 20, 'FontWeight', 'bold');
    xlim([0, max(t)]);
    ylim([-500, 500]);
    grid on;
    
    % 子图2: 纯眨眼伪影（缩放后）
    subplot(3, 2, 2);
    plot(t, scaled_blink, 'r', 'LineWidth', 2.5);
    set(gca, 'Color', 'none', 'FontSize', 20, 'LineWidth', 1.5);
    xlabel('Time (s)', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 20, 'FontWeight', 'bold');
    xlim([0, max(t)]);
    ylim([-500, 500]);
    grid on;
    
    % 子图3: 纯眼动伪影（缩放后）
    subplot(3, 2, 3);
    plot(t, scaled_eog, 'r', 'LineWidth', 2.5);
    set(gca, 'Color', 'none', 'FontSize', 20, 'LineWidth', 1.5);
    xlabel('Time (s)', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 20, 'FontWeight', 'bold');
    xlim([0, max(t)]);
    ylim([-500, 500]);
    grid on;
    
    % 子图4: 眨眼干扰（纯净+眨眼）
    subplot(3, 2, 4);
    plot(t, contaminated_blink, 'b', 'LineWidth', 2.5);
    set(gca, 'Color', 'none', 'FontSize', 20, 'LineWidth', 1.5);
    xlabel('Time (s)', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 20, 'FontWeight', 'bold');
    xlim([0, max(t)]);
    ylim([-500, 500]);
    grid on;
    
    % 子图5: 眼动干扰（纯净+眼动）
    subplot(3, 2, 5);
    plot(t, contaminated_eog, 'b', 'LineWidth', 2.5);
    set(gca, 'Color', 'none', 'FontSize', 20, 'LineWidth', 1.5);
    xlabel('Time (s)', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 20, 'FontWeight', 'bold');
    xlim([0, max(t)]);
    ylim([-500, 500]);
    grid on;
    
    % 子图6: 混合噪声（纯净+眨眼+眼动）
    subplot(3, 2, 6);
    plot(t, contaminated_mixed, 'b', 'LineWidth', 2.5);
    set(gca, 'Color', 'none', 'FontSize', 20, 'LineWidth', 1.5);
    xlabel('Time (s)', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 20, 'FontWeight', 'bold');
    xlim([0, max(t)]);
    ylim([-500, 500]);
    grid on;
    
    fprintf('  已生成: %s\n', fig_name);
end

fprintf('\n========================================\n');
fprintf('全部图例绘制完成！\n');
fprintf('========================================\n');
fprintf('共生成 %d 个大图，每个包含6个子图:\n', length(snr_blink_levels));
fprintf('  每个大图包含:\n');
fprintf('    - 纯净脑电\n');
fprintf('    - 纯眨眼伪影（缩放后）\n');
fprintf('    - 纯眼动伪影（缩放后）\n');
fprintf('    - 眨眼干扰（纯净+眨眼）\n');
fprintf('    - 眼动干扰（纯净+眼动）\n');
fprintf('    - 混合噪声（纯净+眨眼+眼动）\n');
fprintf('========================================\n');
