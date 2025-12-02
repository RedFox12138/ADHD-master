%% 单通道 LFP analysis（保留原特征函数，新增TBR/样本熵独立时序图）
clc;
close all;
clear all;

% --- 全局字体大小设置（在此处统一修改所有文字大小）---
font_sizes = struct();
font_sizes.title = 20;        % 主图表标题字体大小
font_sizes.axis_label = 18;   % 坐标轴标签字体大小
font_sizes.legend = 16;       % 图例字体大小
font_sizes.subtitle = 16;     % 子图标题字体大小
font_sizes.sub_axis_label = 14; % 子图坐标轴标签字体大小

% --- 用户需要设定的参数 ---
target_file = 'D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电\1202 XY额头躲避游戏2_processed.txt'; 
Fs = 250; % 采样率 (Hz)

% 定义两个时间段
time_periods.names = {'静息', '刺激'};
time_periods.ranges = {[10, 70], [82, 140]};
time_periods.var_names = {'Resting', 'Calculate'};
time_periods.colors = {'b', 'r'};

% 滑动窗口分析参数
window_length = 6;      % 窗长 (秒)
step_size = 0.5;       % 滑动步长 (秒)
theta_band = [4, 8];  
beta_band = [14, 25]; 

% 检查文件是否存在
if ~exist(target_file, 'file')
    error('指定的文件不存在: %s', target_file);
end

% 从文件路径中提取文件名
[~, filename, ext] = fileparts(target_file);
display_filename = [filename, ext];

fprintf('--- 开始处理文件: %s ---\n', display_filename);

try
    %% a. 加载和预处理数据
    data = importdata(target_file);
    eeg_data = data(:, 1);
    time_axis = (0:length(eeg_data)-1) / Fs;

    figure();
    plot(time_axis, eeg_data, 'DisplayName', '预处理信号', 'LineWidth', 1.2);  
    xlabel('时间 (s)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    ylabel('幅值', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    legend('show', 'Location', 'best', 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
    title(['预处理LFP信号 - ' display_filename], 'FontName', 'SimSun', 'FontSize', font_sizes.title);
    grid on;  

    t = (0:length(eeg_data)-1) / Fs;

    %% b. 功率谱密度对比图（保留原代码）
    figure('Name', ['功率谱 - ' display_filename]);
    hold on;
    
    plot_handles_pds = [];
    for i = 1:numel(time_periods.names)
        time_range = time_periods.ranges{i};
        data_indices = round(time_range(1)*Fs) : round(time_range(2)*Fs);
        data_segment = eeg_data(data_indices);
        
        [p_spectrum, f_axis] = LFP_Win_Process(data_segment, Fs, 1, window_length, "none");
        freq_idx = find(f_axis >= 0 & f_axis <= 50);
        h = plot(f_axis(freq_idx), p_spectrum(freq_idx), ...
                 'Color', time_periods.colors{i}, 'LineWidth', 2);
        plot_handles_pds(i) = h;
    end
    
    hold off;
    xlabel('Frequency (Hz)', 'FontName', 'Times New Roman', 'FontSize', font_sizes.axis_label);
    ylabel('Power Spectrum (dB)', 'FontName', 'Times New Roman', 'FontSize', font_sizes.axis_label);
    legend(plot_handles_pds, time_periods.names, 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
    title(['功率谱密度对比: ', display_filename], 'FontName', 'SimSun', 'FontSize', font_sizes.title, 'Interpreter', 'none');
    grid on;
    
    %% c. 滑动窗口分析（关键修改：分开存储TBR和样本熵，避免覆盖）
    window_samples = round(window_length * Fs);
    step_samples = round(step_size * Fs);
    results = struct(); % 新增：存储TBR和样本熵的独立结果
    
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        time_range = time_periods.ranges{i};
        phase_idx_global = find(t >= time_range(1) & t < time_range(2));
        n_windows = floor((length(phase_idx_global) - window_samples) / step_samples) + 1;
        
        % 关键修改：新增sampen_array和tbr_array，分开存储两个特征
        sampen_array = zeros(1, n_windows); % 样本熵数组
        tbr_array = zeros(1, n_windows);    % TBR数组
        time_points = zeros(1, n_windows);  % 窗口中心时间点
        
        for win = 1:n_windows
            start_idx = phase_idx_global(1) + (win-1)*step_samples;
            end_idx = start_idx + window_samples - 1;
            
            if end_idx > length(eeg_data)
                continue;
            end
            
            segment = eeg_data(start_idx:end_idx);
            
            % 1. 计算样本熵（保留原代码调用逻辑）
            Samp = SampEn(segment);
            sampen_array(win) = Samp(3); % 原代码取Samp(3)，保持不变
            
            % 2. 计算TBR（保留原代码调用逻辑）
            tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
            tbr_array(win) = tbr_val; % 存入TBR数组，不再覆盖样本熵
            
            % 记录窗口中心时间
            time_points(win) = t(start_idx) + (window_length / 2);
        end
        
        % 去除零值（排除越界窗口），存入results结构体
        results.(phase_name).sampen = sampen_array(sampen_array ~= 0); % 样本熵结果
        results.(phase_name).tbr = tbr_array(tbr_array ~= 0);          % TBR结果
        results.(phase_name).times = time_points(time_points ~= 0);    % 时间点
    end
    
    %% 新增1：绘制样本熵时序图（单独窗口）
    figure('Name', ['样本熵时序图 - ' display_filename], 'Position', [100, 100, 1000, 600]);
    hold on; grid on; box on;
    plot_handles_sampen = [];
    
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        % 绘制样本熵曲线（带标记点）
        h = plot(results.(phase_name).times, results.(phase_name).sampen, ...
                 '-o', 'Color', time_periods.colors{i}, 'LineWidth', 1.5, ...
                 'MarkerFaceColor', time_periods.colors{i}, 'MarkerSize', 6, ...
                 'DisplayName', time_periods.names{i});
        plot_handles_sampen(i) = h;
        
        % 绘制样本熵均值虚线
        sampen_mean = mean(results.(phase_name).sampen, 'omitnan');
        line(time_periods.ranges{i}, [sampen_mean, sampen_mean], ...
             'Color', time_periods.colors{i}, 'LineStyle', '--', 'LineWidth', 2);
        
        % 绘制时间段背景色（增强区分）
        yl = ylim;
        patch([time_periods.ranges{i}(1) time_periods.ranges{i}(2) time_periods.ranges{i}(2) time_periods.ranges{i}(1)], ...
              [yl(1) yl(1) yl(2) yl(2)], time_periods.colors{i}, ...
              'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    
    % 图表标注（保持原代码字体风格）
    xlabel('时间 (s)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    ylabel('样本熵值', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    title(['滑动窗口样本熵分析 (窗长6s, 步长0.5s) - ', display_filename], ...
          'FontName', 'SimSun', 'FontSize', font_sizes.title, 'Interpreter', 'none');
    legend(plot_handles_sampen, time_periods.names, 'Location', 'best', 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
    xlim([0, time_periods.ranges{end}(2) + 10]);
    hold off;

    %% 新增2：绘制TBR时序图（单独窗口）
    figure('Name', ['TBR时序图 - ' display_filename], 'Position', [200, 200, 1000, 600]);
    hold on; grid on; box on;
    plot_handles_tbr = [];
    
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        % 绘制TBR曲线（带标记点，用方形标记区分样本熵）
        h = plot(results.(phase_name).times, results.(phase_name).tbr, ...
                 '-s', 'Color', time_periods.colors{i}, 'LineWidth', 1.5, ...
                 'MarkerFaceColor', time_periods.colors{i}, 'MarkerSize', 6, ...
                 'DisplayName', time_periods.names{i});
        plot_handles_tbr(i) = h;
        
        % 绘制TBR均值虚线
        tbr_mean = mean(results.(phase_name).tbr, 'omitnan');
        line(time_periods.ranges{i}, [tbr_mean, tbr_mean], ...
             'Color', time_periods.colors{i}, 'LineStyle', '--', 'LineWidth', 2);
        
        % 绘制时间段背景色
        yl = ylim;
        patch([time_periods.ranges{i}(1) time_periods.ranges{i}(2) time_periods.ranges{i}(2) time_periods.ranges{i}(1)], ...
              [yl(1) yl(1) yl(2) yl(2)], time_periods.colors{i}, ...
              'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    
    % 图表标注（保持原代码风格）
    xlabel('时间 (s)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    ylabel('TBR (Theta/Beta功率比)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    title(['滑动窗口TBR分析 (窗长6s, 步长0.5s) - ', display_filename], ...
          'FontName', 'SimSun', 'FontSize', font_sizes.title, 'Interpreter', 'none');
    legend(plot_handles_tbr, time_periods.names, 'Location', 'best', 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
    xlim([0, time_periods.ranges{end}(2) + 10]);
    hold off;

    % 滑动窗口特征统计结果（补充TBR统计）
    fprintf('\n\n--- 滑动窗口样本熵统计结果 ---\n');
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        current_sampen = results.(phase_name).sampen;
        
        mean_val = mean(current_sampen, 'omitnan');
        var_val = var(current_sampen, 'omitnan');
        
        fprintf('时间段 "%s":\n', time_periods.names{i});
        fprintf('  - 均值 (Mean)    : %f\n', mean_val);
        fprintf('  - 方差 (Variance) : %f\n', var_val);
    end
    
    fprintf('\n--- 滑动窗口TBR统计结果 ---\n');
    for i = 1:numel(time_periods.names)
        phase_name = time_periods.var_names{i};
        current_tbr = results.(phase_name).tbr;
        
        mean_val = mean(current_tbr, 'omitnan');
        var_val = var(current_tbr, 'omitnan');
        
        fprintf('时间段 "%s":\n', time_periods.names{i});
        fprintf('  - 均值 (Mean)    : %f\n', mean_val);
        fprintf('  - 方差 (Variance) : %f\n', var_val);
    end
    fprintf('----------------------------------\n');
    
catch ME
    fprintf('处理文件 %s 时发生错误: %s\n', display_filename, ME.message);
end

fprintf('--- 处理完毕 ---\n');
%%
% 各波段滤波与分析（保留原代码，无修改）
fs = 250;
t = (0:length(eeg_data)-1)/fs;

%% 设计各波段的带通滤波器
delta_low = 0.5; delta_high = 4;
[b_delta, a_delta] = butter(4, [delta_low, delta_high]/(fs/2), 'bandpass');

theta_low = 4; theta_high = 8;
[b_theta, a_theta] = butter(4, [theta_low, theta_high]/(fs/2), 'bandpass');

alpha_low = 8; alpha_high = 13;
[b_alpha, a_alpha] = butter(4, [alpha_low, alpha_high]/(fs/2), 'bandpass');

beta_low = 13; beta_high = 30;
[b_beta, a_beta] = butter(4, [beta_low, beta_high]/(fs/2), 'bandpass');

%% 滤波得到各波段时域信号
delta_signal = filtfilt(b_delta, a_delta, eeg_data);
theta_signal = filtfilt(b_theta, a_theta, eeg_data);
alpha_signal = filtfilt(b_alpha, a_alpha, eeg_data);
beta_signal = filtfilt(b_beta, a_beta, eeg_data);

%% 绘制原始信号和各波段时域波形
figure('Position', [200, 200, 1000, 800]);

% 原始信号
subplot(5,1,1);
plot(t, eeg_data, 'k', 'LineWidth', 1.2);
xlabel('Time (s)', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
ylabel('Amplitude', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
title('原始脑电信号', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
grid on;

% Delta波段
subplot(5,1,2);
plot(t, delta_signal, 'b', 'LineWidth', 1.2);
xlabel('Time (s)', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
ylabel('Amplitude', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
title('Delta波段 (0.5-4 Hz)', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
grid on;

% Theta波段
subplot(5,1,3);
plot(t, theta_signal, 'r', 'LineWidth', 1.2);
xlabel('Time (s)', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
ylabel('Amplitude', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
title('Theta波段 (4-8 Hz)', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
grid on;

% Alpha波段
subplot(5,1,4);
plot(t, alpha_signal, 'g', 'LineWidth', 1.2);
xlabel('Time (s)', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
ylabel('Amplitude', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
title('Alpha波段 (8-13 Hz)', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
grid on;

% Beta波段
subplot(5,1,5);
plot(t, beta_signal, 'm', 'LineWidth', 1.2);
xlabel('Time (s)', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);
ylabel('Amplitude', 'FontName', 'Times New Roman', 'FontSize', font_sizes.sub_axis_label);