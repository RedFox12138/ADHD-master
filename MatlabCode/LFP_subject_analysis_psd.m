%% 单通道 LFP analysis
clc;
close all;
clear all;

% --- 用户需要设定的参数 ---
% 请将这里替换为您要分析的单个txt文件的完整路径
target_file = 'D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电\0903 XY额头躲避游戏3_processed.txt'; 
% EEG信号参数 D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电
Fs = 250; % 采样率 (Hz)

% 定义三个时间段
time_periods.names = {'静息', '刺激'}; % 用于图例显示的名称
time_periods.ranges = {[10, 70], [80, 140]}; % 每个时间段的起止时间 [开始(s), 结束(s)]
time_periods.var_names = {'Resting', 'Calculate','Tracking'}; % 用于程序变量的英文名称 (必须是合法的变量名)
time_periods.colors = {'b', 'r','g'}; % 每个时间段在绘图时对应的颜色

% 滑动窗口分析参数
window_length = 6;      % 窗长 (秒)
step_size = 0.5;       % 滑动步长 (秒)
% 频带定义 (如果使用功率比计算)
theta_band = [4, 8];  
beta_band = [14, 25]; 

% 检查文件是否存在
if ~exist(target_file, 'file')
    error('指定的文件不存在: %s', target_file);
end

% 从文件路径中提取文件名，用于图表标题
[~, filename, ext] = fileparts(target_file);
display_filename = [filename, ext];

fprintf('--- 开始处理文件: %s ---\n', display_filename);

try
    %% a. 加载和预处理数据
    data = importdata(target_file);
    % 假设有效数据在第一列
    eeg_data = data(:, 1);
    % 如果需要，可以在这里添加其他预处理步骤，例如EEGPreprocess函数
%     [~, plot_data] = EEGPreprocess(eeg_data, Fs, "none");
%     plot_data =  eeg_data;
    % 计算时间轴（单位：秒）
    time_axis = (0:length(eeg_data)-1) / Fs;  % 时间 = 采样点 / 采样率

    figure();
    plot(time_axis, eeg_data, 'DisplayName', '去眼电信号');  % 原始信号
%     hold on;
%     plot(time_axis, plot_data, 'DisplayName', '预处理信号'); % 预处理信号

    % 设置横坐标标签（xlabel）和图例（legend）
    xlabel('时间 (s)');
    ylabel('幅值');
    legend('show', 'Location', 'best');  % 显示图例，自动选择最佳位置
    grid on;  % 可选：添加网格线

    t = (0:length(eeg_data)-1) / Fs; % 创建时间向量

    %% b. 第一个分析：功率谱密度对比图
    figure('Name', ['功率谱 - ' display_filename]);
    hold on;
    
    plot_handles_pds = []; % 用于存储绘图句柄以创建图例
    
    for i = 1:numel(time_periods.names)
        % 提取当前时间段的数据
        time_range = time_periods.ranges{i};
        data_indices = round(time_range(1)*Fs) : round(time_range(2)*Fs);
        data_segment = eeg_data(data_indices);
        
        % 使用您的 LFP_Win_Process 函数计算功率谱
        % 注意：您需要确保 LFP_Win_Process.m 在MATLAB路径中
        [p_spectrum, f_axis] = LFP_Win_Process(data_segment, Fs, 1, window_length, "none");
        
        % 绘制0-50Hz范围内的功率谱
        freq_idx = find(f_axis >= 0 & f_axis <= 50);
        h = plot(f_axis(freq_idx), p_spectrum(freq_idx), ...
                 'Color', time_periods.colors{i}, 'LineWidth', 2);
        plot_handles_pds(i) = h;
    end
    
    hold off;
    xlabel('Frequency (Hz)', 'FontName', 'Times New Roman', 'FontSize', 12);
    ylabel('Power Spectrum (dB)', 'FontName', 'Times New Roman', 'FontSize', 12);
    legend(plot_handles_pds, time_periods.names, 'FontName', 'SimSun', 'FontSize', 12); % 使用SimSun支持中文
    title(['功率谱密度对比: ', display_filename], 'Interpreter', 'none'); % 'Interpreter', 'none' 防止文件名中的下划线被转义
    grid on;
    
    %% c. 第二个分析：滑动窗口样本熵（或TBR）分析
    
    % 转换为样本点数
    window_samples = round(window_length * Fs);
    step_samples = round(step_size * Fs);
    
    results = struct(); % 初始化用于存储结果的结构体
    
    % 对每个时间段进行处理
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        time_range = time_periods.ranges{i};
        
        % 提取该时间段的数据在原始信号中的索引
        phase_idx_global = find(t >= time_range(1) & t < time_range(2));
        
        % 计算滑动窗口数量
        n_windows = floor((length(phase_idx_global) - window_samples) / step_samples) + 1;
        
        % 预分配数组
        ratios = zeros(1, n_windows);
        time_points = zeros(1, n_windows);
        
        % 在每个窗口上计算指标
        for win = 1:n_windows
            start_idx = phase_idx_global(1) + (win-1)*step_samples;
            end_idx = start_idx + window_samples - 1;
            
            if end_idx > length(eeg_data)
                continue;
            end
            
            segment = eeg_data(start_idx:end_idx);
%             segment = EEGPreprocess(segment, Fs, "none");
            % --- 计算指标 ---
            % 使用您的 SampEn 函数计算样本熵
            % 注意：您需要确保 SampEn.m 在MATLAB路径中
            
%             [Samp, ~, ~] = SampEn(segment);
%             ratios(win) = Samp(3); % 假设第三个输出是您需要的值

%               [feature,~,~] = calculateComplexity(segment);
%               ratios(win)= feature;
            
%             % 如果要计算功率比，取消注释下面这行，并注释掉上面的SampEn部分
%              ratios(win) = compute_power_ratio(segment, Fs, theta_band, beta_band);

%             out = get_rhythm_features_fft(segment,Fs);
%             ratios(win) = get_attention_score(out);

%             Samp = FuzzEn(segment);
%             ratios(win) = Samp(1); 
%              [feature,~,~] = calculateComplexity(segment,250);
%               ratios(win)= feature;
              
              Samp = SampEn(segment);
              ratios(win) = Samp(3); 
            
            % 计算每个窗口中心点对应的时间
            time_points(win) = t(start_idx) + (window_length / 2);
        end
        
        % 保存结果
        results.(phase_name).ratios = ratios(ratios~=0); % 移除可能未计算的零值
        results.(phase_name).times = time_points(time_points~=0);
    end
    

    figure('Name', ['滑动窗口分析 - ' display_filename], 'Position', [100, 100, 1000, 600]);
    hold on;
    
    plot_handles_sw = []; % 用于图例
    
    % 绘制每个时间段的结果和平均线
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        h_plot = plot(results.(phase_name).times, results.(phase_name).ratios, ...
                      '-o', 'Color', time_periods.colors{i}, 'LineWidth', 1.5, ...
                      'MarkerFaceColor', time_periods.colors{i}, 'MarkerSize', 4);
        plot_handles_sw(i) = h_plot; % 存储句柄
        
        mean_val = mean(results.(phase_name).ratios, 'omitnan');
        line(time_periods.ranges{i}, [mean_val, mean_val], ...
             'Color', time_periods.colors{i}, 'LineStyle', '--', 'LineWidth', 2);
    end
    
    % 添加背景色块以区分时间段
    yl = ylim; % 获取当前Y轴范围
    for i = 1:numel(time_periods.names)
        time_range = time_periods.ranges{i};
        patch([time_range(1) time_range(2) time_range(2) time_range(1)], ...
              [yl(1) yl(1) yl(2) yl(2)], time_periods.colors{i}, ...
              'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    
    % 图形美化
    xlabel('时间 (s)', 'FontSize', 12);
    ylabel('样本熵值', 'FontSize', 12); % 如果计算TBR，请改为 'Theta/Beta功率比'
    title(['滑动窗口分析 (窗长6s, 步长0.5s) - ', display_filename], 'Interpreter', 'none');
    legend(plot_handles_sw, time_periods.names, 'Location', 'best', 'FontName', 'SimSun');
    grid on;
    box on;
    xlim([0, time_periods.ranges{end}(2) + 10]); % 动态设置X轴范围
    
    hold off;

    % =================================================================
    % --- 新增代码: 在命令窗口中显示每个时间段的均值和方差 ---
    % =================================================================
    fprintf('\n\n--- 滑动窗口样本熵统计结果 ---\n');
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        
        % 从已保存的结果中获取数据
        current_ratios = results.(phase_name).ratios;
        
        % 计算均值和方差 (忽略NaN值)
        mean_val = mean(current_ratios, 'omitnan');
        var_val = var(current_ratios, 'omitnan');
        
        % 在命令窗口打印结果
        fprintf('时间段 "%s":\n', time_periods.names{i});
        fprintf('  - 均值 (Mean)    : %f\n', mean_val);
        fprintf('  - 方差 (Variance) : %f\n', var_val);
    end
    fprintf('----------------------------------\n');
    % =================================================================
    
catch ME
    % 如果处理文件时出错，打印错误信息
    fprintf('处理文件 %s 时发生错误: %s\n', display_filename, ME.message);
end

fprintf('--- 处理完毕 ---\n');
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