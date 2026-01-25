%% plot_calibration_xsampen.m
% 画标定实验的静息/注意力阶段时序交叉样本熵（XSampEn）
%
% 说明:
% - 模仿 ADHD-master/MatlabCode/analyze_rest_attention_features.m 的滑动窗参数
% - 交叉样本熵计算使用 ADHD-master/MatlabCode/feature/XSampEn.m
% - 画图风格参考 ADHD-master/毕设画图/画掩蔽的图/plot_masking_visualization.m
%
% 使用前请修改下列用户参数
clear; close all; clc;

% ========== 用户参数（请修改） ==========
data_file = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\总和的mat\预处理处理后的mat\6s\贴片 1229 XY额头躲避游戏3.mat'; % <-- 指定要读取的 mat 文件
% data_file = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\总和的mat\预处理处理后的mat\6s\贴片 1231 XY额头躲避游戏2.mat'
signal_var = ''; % 可选：指定 mat 内的信号变量名（留空则自动选择第一个向量字段）

% 时间段（单位: 秒），格式: {name, [start end], color}
time_periods = struct();
time_periods.names = {'Rest','Attention'};
time_periods.ranges = {[10,70], [80, 140]}; % <-- 请按数据实际时间修改
time_periods.colors = {[0 0.4470 0.7410], [0.8500 0.3250 0.0980]};

% 采样率与滑动窗口参数（遵循 analyze_rest_attention_features.m 和 LFP_subject_analysis_psd.m）
Fs = 250;                % 采样率 (Hz)
window_length = 6;       % 窗长 (秒)
step_size = 0.5;         % 窗口步长 (秒)

% XSampEn 参数（使用默认值即可，必要时可在此修改）
xsamp_params = struct('m',2,'tau',1,'r',[],'Logx',exp(1));

% ========== 加载并选择信号 ==========
if ~exist(data_file, 'file')
    error('指定的数据文件不存在: %s', data_file);
end
data = load(data_file);

% 严格按照 analyze_rest_attention_features.m 的读取逻辑
rest_samples = [];
attention_samples = [];
if isfield(data, 'rest_samples')
    rest_samples = data.rest_samples;
    fprintf('静息样本数量: %d\n', size(rest_samples,1));
    fprintf('样本长度: %d 个点 (%.1f秒)\n', size(rest_samples,2), size(rest_samples,2)/Fs);
end
if isfield(data, 'attention_samples')
    attention_samples = data.attention_samples;
    fprintf('注意力样本数量: %d\n', size(attention_samples,1));
    fprintf('样本长度: %d 个点 (%.1f秒)\n', size(attention_samples,2), size(attention_samples,2)/Fs);
end

if isempty(rest_samples) && isempty(attention_samples)
    error('没有可用的样本数据！');
end

% 将 feature 目录加入路径以使用 XSampEn
addpath(fullfile(fileparts(mfilename('fullpath')),'..','..','MatlabCode','feature'));

% 为后续绘图准备默认颜色
if ~isfield(time_periods, 'colors') || isempty(time_periods.colors)
    time_periods.colors = {[0 0.4470 0.7410], [0.8500 0.3250 0.0980]};
end

% ========== 计算 XSampEn（优先使用 mat 中的 rest_samples / attention_samples） ==========
results = struct();

% 优先使用标注好的样本矩阵（每行一个样本）
% 如果存在 rest_samples/attention_samples，则对每个样本计算 XSampEn（按 CalculateFeature.m 的逻辑）
if ~isempty(rest_samples) || ~isempty(attention_samples)
    if ~isempty(rest_samples)
        R = rest_samples;
        if ~isempty(R) && isnumeric(R) && size(R,2) >= 10
            nR = size(R,1);
            xsamp_R = nan(1, nR);
            for i = 1:nR
                segment = double(R(i,:));
                mid_point = floor(length(segment)/2);
                if mid_point > 10
                    sig1 = segment(1:mid_point);
                    sig2 = segment(mid_point+1:end);
                    try
                        if isempty(xsamp_params.r)
                            XSamp = XSampEn(sig1, sig2, 'm', xsamp_params.m, 'tau', xsamp_params.tau);
                        else
                            XSamp = XSampEn(sig1, sig2, 'm', xsamp_params.m, 'tau', xsamp_params.tau, 'r', xsamp_params.r);
                        end
                        xsamp_R(i) = XSamp(3);
                    catch
                        xsamp_R(i) = NaN;
                    end
                else
                    xsamp_R(i) = NaN;
                end
            end
            % 时间轴按样本索引（若需要可改为实际时间点）
            times_R = (0:nR-1) + 1; % 样本索引起始 1
            results.Rest.xsamp = xsamp_R;
            results.Rest.times = times_R;
            results.Rest.color = time_periods.colors{1};
        end
    end

    if ~isempty(attention_samples)
        A = attention_samples;
        if ~isempty(A) && isnumeric(A) && size(A,2) >= 10
            nA = size(A,1);
            xsamp_A = nan(1, nA);
            for i = 1:nA
                segment = double(A(i,:));
                mid_point = floor(length(segment)/2);
                if mid_point > 10
                    sig1 = segment(1:mid_point);
                    sig2 = segment(mid_point+1:end);
                    try
                        if isempty(xsamp_params.r)
                            XSamp = XSampEn(sig1, sig2, 'm', xsamp_params.m, 'tau', xsamp_params.tau);
                        else
                            XSamp = XSampEn(sig1, sig2, 'm', xsamp_params.m, 'tau', xsamp_params.tau, 'r', xsamp_params.r);
                        end
                        xsamp_A(i) = XSamp(3);
                    catch
                        xsamp_A(i) = NaN;
                    end
                else
                    xsamp_A(i) = NaN;
                end
            end
            times_A = (0:nA-1) + 1;
            results.Attention.xsamp = xsamp_A;
            results.Attention.times = times_A;
            if length(time_periods.colors) >= 2
                results.Attention.color = time_periods.colors{2};
            else
                results.Attention.color = [0.8500 0.3250 0.0980];
            end
        end
    end
else
    % 回退到基于连续信号的滑动窗口时序计算（原实现）
    window_samples = round(window_length * Fs);
    step_samples = round(step_size * Fs);

    for p = 1:numel(time_periods.names)
        name = time_periods.names{p};
        tr = time_periods.ranges{p};
        idx_global = find(t >= tr(1) & t < tr(2));
        n_windows = floor((length(idx_global) - window_samples) / step_samples) + 1;
        xsamp_array = nan(1, max(n_windows,0));
        time_points = nan(1, max(n_windows,0));

        if n_windows > 0
            win_ct = 0;
            for win = 1:n_windows
                start_idx = idx_global(1) + (win-1)*step_samples;
                end_idx = start_idx + window_samples - 1;
                if end_idx > N
                    continue;
                end
                segment = sig(start_idx:end_idx);

                mid_point = floor(length(segment)/2);
                if mid_point > 10
                    sig1 = segment(1:mid_point);
                    sig2 = segment(mid_point+1:end);
                    try
                        if isempty(xsamp_params.r)
                            XSamp = XSampEn(sig1, sig2, 'm', xsamp_params.m, 'tau', xsamp_params.tau);
                        else
                            XSamp = XSampEn(sig1, sig2, 'm', xsamp_params.m, 'tau', xsamp_params.tau, 'r', xsamp_params.r);
                        end
                        val = XSamp(3);
                    catch
                        val = NaN;
                    end
                else
                    val = NaN;
                end

                win_ct = win_ct + 1;
                xsamp_array(win_ct) = val;
                time_points(win_ct) = t(start_idx) + (window_length/2);
            end
            xsamp_array = xsamp_array(1:win_ct);
            time_points = time_points(1:win_ct);
        end

        results.(name).xsamp = xsamp_array;
        results.(name).times = time_points;
        results.(name).color = time_periods.colors{p};
    end
end

% ========== 绘图：箱型图（参考 analyze_rest_attention_features.m） ==========
label_font = 30; % 轴标签和标题字体
tick_font = 30;  % 刻度字体

% 准备 XSampEn 数据
rest_sampen = [];
attention_sampen = [];
if isfield(results, 'Rest')
    rest_sampen = results.Rest.xsamp(:);
end
if isfield(results, 'Attention')
    attention_sampen = results.Attention.xsamp(:);
end

rest_valid = [];
att_valid = [];
if ~isempty(rest_sampen)
    rest_valid = rest_sampen(~isnan(rest_sampen));
end
if ~isempty(attention_sampen)
    att_valid = attention_sampen(~isnan(attention_sampen));
end

[~, filename, ext] = fileparts(data_file);
display_filename = [filename, ext];

if ~isempty(rest_valid) || ~isempty(att_valid)
    figure('Position', [100, 100, 800, 600]);
    if ~isempty(rest_valid) && ~isempty(att_valid)
        boxplot([rest_valid; att_valid], [ones(size(rest_valid)); 2*ones(size(att_valid))], ...
               'Labels', {'静息', '注意力'}, 'Colors', 'br');
        hold on;
        plot(1, mean(rest_valid), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        plot(2, mean(att_valid), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        hold off;
    elseif ~isempty(rest_valid)
        boxplot(rest_valid, 'Labels', {'静息阶段'}, 'Colors', 'b');
        hold on; plot(1, mean(rest_valid), 'ro', 'MarkerSize', 10, 'LineWidth', 2); hold off;
    else
        boxplot(att_valid, 'Labels', {'注意力阶段'}, 'Colors', 'r');
        hold on; plot(1, mean(att_valid), 'ro', 'MarkerSize', 10, 'LineWidth', 2); hold off;
    end
    % 设置坐标刻度与标签字体（SimSun，与 plot_masking_visualization.m 一致）
    set(gca, 'Color', 'none', 'FontSize', tick_font, 'LineWidth', 1.5, 'FontName', 'SimSun');
    ylabel('交叉样本熵', 'FontName', 'SimSun', 'FontSize', label_font, 'FontWeight', 'bold');
    title(['XSampEn 对比 - ' display_filename], 'FontName', 'SimSun', 'FontSize', label_font, 'Interpreter', 'none');
    grid on;
else
    warning('没有可用于绘制箱型图的 XSampEn 数据。');
end

fprintf('已完成 XSampEn 计算并绘制箱型图。\n数据文件: %s\n', data_file);
