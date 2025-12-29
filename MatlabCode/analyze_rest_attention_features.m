%% 静息与注意力阶段特征对比分析
% 分析Python脚本生成的mat文件（包含rest_samples和attention_samples）
clc;
close all;
clear all;

% --- 全局字体大小设置 ---
font_sizes = struct();
font_sizes.title = 20;
font_sizes.axis_label = 18;
font_sizes.legend = 16;
font_sizes.subtitle = 16;

% --- 用户需要设定的参数 ---
data_file = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\微信小程序\裁剪好的MAT\预处理后\1223 HR微信小程序信号图-存活127s-舒尔特51s.mat';
Fs = 250; % 采样率 (Hz)

% 特征计算参数
theta_band = [4, 8];
beta_band = [14, 25];
window_length = 6; % 窗长 (秒)

% 检查文件是否存在
if ~exist(data_file, 'file')
    error('指定的数据文件不存在: %s', data_file);
end

% 从文件路径中提取文件名
[~, filename, ext] = fileparts(data_file);
display_filename = [filename, ext];

fprintf('--- 开始分析数据文件: %s ---\n', display_filename);

try
    %% 1. 加载数据
    data = load(data_file);
    
    % 读取静息和注意力样本（直接读取矩阵）
    rest_samples = [];
    attention_samples = [];
    
    if isfield(data, 'rest_samples')
        rest_samples = data.rest_samples;
        fprintf('静息样本数量: %d\n', size(rest_samples, 1));
        fprintf('样本长度: %d 个点 (%.1f秒)\n', size(rest_samples, 2), size(rest_samples, 2)/Fs);
    end
    
    if isfield(data, 'attention_samples')
        attention_samples = data.attention_samples;
        fprintf('注意力样本数量: %d\n', size(attention_samples, 1));
        fprintf('样本长度: %d 个点 (%.1f秒)\n', size(attention_samples, 2), size(attention_samples, 2)/Fs);
    end
    
    if isempty(rest_samples) && isempty(attention_samples)
        error('没有可用的样本数据！');
    end
    
    %% 2. 计算静息阶段特征
    fprintf('\n--- 计算静息阶段特征 ---\n');
    rest_sampen = [];
    rest_tbr = [];
    
    if ~isempty(rest_samples)
        n_rest = size(rest_samples, 1);
        rest_sampen = zeros(n_rest, 1);
        rest_tbr = zeros(n_rest, 1);
        
        for i = 1:n_rest
            segment = rest_samples(i, :);
            Samp = SampEn(segment);
            rest_sampen(i) = Samp(3);
            rest_tbr(i) = compute_power_ratio(segment, Fs, theta_band, beta_band);
        end
        fprintf('静息阶段特征计算完成\n');
    end
    
    %% 3. 计算注意力阶段特征
    fprintf('\n--- 计算注意力阶段特征 ---\n');
    attention_sampen = [];
    attention_tbr = [];
    
    if ~isempty(attention_samples)
        n_attention = size(attention_samples, 1);
        attention_sampen = zeros(n_attention, 1);
        attention_tbr = zeros(n_attention, 1);
        
        for i = 1:n_attention
            segment = attention_samples(i, :);
            Samp = SampEn(segment);
            attention_sampen(i) = Samp(3);
            attention_tbr(i) = compute_power_ratio(segment, Fs, theta_band, beta_band);
        end
        fprintf('注意力阶段特征计算完成\n');
    end
    
    %% 4. 统计分析
    fprintf('\n========== 特征统计分析 ==========\n');
    
    if ~isempty(rest_sampen)
        fprintf('\n【静息阶段】\n');
        fprintf('样本熵: 均值=%.4f, 标准差=%.4f\n', mean(rest_sampen), std(rest_sampen));
        fprintf('TBR:    均值=%.4f, 标准差=%.4f\n', mean(rest_tbr), std(rest_tbr));
    end
    
    if ~isempty(attention_sampen)
        fprintf('\n【注意力阶段】\n');
        fprintf('样本熵: 均值=%.4f, 标准差=%.4f\n', mean(attention_sampen), std(attention_sampen));
        fprintf('TBR:    均值=%.4f, 标准差=%.4f\n', mean(attention_tbr), std(attention_tbr));
    end
    
    if ~isempty(rest_sampen) && ~isempty(attention_sampen)
        fprintf('\n【差异显著性检验 (t-test)】\n');
        [~, p_sampen] = ttest2(rest_sampen, attention_sampen);
        [~, p_tbr] = ttest2(rest_tbr, attention_tbr);
        fprintf('样本熵 p-value = %.4f\n', p_sampen);
        fprintf('TBR p-value = %.4f\n', p_tbr);
    end
    
    fprintf('==================================\n\n');
    
    %% 5. 可视化对比
    
    % 5.1 样本熵箱线图
    if ~isempty(rest_sampen) && ~isempty(attention_sampen)
        figure('Position', [100, 100, 800, 600]);
        boxplot([rest_sampen; attention_sampen], ...
                [ones(size(rest_sampen)); 2*ones(size(attention_sampen))], ...
                'Labels', {'静息', '注意力'}, 'Colors', 'br');
        ylabel('样本熵值', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        title(['样本熵对比 - ' display_filename], 'FontName', 'SimSun', ...
              'FontSize', font_sizes.title, 'Interpreter', 'none');
        grid on;
        hold on;
        plot(1, mean(rest_sampen), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        plot(2, mean(attention_sampen), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        hold off;
    end
    
    % 5.2 TBR箱线图
    if ~isempty(rest_tbr) && ~isempty(attention_tbr)
        figure('Position', [200, 200, 800, 600]);
        boxplot([rest_tbr; attention_tbr], ...
                [ones(size(rest_tbr)); 2*ones(size(attention_tbr))], ...
                'Labels', {'静息', '注意力'}, 'Colors', 'br');
        ylabel('TBR值', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        title(['TBR对比 - ' display_filename], 'FontName', 'SimSun', ...
              'FontSize', font_sizes.title, 'Interpreter', 'none');
        grid on;
        hold on;
        plot(1, mean(rest_tbr), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        plot(2, mean(attention_tbr), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        hold off;
    end
    
    % 5.3 样本熵分布直方图
    if ~isempty(rest_sampen) && ~isempty(attention_sampen)
        figure('Position', [300, 300, 1000, 500]);
        
        subplot(1, 2, 1);
        histogram(rest_sampen, 20, 'FaceColor', 'b', 'FaceAlpha', 0.6);
        xlabel('样本熵值', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        title('静息阶段', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
        
        subplot(1, 2, 2);
        histogram(attention_sampen, 20, 'FaceColor', 'r', 'FaceAlpha', 0.6);
        xlabel('样本熵值', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        title('注意力阶段', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
    end
    
    % 5.4 TBR分布直方图
    if ~isempty(rest_tbr) && ~isempty(attention_tbr)
        figure('Position', [400, 400, 1000, 500]);
        
        subplot(1, 2, 1);
        histogram(rest_tbr, 20, 'FaceColor', 'b', 'FaceAlpha', 0.6);
        xlabel('TBR值', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        title('静息阶段', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
        
        subplot(1, 2, 2);
        histogram(attention_tbr, 20, 'FaceColor', 'r', 'FaceAlpha', 0.6);
        xlabel('TBR值', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        ylabel('频数', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        title('注意力阶段', 'FontName', 'SimSun', 'FontSize', font_sizes.subtitle);
        grid on;
    end
    
    % 5.5 散点图
    if ~isempty(rest_sampen) && ~isempty(attention_sampen)
        figure('Position', [500, 500, 800, 600]);
        hold on;
        scatter(rest_sampen, rest_tbr, 50, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
        scatter(attention_sampen, attention_tbr, 50, 'r', 'filled', 'MarkerFaceAlpha', 0.5);
        xlabel('样本熵', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        ylabel('TBR', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
        title(['样本熵 vs TBR - ' display_filename], 'FontName', 'SimSun', ...
              'FontSize', font_sizes.title, 'Interpreter', 'none');
        legend({'静息', '注意力'}, 'FontName', 'SimSun', 'FontSize', font_sizes.legend);
        grid on;
        hold off;
    end
    
catch ME
    fprintf('处理数据时发生错误: %s\n', ME.message);
    fprintf('错误位置: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
end

fprintf('--- 分析完毕 ---\n');
