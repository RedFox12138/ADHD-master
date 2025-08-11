%% 单通道 LFP analysis
clc
close all;
clear all;
%% load data
data = importdata('D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电\0526 XY 头顶_processed.txt');
% data = importdata('D:\pycharm Project\ADHD-master\data\oksQL7aHWZ0qkXkFP-oC05eZugE8\0424\0424 SF头部2.txt');
% data = load('E:\brainData\小鼠脑电信号处理\LFP\2024-06-13\2024-06-13-10-28.txt')
% load('E:\brainData\小鼠脑电信号处理\LFP\20240604俊俊脑电\EEG-1 大鼠\EEG-1 大鼠\15605188179_0516-11_32_03_0516-11_47_08_0.00_4\eeg.mat');
% data = EEG(4,:); % 通道
data = data(:,1);
% data=data./12;

Fs = 250;
% 选择时间点 每组信号是在第2min给氨气刺激
air_index = [10*Fs:1:65*Fs]; % 空气选择刺激前1min
nh3_index = [80*Fs:1:135*Fs]; % 氨气刺激后1min

air_d1 = data(air_index);
nh3_d1 = data(nh3_index);

% % 降采样到250Hz
% air_d1_250hz = downsample(air_d1,4);
% nh3_d1_250hz = downsample(nh3_d1,4);
% Fs = 250;

% f1 f2 index
% theta1 3.9 – 7.8 Hz  2
% theta2 7.8 – 11.7 Hz  3
% alpha  11.7 - 15.625 4
% beta 15.625-31.25 5
f1 = 10 ;
f2 = 11.7 ;
index = 1;

winlenth = 6;
[p_theta1_nh3_ch1,f_theta1] =  LFP_Win_Process(nh3_d1,Fs,index,winlenth,"none");
[p_theta1_air_ch1,f_theta1] =  LFP_Win_Process(air_d1,Fs,index,winlenth,"none");

%% preprocess
% [filter_air_d1,air_d1_output] = EEGPreprocess(air_d1_250hz, 250, "vmd_cca");% 选择降噪算法 "none" ,"wpt_cca","ssa_cca","eemd_cca","vmd_cca"
% [filter_nh3_d1,nh3_d1_output] = EEGPreprocess(nh3_d1_250hz, 250, "vmd_cca");
% 
% %小波包分解
% [rex_air] = waveletpackdec(air_d1_output);
% [rex_nh3] = waveletpackdec(nh3_d1_output);
% 
% signal_air_denoised  = rex_air(:,index);
% signal_nh3_denoised = rex_nh3(:,index);
% 
% %% 频谱分析
% win_length = 0.5; % 以0.5秒为一个信号样本
% [p_theta1_nh3_ch1,f_theta1,energy_r_nh3_ch1,energy_m_nh3_ch1]  = LFP_pspectrum(signal_nh3_denoised,win_length,Fs,f1,f2,1);
% [p_theta1_air_ch1,f_theta1,energy_r_air_ch1,energy_m_air_ch1]  = LFP_pspectrum(signal_air_denoised,win_length,Fs,f1,f2,1);

figure
% plot ch1 theta1 3.9 – 7.8 Hz
index1 = find(f_theta1>=0);
index2 = find(f_theta1<=50);
index = [index1(1):index2(end)];
plot(f_theta1(index),p_theta1_nh3_ch1(index),'LineWidth',2)
hold on
plot(f_theta1(index),p_theta1_air_ch1(index),'LineWidth',2)
% hold on
% plot(f_theta1(index),p_theta1_Null_ch1(index),'LineWidth',2)
xlabel('Frequency (Hz)','FontName','Times New Roman','FontSize',12)
ylabel('Power spectrum (dB)','FontName','Times New Roman','FontSize',12)
legend('stimulated group','control group','FontName','Times New Roman','FontSize',12)
% title('ch1: filtered','FontName','Times New Roman','FontSize',12)
% title('{\theta}2:7.8-11.7 Hz','FontName','Times New Roman','FontSize',12)
title('Frequency','FontName','Times New Roman','FontSize',12)
% ylim([-50 -30])
%%
fs = 250; % 采样率(Hz)
[~, eeg_data] = EEGPreprocess(data, fs, "none");
t = (0:length(eeg_data)-1)/fs; % 时间向量

%% 设计各波段的带通滤波器
% Delta波段 (0.5-4 Hz)
delta_low = 0.5; 
delta_high = 4;
[b_delta, a_delta] = butter(4, [delta_low, delta_high]/(fs/2), 'bandpass');

% Theta波段 (4-8 Hz)
theta_low = 4; 
theta_high = 8;
[b_theta, a_theta] = butter(4, [theta_low, theta_high]/(fs/2), 'bandpass');

% Alpha波段 (8-13 Hz)
alpha_low = 8; 
alpha_high = 13;
[b_alpha, a_alpha] = butter(4, [alpha_low, alpha_high]/(fs/2), 'bandpass');

% Beta波段 (13-30 Hz)
beta_low = 13; 
beta_high = 30;
[b_beta, a_beta] = butter(4, [beta_low, beta_high]/(fs/2), 'bandpass');

%% 滤波得到各波段时域信号
delta_signal = filtfilt(b_delta, a_delta, eeg_data);
theta_signal = filtfilt(b_theta, a_theta, eeg_data);
alpha_signal = filtfilt(b_alpha, a_alpha, eeg_data);
beta_signal = filtfilt(b_beta, a_beta, eeg_data);

%% 绘制原始信号和各波段时域波形
figure;

% 原始信号
subplot(5,1,1);
plot(t, eeg_data, 'k', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Amplitude');
title('原始脑电信号');
grid on;

% Delta波段
subplot(5,1,2);
plot(t, delta_signal, 'b', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Amplitude');
title('Delta波段 (0.5-4 Hz)');
grid on;

% Theta波段
subplot(5,1,3);
plot(t, theta_signal, 'r', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Amplitude');
title('Theta波段 (4-8 Hz)');
grid on;

% Alpha波段
subplot(5,1,4);
plot(t, alpha_signal, 'g', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Amplitude');
title('Alpha波段 (8-13 Hz)');
grid on;

% Beta波段
subplot(5,1,5);
plot(t, beta_signal, 'm', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Amplitude');
title('Beta波段 (13-30 Hz)');
grid on;

%% 绘制累积功率图和时序功率图
% 设置STFT参数
window = hamming(512); % 窗函数
noverlap = 256; % 重叠点数
nfft = 1024; % FFT点数

% 计算STFT
[S, F, T] = spectrogram(eeg_data, window, noverlap, nfft, fs);

% 定义波段范围
delta_band = (F >= 0.5 & F <= 4);   % Delta: 0.5-4Hz
theta_band = (F >= 4 & F <= 8);     % Theta: 4-8Hz
alpha_band = (F >= 8 & F <= 13);    % Alpha: 8-13Hz
beta_band = (F >= 13 & F <= 30);    % Beta: 13-30Hz

% 提取各波段功率（幅度平方）
S_delta = abs(S(delta_band, :)).^2;
S_theta = abs(S(theta_band, :)).^2;
S_alpha = abs(S(alpha_band, :)).^2;
S_beta = abs(S(beta_band, :)).^2;

% 计算各波段瞬时功率（跨频率维度平均）
delta_power = mean(S_delta, 1);
theta_power = mean(S_theta, 1);
alpha_power = mean(S_alpha, 1);
beta_power = mean(S_beta, 1);

% 去除前几个时间点（可选）
delta_power = delta_power(5:end);
theta_power = theta_power(5:end);
alpha_power = alpha_power(5:end);
beta_power = beta_power(5:end);

T = T(5:end);

%% 图1：绘制累积功率图（保留原有分析）
% 计算累积平均功率
delta_cumavg = cumsum(delta_power) ./ (1:length(delta_power));
theta_cumavg = cumsum(theta_power) ./ (1:length(theta_power));
alpha_cumavg = cumsum(alpha_power) ./ (1:length(alpha_power));
beta_cumavg = cumsum(beta_power) ./ (1:length(beta_power));

figure;
hold on;
plot(T, delta_cumavg, 'b', 'LineWidth', 1.5, 'DisplayName', 'Delta (0.5-4Hz)');
plot(T, theta_cumavg, 'r', 'LineWidth', 1.5, 'DisplayName', 'Theta (4-8Hz)');
plot(T, alpha_cumavg, 'g', 'LineWidth', 1.5, 'DisplayName', 'Alpha (8-13Hz)');
plot(T, beta_cumavg, 'm', 'LineWidth', 1.5, 'DisplayName', 'Beta (13-30Hz)');

xlabel('Time (s)');
ylabel('Cumulative Average Power');
title('脑电波段功率累积平均');
legend('show', 'Location', 'best');
grid on;

%% 图2：绘制时序功率图（不带平均）
figure;
hold on;
plot(T, delta_power, 'b', 'LineWidth', 1.5, 'DisplayName', 'Delta (0.5-4Hz)');
plot(T, theta_power, 'r', 'LineWidth', 1.5, 'DisplayName', 'Theta (4-8Hz)');
plot(T, alpha_power, 'g', 'LineWidth', 1.5, 'DisplayName', 'Alpha (8-13Hz)');
plot(T, beta_power, 'm', 'LineWidth', 1.5, 'DisplayName', 'Beta (13-30Hz)');

xlabel('Time (s)');
ylabel('Instantaneous Power');
title('脑电波段时序功率');
legend('show', 'Location', 'best');
grid on;

% 可选：调整y轴范围使图形更清晰
% ylim([0 max([delta_power, theta_power, alpha_power, beta_power]) * 1.1]);
%%
% 参数设置
fs = 250;               % 采样率(Hz)
window_length = 6;      % 窗长(秒)
step_size = 0.5;        % 滑动间隔(秒)
theta_band = [4, 8];    % Theta频带(4-8Hz)
beta_band = [13, 30];   % Beta频带(13-30Hz)

% 加载数据（假设data已存在）
[~, eeg_data] = EEGPreprocess(data, fs, "none");
% eeg_data = data;
t = (0:length(eeg_data)-1)/fs; % 时间向量

% 转换为样本数
window_samples = round(window_length * fs);
step_samples = round(step_size * fs);

% 初始化结果存储
results = struct();
phases = {'non_attention', 'attention'};
time_ranges = {[10, 70], [80, 140]};

% 对每个阶段进行处理
for i = 1:2
    % 提取阶段数据索引
    phase_idx = find(t >= time_ranges{i}(1) & t < time_ranges{i}(2));
    phase_data = eeg_data(phase_idx);
    
    % 计算滑动窗口数量
    n_windows = floor((length(phase_data) - window_samples) / step_samples) + 1;
    
    % 预分配数组
    ratios = zeros(1, n_windows);
    time_points = zeros(1, n_windows);
    
    % 对每个窗口计算功率比
    for win = 1:n_windows
        start_idx = phase_idx(1) + (win-1)*step_samples;
        end_idx = start_idx + window_samples - 1;
        segment = eeg_data(start_idx:end_idx);     
        % 存储结果
        ratios(win) =  compute_power_ratio(segment, fs, [8,13],theta_band, beta_band);
        time_points(win) = time_ranges{i}(1) + (win-1)*step_size + window_length/2;
    end
    
    % 保存结果
    results.(phases{i}).ratios = ratios;
    results.(phases{i}).times = time_points;
end

% 绘制对比图
figure('Position', [100, 100, 900, 500]);
hold on;

% 绘制非注意力阶段
plot(results.non_attention.times, results.non_attention.ratios, 'b-o',...
    'LineWidth', 1.5, 'MarkerFaceColor', 'b', 'DisplayName', '非注意力阶段');

% 绘制注意力阶段
plot(results.attention.times, results.attention.ratios, 'r-o',...
    'LineWidth', 1.5, 'MarkerFaceColor', 'r', 'DisplayName', '注意力阶段');

% 添加背景色块
yl = ylim;
patch([10 30 30 10], [yl(1) yl(1) yl(2) yl(2)], 'b',...
      'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', '非注意力时段');
patch([30 180 180 30], [yl(1) yl(1) yl(2) yl(2)], 'r',...
      'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', '注意力时段');

% 图形标注
xlabel('时间 (s)', 'FontSize', 12);
ylabel('Theta/Beta功率比', 'FontSize', 12);
title('TBR分析 (窗长6s,步长0.5s)', 'FontSize', 14);
legend('Location', 'best');
grid on;
box on;
xlim([0, 150]);

% 添加平均线
line([0 150], [mean(results.non_attention.ratios), mean(results.non_attention.ratios)],...
     'Color', 'b', 'LineStyle', '--', 'DisplayName', '非注意力平均');
line([0 150], [mean(results.attention.ratios), mean(results.attention.ratios)],...
     'Color', 'r', 'LineStyle', '--', 'DisplayName', '注意力平均');
 %%
data1 = importdata('D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电\没去轻微眼电\0526 XY 头顶 小程序_processed.txt');
data2 = importdata('D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电\去轻微眼电\0526 XY 头顶 小程序_processed.txt');

figure();
fs = 250; % 采样率 (Hz)
time_axis = (0:length(data1)-1) / fs; % 时间轴（秒）

% 绘制信号并设置标签
% plot(time_axis, data1, 'b', 'LineWidth', 1, 'DisplayName', 'Raw EEG (with EOG)');
% hold on;
plot(time_axis, data2, 'r', 'LineWidth', 1, 'DisplayName', 'Processed EEG (EOG removed)');

% 坐标轴和标题设置
xlabel('Time (s)'); 
ylabel('Amplitude (mV)'); 
title('EEG Signal Before/After EOG Removal');
legend('show'); % 显示图例
grid on; % 添加网格线

% 可选：调整坐标范围以突出差异
xlim([0, max(time_axis)]); % 完整时间范围
ylim([min([data1; data2])*1.1, max([data1; data2])*1.1]); % 自动适应幅度范围
grid on; % 可选：显示网格