%% plot_game_xsampen_timeseries.m
% 画游戏过程的 XSampEn 时序图并显示自适应阈值
% 逻辑参考: ADHD-master/MatlabCode/batch_feature_compare.m

clear; close all; clc;

% ========== 用户配置 ==========
data_file = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\微信小程序\TXT文件\预处理后的完整数据，未分段\XY\0106 XY微信小程序信号图-存活251s-舒尔特23s_processed.txt'; % 指定 mat 文件
Fs = 250;                % 采样率 (Hz)
window_length = 6;       % 窗长 (秒)
step_size = 2;           % 窗口步长 (秒) - 跟 batch_feature_compare 保持一致

time_periods.names = {'静息', '注意力'};
time_periods.ranges = {[10, 40], [40, Inf]}; % 默认时间段（可根据文件调整）
time_periods.colors = {[0, 0.4470, 0.7410], [0.8500, 0.3250, 0.0980]};

% 阈值自适应参数
threshold_duration = 12;    % 持续多少秒触发阈值调整
threshold_up_factor = 1.10; % 上调整倍数
threshold_down_factor = 0.95; % 下调整倍数

% 绘图样式（同 plot_masking_visualization.m）
label_font = 36; % 轴标签和标题字体
tick_font = 30;  % 刻度字体
line_w = 2.5;

% ========== 加载数据 ==========
if ~exist(data_file, 'file')
    error('指定的数据文件不存在: %s', data_file);
end

[~, ~, ext] = fileparts(data_file);
continuous_signal = [];
rest_samples = [];
attention_samples = [];

% 如果是文本文件，使用 importdata 读取（与 batch_feature_compare.m 一致）
if any(strcmpi(ext, {'.txt', '.dat', '.csv'}))
    d = importdata(data_file);
    if isnumeric(d)
        if size(d,2) >= 1
            continuous_signal = double(d(:,1));
        end
    elseif isstruct(d)
        % importdata 可能返回 struct，尝试常见字段
        fldc = fieldnames(d);
        if isfield(d, 'data') && isnumeric(d.data)
            continuous_signal = double(d.data(:,1));
        elseif ~isempty(fldc)
            % 取第一个数值字段
            for k = 1:length(fldc)
                v = d.(fldc{k});
                if isnumeric(v) && size(v,2) >= 1
                    continuous_signal = double(v(:,1)); break;
                end
            end
        end
    end
else
    % 默认按 mat 文件处理（保留原有逻辑）
    data = load(data_file);
    % 检查是否包含分段样本
    if isfield(data, 'rest_samples')
        rest_samples = data.rest_samples;
    end
    if isfield(data, 'attention_samples')
        attention_samples = data.attention_samples;
    end
    % 若 mat 包含连续信号字段，取第一匹配字段作为连续信号
    candidate_fields = {'eeg_data','eeg','data','signal','raw'};
    for i = 1:length(candidate_fields)
        if isfield(data, candidate_fields{i})
            continuous_signal = data.(candidate_fields{i});
            break;
        end
    end
end

% 添加 feature 路径以使用 XSampEn
addpath(fullfile(fileparts(mfilename('fullpath')),'..','..','MatlabCode','feature'));

rest_xs = [];
rest_times = [];
att_xs = [];
att_times = [];

if ~isempty(continuous_signal)
    % 连续信号模式：按 batch_feature_compare 的时间段和滑动窗口计算
    eeg = double(continuous_signal(:));
    t = (0:length(eeg)-1)/Fs;

    window_samples = round(window_length * Fs);
    step_samples = round(step_size * Fs);

    for idxPeriod = 1:2
        tr = time_periods.ranges{idxPeriod};
        % 支持 cell 或 numeric 格式的 ranges
        if iscell(tr)
            tr = [tr{1}, tr{2}];
        end
        if isinf(tr(2))
            phase_idx = find(t >= tr(1));
        else
            phase_idx = find(t >= tr(1) & t < tr(2));
        end

        if isempty(phase_idx)
            continue;
        end

        n_windows = floor((length(phase_idx) - window_samples) / step_samples) + 1;
        xs = nan(1, max(n_windows,0));
        times = nan(1, max(n_windows,0));
        win_ct = 0;

        for win = 1:n_windows
            start_idx = phase_idx(1) + (win-1)*step_samples;
            end_idx = start_idx + window_samples - 1;
            if end_idx > length(eeg)
                continue;
            end
            segment = eeg(start_idx:end_idx);
            mid_point = floor(length(segment)/2);
            if mid_point > 10
                sig1 = segment(1:mid_point);
                sig2 = segment(mid_point+1:end);
                try
                    XS = XSampEn(sig1, sig2);
                    val = XS(3);
                catch
                    val = NaN;
                end
            else
                val = NaN;
            end
            win_ct = win_ct + 1;
            xs(win_ct) = val;
            times(win_ct) = t(start_idx) + (window_length/2);
        end
        xs = xs(1:win_ct);
        times = times(1:win_ct);
        if idxPeriod == 1
            rest_xs = xs;
            rest_times = times;
        else
            att_xs = xs;
            att_times = times;
        end
    end
else
    % 如果存在 rest_samples/attention_samples 矩阵，按每行作为一个样本计算 XSampEn
    if isfield(data, 'rest_samples')
        R = data.rest_samples;
        nR = size(R,1);
        xsR = nan(1,nR);
        for i = 1:nR
            seg = double(R(i,:)); mid = floor(length(seg)/2);
            if mid > 10
                try
                    XS = XSampEn(seg(1:mid), seg(mid+1:end)); xsR(i) = XS(3);
                catch xsR(i)=NaN; end
            else xsR(i)=NaN; end
        end
        rest_xs = xsR;
        rest_times = (0:nR-1)*window_length + window_length/2; % 以样本为单位映射时间
    end
    if isfield(data, 'attention_samples')
        A = data.attention_samples;
        nA = size(A,1);
        xsA = nan(1,nA);
        for i = 1:nA
            seg = double(A(i,:)); mid = floor(length(seg)/2);
            if mid > 10
                try
                    XS = XSampEn(seg(1:mid), seg(mid+1:end)); xsA(i) = XS(3);
                catch xsA(i)=NaN; end
            else xsA(i)=NaN; end
        end
        att_xs = xsA;
        att_times = (0:nA-1)*window_length + window_length/2;
    end
end

% 检查是否有数据
if isempty(rest_xs) && isempty(att_xs)
    error('未能计算到任何 XSampEn 数据。请检查 mat 文件内容或路径。');
end

% ========== 计算阈值与自适应逻辑 ==========
rest_mean = mean(rest_xs(~isnan(rest_xs)));
if isempty(rest_mean) || isnan(rest_mean)
    error('静息阶段 XSampEn 均值不可用，无法设置初始阈值。');
end

nAtt = length(att_xs);
threshold_history = nan(1, max(nAtt,1));
current_threshold = rest_mean;
threshold_history(:) = current_threshold;

if length(att_times) >= 2
    dt = median(diff(att_times));
else
    dt = step_size; % fallback
end
% 使用连续窗口计数判断是否满足连续 threshold_duration
below_count = 0; above_count = 0;
needed_count = max(1, ceil(threshold_duration / dt));

for i = 1:nAtt
    val = att_xs(i);
    if isnan(val)
        below_count = 0; above_count = 0; threshold_history(i) = current_threshold; continue;
    end
    if val < current_threshold
        below_count = below_count + 1;
        above_count = 0;
    elseif val > current_threshold
        above_count = above_count + 1;
        below_count = 0;
    else
        below_count = 0; above_count = 0;
    end

    if below_count >= needed_count
        current_threshold = current_threshold * threshold_down_factor;
        below_count = 0;
    elseif above_count >= needed_count
        current_threshold = current_threshold * threshold_up_factor;
        above_count = 0;
    end
    threshold_history(i) = current_threshold;
end

% 扩展阈值到 rest 时间范围（画在整个图上）
if ~isempty(att_times)
    full_times = [rest_times, att_times];
else
    full_times = rest_times;
end

% ========== 绘图 ==========
figure('Position',[100,100,1200,600],'Color','none'); hold on; grid on;
plot_color = time_periods.colors{1};

% 绘制静息时序
if ~isempty(rest_xs)
    plot(rest_times, rest_xs, '-', 'Color', plot_color, 'LineWidth', line_w);
end

% 绘制注意力时序
if ~isempty(att_xs)
    plot(att_times, att_xs, '--', 'Color', plot_color, 'LineWidth', line_w);
end

% 绘制阈值
if ~isempty(att_xs)
    plot(att_times, threshold_history, ':', 'Color', plot_color, 'LineWidth', line_w);
else
    % 只有 rest 时，绘制恒定阈值
    plot([min(rest_times), max(rest_times)], [rest_mean, rest_mean], ':', 'Color', plot_color, 'LineWidth', line_w);
end

set(gca, 'FontName', 'SimSun', 'FontSize', tick_font, 'LineWidth', 1.5);
xlabel('Time (s)', 'FontName', 'SimSun', 'FontSize', label_font, 'FontWeight', 'bold');
ylabel('XSampEn', 'FontName', 'SimSun', 'FontSize', label_font, 'FontWeight', 'bold');

% Legend
leg_handles = [];
leg_labels = {};
if ~isempty(rest_xs)
    leg_handles(end+1) = plot(nan,nan,'-','Color',plot_color,'LineWidth',line_w); leg_labels{end+1}='静息 XSampEn'; end
if ~isempty(att_xs)
    leg_handles(end+1) = plot(nan,nan,'--','Color',plot_color,'LineWidth',line_w); leg_labels{end+1}='注意力 XSampEn'; end
leg_handles(end+1) = plot(nan,nan,':','Color',plot_color,'LineWidth',line_w); leg_labels{end+1}='阈值';
if ~isempty(leg_handles)
    lh = legend(leg_handles, leg_labels, 'FontName', 'SimSun', 'FontSize', tick_font, 'Location', 'best');
    set(lh,'Box','off');
end

hold off;
fprintf('完成：绘制 XSampEn 时序并显示自适应阈值。\n数据文件: %s\n', data_file);
