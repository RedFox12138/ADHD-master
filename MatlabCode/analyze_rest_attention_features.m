%% 静息与注意力阶段特征对比分析
% 读取Python脚本生成的mat文件，对静息和注意力样本进行特征计算和对比
clc;
close all;
clear all;

% --- 全局字体大小设置 ---
font_sizes = struct();
font_sizes.title = 20;
font_sizes.axis_label = 18;
font_sizes.legend = 16;
font_sizes.subtitle = 16;
font_sizes.sub_axis_label = 14;

% --- 用户需要设定的参数 ---
data_file = 'D:\Pycharm_Projects\ADHD-master\data\rest_attention_dataset.mat';
Fs = 250; % 采样率 (Hz)

% 特征计算参数
theta_band = [4, 8];
beta_band = [14, 25];
window_length = 6; % 窗长 (秒) - 与Python脚本中的窗口长度一致

% 检查文件是否存在
if ~exist(data_file, 'file')
    error('指定的数据文件不存在: %s', data_file);
end

fprintf('--- 开始分析数据文件: %s ---\n', data_file);

try
    %% 1. 加载数据
    data = load(data_file);
    
    % 检查数据是否包含所需字段
    if ~isfield(data, 'rest_samples') && ~isfield(data, 'attention_samples')
        error('数据文件中没有找到 rest_samples 或 attention_samples 字段！');
    end
    
    % 读取静息和注意力样本
    rest_samples = [];
    attention_samples = [];
    
    if isfield(data, 'rest_samples')
        rest_samples = data.rest_samples;
        fprintf('静息样本数量: %d\n', size(rest_samples, 1));
        fprintf('样本长度: %d 个点 (%.1f秒)\n', size(rest_samples, 2), size(rest_samples, 2)/Fs);
    else
        fprintf('警告: 数据中没有静息样本\n');
    end
    
    if isfield(data, 'attention_samples')
        attention_samples = data.attention_samples;
        fprintf('注意力样本数量: %d\n', size(attention_samples, 1));
        fprintf('样本长度: %d 个点 (%.1f秒)\n', size(attention_samples, 2), size(attention_samples, 2)/Fs);
    else
        fprintf('警告: 数据中没有注意力样本\n');
    end
    
    if isempty(rest_samples) && isempty(attention_samples)
        error('没有可用的样本数据！');
    end
    
    %% 2. 计算静息阶段特征
    fprintf('\n--- 计算静息阶段特征 ---\n');
    rest_features = struct();
    
    if ~isempty(rest_samples)
        n_rest = size(rest_samples, 1);
        rest_features.sampen = zeros(n_rest, 1);
        rest_features.tbr = zeros(n_rest, 1);
        rest_features.mean_psd = zeros(n_rest, 51); % 0-50Hz
        
        for i = 1:n_rest
            if mod(i, 10) == 0
                fprintf('  处理静息样本 %d/%d\n', i, n_rest);
            end
            
            signal = rest_samples(i, :);
            
            % 计算样本熵
            Samp = SampEn(signal);
            rest_features.sampen(i) = Samp(3);
            
            % 计算TBR
            rest_features.tbr(i) = compute_power_ratio(signal, Fs, theta_band, beta_band);
            
            % 计算功率谱
            [p_spectrum, f_axis] = LFP_Win_Process(signal, Fs, 1, window_length, "none");
            freq_idx = find(f_axis >= 0 & f_axis <= 50);
            rest_features.mean_psd(i, :) = p_spectrum(freq_idx);
        end
        
        fprintf('静息阶段特征计算完成\n');
    end
    
    %% 3. 计算注意力阶段特征
    fprintf('\n--- 计算注意力阶段特征 ---\n');
    attention_features = struct();
    
    if ~isempty(attention_samples)
        n_attention = size(attention_samples, 1);
        attention_features.sampen = zeros(n_attention, 1);
        attention_features.tbr = zeros(n_attention, 1);
        attention_features.mean_psd = zeros(n_attention, 51);
        
        for i = 1:n_attention
            if mod(i, 10) == 0
                fprintf('  处理注意力样本 %d/%d\n', i, n_attention);
            end
            
            signal = attention_samples(i, :);
            
            % 计算样本熵
            Samp = SampEn(signal);
            attention_features.sampen(i) = Samp(3);
            
            % 计算TBR
            attention_features.tbr(i) = compute_power_ratio(signal, Fs, theta_band, beta_band);
            
            % 计算功率谱
            [p_spectrum, f_axis] = LFP_Win_Process(signal, Fs, 1, window_length, "none");
            freq_idx = find(f_axis >= 0 & f_axis <= 50);
            attention_features.mean_psd(i, :) = p_spectrum(freq_idx);
        end
        
        fprintf('注意力阶段特征计算完成\n');
    end
    
    %% 4. 统计分析
    fprintf('\n========== 特征统计分析 ==========\n');
    
    if ~isempty(rest_samples)
        fprintf('\n【静息阶段】\n');
        fprintf('样本熵:\n');
        fprintf('  均值 = %.4f, 标准差 = %.4f\n', mean(rest_features.sampen), std(rest_features.sampen));
        fprintf('  中位数 = %.4f, 范围 = [%.4f, %.4f]\n', ...
                median(rest_features.sampen), min(rest_features.sampen), max(rest_features.sampen));
        
        fprintf('TBR:\n');
        fprintf('  均值 = %.4f, 标准差 = %.4f\n', mean(rest_features.tbr), std(rest_features.tbr));
        fprintf('  中位数 = %.4f, 范围 = [%.4f, %.4f]\n', ...
                median(rest_features.tbr), min(rest_features.tbr), max(rest_features.tbr));
    end
    
    if ~isempty(attention_samples)
        fprintf('\n【注意力阶段】\n');
        fprintf('样本熵:\n');
        fprintf('  均值 = %.4f, 标准差 = %.4f\n', mean(attention_features.sampen), std(attention_features.sampen));
        fprintf('  中位数 = %.4f, 范围 = [%.4f, %.4f]\n', ...
                median(attention_features.sampen), min(attention_features.sampen), max(attention_features.sampen));
        
        fprintf('TBR:\n');
        fprintf('  均值 = %.4f, 标准差 = %.4f\n', mean(attention_features.tbr), std(attention_features.tbr));
        fprintf('  中位数 = %.4f, 范围 = [%.4f, %.4f]\n', ...
                median(attention_features.tbr), min(attention_features.tbr), max(attention_features.tbr));
    end
    
    % 差异检验
    if ~isempty(rest_samples) && ~isempty(attention_samples)
        fprintf('\n【差异显著性检验 (t-test)】\n');
        
        % 样本熵差异检验
        [h_sampen, p_sampen] = ttest2(rest_features.sampen, attention_features.sampen);
        fprintf('样本熵: p-value = %.4f %s\n', p_sampen, ...
                iif(h_sampen, '(显著差异 **)', '(无显著差异)'));
        
        % TBR差异检验
        [h_tbr, p_tbr] = ttest2(rest_features.tbr, attention_features.tbr);
        fprintf('TBR: p-value = %.4f %s\n', p_tbr, ...
                iif(h_tbr, '(显著差异 **)', '(无显著差异)'));
    end
    
    fprintf('==================================\n\n');
    
    %% 5. 可视化对比
    
    % 5.1 样本熵箱线图对比
    if ~isempty(rest_samples) && ~isempty(attention_samples)
        figure('Name', '样本熵对比', 'Position', [100, 100, 800, 600]);
        
        data_to_plot = [rest_features.sampen; attention_features.sampen];
        groups = [ones(size(rest_features.sampen)); 2*ones(size(attention_features.sampen))];
        
        boxplot(data_to_plot, groups, 'Labels', {'静息', '注意力'}, 'Colors', 'br');
        ylabel('样本熵值', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        title('静息 vs 注意力 - 样本熵对比', 'FontName', 'SimSun', 'FontSize', font_sizes.title);
        grid on;
        
        % 添加均值标记
        hold on;
        plot(1, mean(rest_features.sampen), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        plot(2, mean(attention_features.sampen), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        legend('均值', 'Location', 'best', 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
        hold off;
    end
    
    % 5.2 TBR箱线图对比
    if ~isempty(rest_samples) && ~isempty(attention_samples)
        figure('Name', 'TBR对比', 'Position', [200, 200, 800, 600]);
        
        data_to_plot = [rest_features.tbr; attention_features.tbr];
        groups = [ones(size(rest_features.tbr)); 2*ones(size(attention_features.tbr))];
        
        boxplot(data_to_plot, groups, 'Labels', {'静息', '注意力'}, 'Colors', 'br');
        ylabel('TBR值', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        title('静息 vs 注意力 - TBR对比', 'FontName', 'SimSun', 'FontSize', font_sizes.title);
        grid on;
        
        % 添加均值标记
        hold on;
        plot(1, mean(rest_features.tbr), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        plot(2, mean(attention_features.tbr), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        legend('均值', 'Location', 'best', 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
        hold off;
    end
    
    % 5.3 功率谱密度对比
    if ~isempty(rest_samples) && ~isempty(attention_samples)
        figure('Name', '功率谱密度对比', 'Position', [300, 300, 1000, 600]);
        
        % 计算平均功率谱
        mean_psd_rest = mean(rest_features.mean_psd, 1);
        std_psd_rest = std(rest_features.mean_psd, 0, 1);
        
        mean_psd_attention = mean(attention_features.mean_psd, 1);
        std_psd_attention = std(attention_features.mean_psd, 0, 1);
        
        f_axis = linspace(0, 50, 51);
        
        hold on;
        
        % 绘制静息阶段功率谱（带阴影表示标准差）
        h1 = plot(f_axis, mean_psd_rest, 'b-', 'LineWidth', 2, 'DisplayName', '静息');
        fill([f_axis, fliplr(f_axis)], ...
             [mean_psd_rest + std_psd_rest, fliplr(mean_psd_rest - std_psd_rest)], ...
             'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        
        % 绘制注意力阶段功率谱（带阴影表示标准差）
        h2 = plot(f_axis, mean_psd_attention, 'r-', 'LineWidth', 2, 'DisplayName', '注意力');
        fill([f_axis, fliplr(f_axis)], ...
             [mean_psd_attention + std_psd_attention, fliplr(mean_psd_attention - std_psd_attention)], ...
             'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        
        hold off;
        
        xlabel('频率 (Hz)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        ylabel('功率谱密度 (dB)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        title('静息 vs 注意力 - 平均功率谱密度对比', 'FontName', 'SimSun', 'FontSize', font_sizes.title);
        legend([h1, h2], 'Location', 'best', 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
        grid on;
        xlim([0, 50]);
    end
    
    % 5.4 样本熵分布直方图
    if ~isempty(rest_samples) && ~isempty(attention_samples)
        figure('Name', '样本熵分布', 'Position', [400, 400, 1000, 500]);
        
        subplot(1, 2, 1);
        histogram(rest_features.sampen, 20, 'FaceColor', 'b', 'FaceAlpha', 0.6);
        xlabel('样本熵值', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        title('静息阶段样本熵分布', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
        
        subplot(1, 2, 2);
        histogram(attention_features.sampen, 20, 'FaceColor', 'r', 'FaceAlpha', 0.6);
        xlabel('样本熵值', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        title('注意力阶段样本熵分布', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
    end
    
    % 5.5 TBR分布直方图
    if ~isempty(rest_samples) && ~isempty(attention_samples)
        figure('Name', 'TBR分布', 'Position', [500, 500, 1000, 500]);
        
        subplot(1, 2, 1);
        histogram(rest_features.tbr, 20, 'FaceColor', 'b', 'FaceAlpha', 0.6);
        xlabel('TBR值', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        title('静息阶段TBR分布', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
        
        subplot(1, 2, 2);
        histogram(attention_features.tbr, 20, 'FaceColor', 'r', 'FaceAlpha', 0.6);
        xlabel('TBR值', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.sub_axis_label);
        title('注意力阶段TBR分布', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
    end
    
    % 5.6 散点图：样本熵 vs TBR
    if ~isempty(rest_samples) && ~isempty(attention_samples)
        figure('Name', '样本熵-TBR散点图', 'Position', [600, 600, 800, 600]);
        
        hold on;
        scatter(rest_features.sampen, rest_features.tbr, 50, 'b', 'filled', ...
                'MarkerFaceAlpha', 0.5, 'DisplayName', '静息');
        scatter(attention_features.sampen, attention_features.tbr, 50, 'r', 'filled', ...
                'MarkerFaceAlpha', 0.5, 'DisplayName', '注意力');
        hold off;
        
        xlabel('样本熵', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        ylabel('TBR', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        title('样本熵 vs TBR 散点图', 'FontName', 'SimSun', 'FontSize', font_sizes.title);
        legend('Location', 'best', 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
        grid on;
    end
    
catch ME
    fprintf('处理数据时发生错误: %s\n', ME.message);
    fprintf('错误堆栈:\n');
    disp(ME.stack);
end

fprintf('--- 分析完毕 ---\n');

%% 辅助函数
function out = iif(condition, true_val, false_val)
    % 三元运算符实现
    if condition
        out = true_val;
    else
        out = false_val;
    end
end
