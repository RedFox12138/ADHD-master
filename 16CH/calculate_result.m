%% 多通道 LFP analysis (整合版)
clc
close all;
clear all;

% --- 1. 数据加载 ---
% 加载包含所有16个通道数据的.mat文件
% all_data 变量应为一个 16*n 的矩阵
try
    loaded_data = load('Preprocessed\0820\0820 XY睁眼闭眼1_preprocessed.mat');
    % 假设.mat文件中的变量名为 'preprocessed_data' 或其他，需要找到它
    % 如果直接就是数据矩阵，那么 loaded_data 就是一个结构体，我们需要提取里面的变量
    data_fields = fieldnames(loaded_data);
    all_data = loaded_data.(data_fields{1});
catch
    disp('无法加载.mat文件，请确保路径和文件名正确，并且文件内包含数据矩阵。');
    disp('将使用随机数据进行演示。');
    all_data = randn(16, 250 * 220); % 生成16通道，220秒的随机数据以进行演示
end

% 确认数据维度，确保通道在行，时间在列
if size(all_data, 2) < size(all_data, 1)
    all_data = all_data';
end

% 获取通道数
num_channels = size(all_data, 1);
if num_channels ~= 16
    disp('警告：检测到的通道数不是16，将根据实际通道数调整绘图网格。');
    % 动态调整网格布局
    grid_rows = ceil(sqrt(num_channels));
    grid_cols = ceil(num_channels / grid_rows);
else
    grid_rows = 4;
    grid_cols = 4;
end

fprintf('数据加载完成，共 %d 个通道。\n', num_channels);

% --- 2. 在循环开始前，为每种类型的图创建一个大的 Figure 窗口 ---
% 设置一个较大的屏幕位置和尺寸，方便查看
fig_position = [50, 50, 1400, 800]; 

h_fig1 = figure('Name', '频谱对比图 (所有通道)', 'Position', fig_position);
h_fig2 = figure('Name', '滤波时域信号 (所有通道)', 'Position', fig_position);
h_fig3 = figure('Name', '累积功率图 (所有通道)', 'Position', fig_position);
h_fig4 = figure('Name', '时序功率图 (所有通道)', 'Position', fig_position);
h_fig5 = figure('Name', 'TBR 分析 (所有通道)', 'Position', fig_position);


% --- 3. 循环处理每个通道 ---
for ch = 1:num_channels
    % 从 all_data 中提取当前通道的数据
    data = all_data(ch,:);
    
    fprintf('正在处理通道 %d ...\n', ch);
    
    % =================================================================
    % 以下代码将在循环内对每个通道的 'data' 执行
    % 并且将结果绘制到对应的大图的子图中
    % =================================================================
    
    %% Section 1: 功率谱对比分析
    Fs = 250;
    % 确保索引不超过数据长度
    end_air_time = min(60, size(data, 2)/Fs);
    end_nh3_time = min(120, size(data, 2)/Fs);
    
    air_index = [1:1:end_air_time*Fs]; 
    nh3_index = [end_air_time*Fs: 1: end_nh3_time*Fs];

    if isempty(air_index) || isempty(nh3_index)
        fprintf('通道 %d 数据长度不足，跳过功率谱分析。\n', ch);
    else
        air_d1 = data(air_index);
        nh3_d1 = data(nh3_index);

        winlenth = 6;
        % 假设 LFP_Win_Process 函数已在您的MATLAB环境中
        [p_theta1_nh3, f_theta1] = LFP_Win_Process(nh3_d1, Fs, 1, winlenth, "none");
        [p_theta1_air, ~] = LFP_Win_Process(air_d1, Fs, 1, winlenth, "none");

        % --- 绘图到 h_fig1 ---
        figure(h_fig1); % 激活第一个图形窗口
        subplot(grid_rows, grid_cols, ch); % 选择当前通道对应的子图

        index1 = find(f_theta1 >= 0);
        index2 = find(f_theta1 <= 50);
        index = [index1(1):index2(end)];

        plot(f_theta1(index), p_theta1_nh3(index), 'LineWidth', 1.5);
        hold on;
        plot(f_theta1(index), p_theta1_air(index), 'LineWidth', 1.5);
        hold off;
        xlabel('Frequency (Hz)');
        ylabel('Power (dB)');
        title(['Channel ', num2str(ch)]);
        if ch == 1 % 只在第一个子图上显示图例
            legend('闭眼', '睁眼');
        end
    end
    
    %% Section 2: 各波段时域信号滤波与绘制
    fs = 250;
    eeg_data = data;
    t = (0:length(eeg_data)-1)/fs;

    [b_delta, a_delta] = butter(4, [0.5, 4]/(fs/2), 'bandpass');
    [b_theta, a_theta] = butter(4, [4, 8]/(fs/2), 'bandpass');
    [b_alpha, a_alpha] = butter(4, [8, 13]/(fs/2), 'bandpass');
    [b_beta, a_beta] = butter(4, [13, 30]/(fs/2), 'bandpass');

    delta_signal = filtfilt(b_delta, a_delta, eeg_data);
    theta_signal = filtfilt(b_theta, a_theta, eeg_data);
    alpha_signal = filtfilt(b_alpha, a_alpha, eeg_data);
    beta_signal = filtfilt(b_beta, a_beta, eeg_data);

    % --- 绘图到 h_fig2 (修改版：所有波段画在同一子图) ---
    figure(h_fig2); % 激活第二个图形窗口
    subplot(grid_rows, grid_cols, ch); % 选择当前通道对应的子图
    
    % 为了更好的可视化，我们对滤波后的信号进行一点垂直偏移
    offset = max(abs(eeg_data)) * 1.5;
    plot(t, eeg_data, 'k', 'LineWidth', 1); hold on;
    plot(t, delta_signal + offset, 'b', 'LineWidth', 1);
    plot(t, theta_signal + 2*offset, 'r', 'LineWidth', 1);
    plot(t, alpha_signal + 3*offset, 'g', 'LineWidth', 1);
    plot(t, beta_signal + 4*offset, 'm', 'LineWidth', 1);
    hold off;
    
    % 移除y轴刻度，因为它现在代表的是偏移后的相对幅度
    set(gca,'ytick',[])
    xlabel('Time (s)');
    title(['Channel ', num2str(ch)]);
    xlim([t(1), t(end)]);
    if ch == 1
        legend('Raw', 'Delta', 'Theta', 'Alpha', 'Beta', 'Location', 'northwest');
    end

    %% Section 3: 累积功率图和时序功率图
    window = hamming(512); noverlap = 256; nfft = 1024;
    [S, F, T] = spectrogram(eeg_data, window, noverlap, nfft, fs);

    delta_band = (F >= 0.5 & F <= 4);
    theta_band_stft = (F >= 4 & F <= 8);
    alpha_band = (F >= 8 & F <= 13);
    beta_band_stft = (F >= 13 & F <= 30);

    S_delta = abs(S(delta_band, :)).^2;
    S_theta = abs(S(theta_band_stft, :)).^2;
    S_alpha = abs(S(alpha_band, :)).^2;
    S_beta = abs(S(beta_band_stft, :)).^2;

    delta_power = mean(S_delta, 1);
    theta_power = mean(S_theta, 1);
    alpha_power = mean(S_alpha, 1);
    beta_power = mean(S_beta, 1);
    
    % 去掉前几个点可能存在的边界效应
    if length(T) > 4
        T = T(5:end);
        delta_power = delta_power(5:end);
        theta_power = theta_power(5:end);
        alpha_power = alpha_power(5:end);
        beta_power = beta_power(5:end);
    end
    
    % --- 绘图1：累积功率图到 h_fig3 ---
    delta_cumavg = cumsum(delta_power) ./ (1:length(delta_power));
    theta_cumavg = cumsum(theta_power) ./ (1:length(theta_power));
    alpha_cumavg = cumsum(alpha_power) ./ (1:length(alpha_power));
    beta_cumavg = cumsum(beta_power) ./ (1:length(beta_power));

    figure(h_fig3); % 激活第三个图形窗口
    subplot(grid_rows, grid_cols, ch);
    hold on;
    plot(T, delta_cumavg, 'b', 'LineWidth', 1);
    plot(T, theta_cumavg, 'r', 'LineWidth', 1);
    plot(T, alpha_cumavg, 'g', 'LineWidth', 1);
    plot(T, beta_cumavg, 'm', 'LineWidth', 1);
    hold off;
    xlabel('Time (s)'); ylabel('Cumulative Avg Power');
    title(['Channel ', num2str(ch)]);
    grid on;
    if ch == 1
        legend('Delta', 'Theta', 'Alpha', 'Beta');
    end

    % --- 绘图2：时序功率图到 h_fig4 ---
    figure(h_fig4); % 激活第四个图形窗口
    subplot(grid_rows, grid_cols, ch);
    hold on;
    plot(T, delta_power, 'b', 'LineWidth', 1);
    plot(T, theta_power, 'r', 'LineWidth', 1);
    plot(T, alpha_power, 'g', 'LineWidth', 1);
    plot(T, beta_power, 'm', 'LineWidth', 1);
    hold off;
    xlabel('Time (s)'); ylabel('Instantaneous Power');
    title(['Channel ', num2str(ch)]);
    grid on;
    if ch == 1
        legend('Delta', 'Theta', 'Alpha', 'Beta');
    end

    %% Section 4: TBR (Theta/Beta Ratio) 分析
    % ======================= 代码修改开始 =======================
    
    % 确保数据长度足够进行此分析
    if length(eeg_data)/fs < 205
        fprintf('通道 %d 数据长度不足210s，跳过TBR分析。\n', ch);
    else
        window_length = 4; step_size = 2;
        theta_band = [4, 8]; beta_band = [13, 30];delta_band = [1,4];

        t_tbr = (0:length(eeg_data)-1)/fs;
        window_samples = round(window_length * fs);
        step_samples = round(step_size * fs);

        results = struct();
        % 定义三个阶段和对应的时间范围
        phases = {'period_1', 'period_2', 'period_3'};
        time_ranges = {[10, 70], [80, 140], [150, 205]};

        % 循环处理三个阶段
        for i = 1:3
            phase_idx_logical = (t_tbr >= time_ranges{i}(1) & t_tbr < time_ranges{i}(2));
            phase_data = eeg_data(phase_idx_logical);
            
            n_windows = floor((length(phase_data) - window_samples) / step_samples) + 1;
            
            ratios = zeros(1, n_windows);
            time_points = zeros(1, n_windows);
            
            for win = 1:n_windows
                start_idx_in_phase = (win-1)*step_samples + 1;
                end_idx_in_phase = start_idx_in_phase + window_samples - 1;
                segment = phase_data(start_idx_in_phase:end_idx_in_phase);
                
                % 如果没有 compute_power_ratio 函数，我们可以用pwelch临时计算
                ratios(win) = compute_power_ratio(segment, fs, delta_band, theta_band,beta_band);
%                 [pxx, f] = pwelch(segment, [], [], [], fs);
%                 power_theta = bandpower(pxx, f, theta_band, 'psd');
%                 power_beta = bandpower(pxx, f, beta_band, 'psd');
%                 if power_beta > 0
%                     ratios(win) = power_theta / power_beta;
%                 else
%                     ratios(win) = NaN;
%                 end

                time_points(win) = time_ranges{i}(1) + (win-1)*step_size + window_length/2;
            end
            
            results.(phases{i}).ratios = ratios;
            results.(phases{i}).times = time_points;
        end

        % --- 绘图到 h_fig5 ---
        figure(h_fig5); % 激活第五个图形窗口
        subplot(grid_rows, grid_cols, ch);
        
        hold on;
        % 绘制三个时间段的TBR值
        plot(results.period_1.times, results.period_1.ratios, 'b-o', 'MarkerSize', 3);
        plot(results.period_2.times, results.period_2.ratios, 'r-o', 'MarkerSize', 3);
        plot(results.period_3.times, results.period_3.ratios, 'g-o', 'MarkerSize', 3); % 新增

        yl = ylim;
        % 绘制三个时间段的背景色块
        patch([10 70 70 10], [yl(1) yl(1) yl(2) yl(2)], 'b', 'FaceAlpha', 0.05, 'EdgeColor', 'none');
        patch([80 140 140 80], [yl(1) yl(1) yl(2) yl(2)], 'r', 'FaceAlpha', 0.05, 'EdgeColor', 'none');
        patch([150 210 210 150], [yl(1) yl(1) yl(2) yl(2)], 'g', 'FaceAlpha', 0.05, 'EdgeColor', 'none'); % 新增
        
        % 绘制三个时间段的平均值虚线
        line([10 70], [mean(results.period_1.ratios, 'omitnan'), mean(results.period_1.ratios, 'omitnan')], 'Color', 'b', 'LineStyle', '--');
        line([80 140], [mean(results.period_2.ratios, 'omitnan'), mean(results.period_2.ratios, 'omitnan')], 'Color', 'r', 'LineStyle', '--');
        line([150 210], [mean(results.period_3.ratios, 'omitnan'), mean(results.period_3.ratios, 'omitnan')], 'Color', 'g', 'LineStyle', '--'); % 新增
        
        hold off;
        xlabel('Time (s)');
        ylabel('Theta/Beta Ratio');
        title(['Channel ', num2str(ch)]);
        xlim([0, 220]); % 调整X轴范围以显示所有数据
        grid on;
        if ch == 1
            % 更新图例
            legend('时段 1 (10-70s)', '时段 2 (80-140s)', '时段 3 (150-210s)', 'Location', 'best');
        end
    end
    % ======================= 代码修改结束 =======================

end % 结束对所有通道的循环

% --- 4. 为每个 Figure 添加总标题 ---
figure(h_fig1);
sgtitle('所有通道功率谱对比', 'FontSize', 16, 'FontWeight', 'bold');

figure(h_fig2);
sgtitle('所有通道 - 原始及滤波后时域信号', 'FontSize', 16, 'FontWeight', 'bold');

figure(h_fig3);
sgtitle('所有通道 - 脑电波段功率累积平均', 'FontSize', 16, 'FontWeight', 'bold');

figure(h_fig4);
sgtitle('所有通道 - 脑电波段时序功率', 'FontSize', 16, 'FontWeight', 'bold');

figure(h_fig5);
sgtitle('所有通道 - TBR 分析 (窗长4s, 步长2s)', 'FontSize', 16, 'FontWeight', 'bold');


fprintf('所有 %d 个通道处理完毕！\n', num_channels);

% --- 依赖的函数 (如果您的环境中没有这些函数，请将它们放在同一目录下或添加到MATLAB路径) ---
% function [p, f] = LFP_Win_Process(data, Fs, fmin, fmax, option)
%     % 您的 LFP_Win_Process 函数实现
%     % 这里提供一个基于 pwelch 的简单示例
%     [p,f] = pwelch(data, hamming(Fs*2), Fs, Fs*2, Fs);
%     p = 10*log10(p);
% end
% 
% function ratio = compute_power_ratio(segment, fs, band1, band2)
%     % 您的 compute_power_ratio 函数实现
%     % 这里提供一个基于 bandpower 的简单示例
%     power1 = bandpower(segment, fs, band1);
%     power2 = bandpower(segment, fs, band2);
%     if power2 > 0
%         ratio = power1 / power2;
%     else
%         ratio = NaN;
%     end
% end