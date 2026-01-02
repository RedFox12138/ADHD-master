%% 批量特征对比分析脚本 - 寻找最佳区分特征和最佳窗口大小
clc;
close all;
clear all;

%% ========== 用户配置区 ==========
% 方式1: 直接指定根目录（包含2s、4s、6s、8s子文件夹）
% root_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat';

% 方式2: 用户选择文件夹（推荐）
root_folder = uigetdir('D:\Pycharm_Projects\ADHD-master\data', '选择包含2s、4s、6s、8s子文件夹的根目录');
if root_folder == 0
    error('用户取消了文件夹选择');
end

Fs = 250; % 采样率 (Hz)

% 特征计算参数
theta_band = [4, 8];
beta_band = [14, 25];

% 定义窗口大小列表
window_sizes = {'2s', '4s', '6s', '8s'};
n_windows = length(window_sizes);

% 检查根文件夹和子文件夹
if ~exist(root_folder, 'dir')
    error('输入文件夹不存在: %s', root_folder);
end

fprintf('========== 多窗口批量特征对比分析 ==========\n');
fprintf('根目录: %s\n', root_folder);
fprintf('将分析以下窗口大小: %s\n', strjoin(window_sizes, ', '));

% 检查所有子文件夹是否存在
missing_folders = {};
for i = 1:n_windows
    subfolder = fullfile(root_folder, window_sizes{i});
    if ~exist(subfolder, 'dir')
        missing_folders{end+1} = window_sizes{i};
    end
end

if ~isempty(missing_folders)
    warning('以下子文件夹不存在，将被跳过: %s', strjoin(missing_folders, ', '));
    window_sizes = setdiff(window_sizes, missing_folders, 'stable');
    n_windows = length(window_sizes);
end

if n_windows == 0
    error('未找到任何有效的窗口文件夹');
end

fprintf('实际分析窗口数: %d\n\n', n_windows);

%% 定义要测试的特征
feature_names = {'SampEn', 'FuzzEn', 'TBR', 'Complexity_Activity', ...
                 'Complexity_Mobility', 'Complexity_Complexity'};
n_features = length(feature_names);

% 初始化多窗口存储结构: window_features{窗口索引}.特征名.{rest/attention}
window_features = cell(n_windows, 1);
for w = 1:n_windows
    window_features{w} = struct();
    for f = 1:n_features
        window_features{w}.(feature_names{f}).rest = [];
        window_features{w}.(feature_names{f}).attention = [];
    end
end

%% 对每个窗口大小进行特征提取
for window_idx = 1:n_windows
    window_name = window_sizes{window_idx};
    input_folder = fullfile(root_folder, window_name);
    
    fprintf('\n========================================\n');
    fprintf('处理窗口大小: %s\n', window_name);
    fprintf('========================================\n');
    
    % 获取当前窗口文件夹下的所有mat文件
    mat_files = dir(fullfile(input_folder, '*.mat'));
    n_files = length(mat_files);
    fprintf('找到 %d 个mat文件\n', n_files);
    
    if n_files == 0
        warning('窗口 %s 文件夹为空，跳过', window_name);
        continue;
    end
    
    % 批量计算特征
    fprintf('--- 开始提取特征 ---\n');
    count_processed = 0;
    count_failed = 0;
    
    for file_idx = 1:n_files
        filename = mat_files(file_idx).name;
        filepath = fullfile(input_folder, filename);
        
        fprintf('[%d/%d] %s\n', file_idx, n_files, filename);
        
        try
            % 加载数据
            data = load(filepath);
            
            if ~isfield(data, 'rest_samples') || ~isfield(data, 'attention_samples')
                fprintf('  警告: 缺少必需字段,跳过\n');
                count_failed = count_failed + 1;
                continue;
            end
            
            rest_samples = data.rest_samples;
            attention_samples = data.attention_samples;
            
            if isempty(rest_samples) || isempty(attention_samples)
                fprintf('  警告: 样本为空,跳过\n');
                count_failed = count_failed + 1;
                continue;
            end
            
            % 计算静息阶段特征
            n_rest = size(rest_samples, 1);
            for i = 1:n_rest
                segment = rest_samples(i, :);
                
                % SampEn
                Samp = SampEn(segment);
                window_features{window_idx}.SampEn.rest = [window_features{window_idx}.SampEn.rest; Samp(3)];
                
                % FuzzEn
                Fuzz = FuzzEn(segment);
                window_features{window_idx}.FuzzEn.rest = [window_features{window_idx}.FuzzEn.rest; Fuzz(1)];
                
                % TBR
                tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
                window_features{window_idx}.TBR.rest = [window_features{window_idx}.TBR.rest; tbr_val];
                
                % Complexity (Hjorth参数)
                [activity, mobility, complexity] = calculateComplexity(segment, Fs);
                window_features{window_idx}.Complexity_Activity.rest = [window_features{window_idx}.Complexity_Activity.rest; activity];
                window_features{window_idx}.Complexity_Mobility.rest = [window_features{window_idx}.Complexity_Mobility.rest; mobility];
                window_features{window_idx}.Complexity_Complexity.rest = [window_features{window_idx}.Complexity_Complexity.rest; complexity];
            end
            
            % 计算注意力阶段特征
            n_attention = size(attention_samples, 1);
            for i = 1:n_attention
                segment = attention_samples(i, :);
                
                % SampEn
                Samp = SampEn(segment);
                window_features{window_idx}.SampEn.attention = [window_features{window_idx}.SampEn.attention; Samp(3)];
                
                % FuzzEn
                Fuzz = FuzzEn(segment);
                window_features{window_idx}.FuzzEn.attention = [window_features{window_idx}.FuzzEn.attention; Fuzz(1)];
                
                % TBR
                tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
                window_features{window_idx}.TBR.attention = [window_features{window_idx}.TBR.attention; tbr_val];
                
                % Complexity
                [activity, mobility, complexity] = calculateComplexity(segment, Fs);
                window_features{window_idx}.Complexity_Activity.attention = [window_features{window_idx}.Complexity_Activity.attention; activity];
                window_features{window_idx}.Complexity_Mobility.attention = [window_features{window_idx}.Complexity_Mobility.attention; mobility];
                window_features{window_idx}.Complexity_Complexity.attention = [window_features{window_idx}.Complexity_Complexity.attention; complexity];
            end
            
            count_processed = count_processed + 1;
            
        catch ME
            fprintf('  错误: %s\n', ME.message);
            count_failed = count_failed + 1;
        end
    end
    
    fprintf('窗口 %s: 成功处理 %d 个文件, 失败 %d 个\n', window_name, count_processed, count_failed);
end

%% 计算每个窗口大小的评估指标
fprintf('\n\n========== 各窗口大小的特征区分能力评估 ==========\n');

% 初始化结果存储：window_results{窗口索引} = 结果表
window_results = cell(n_windows, 1);
window_best_features = cell(n_windows, 1);
window_scores = zeros(n_windows, 1);

for window_idx = 1:n_windows
    window_name = window_sizes{window_idx};
    fprintf('\n========== 窗口: %s ==========\n', window_name);
    
    % 初始化结果表
    results_table = cell(n_features + 1, 9);
    results_table(1, :) = {'特征名称', 'Cohen''s d', '分离度', 'p值', ...
                           '静息均值±std', '注意力均值±std', '重叠系数', '推荐度', '样本数'};
    
    for feat_idx = 1:n_features
        feat_name = feature_names{feat_idx};
        rest_data = window_features{window_idx}.(feat_name).rest;
        attention_data = window_features{window_idx}.(feat_name).attention;
        
        % 移除NaN和Inf
        rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
        attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
        
        if isempty(rest_data) || isempty(attention_data)
            fprintf('  %s: 数据不足,跳过\n', feat_name);
            continue;
        end
        
        % 1. Cohen's d (效应量)
        mean_rest = mean(rest_data);
        mean_attention = mean(attention_data);
        std_rest = std(rest_data);
        std_attention = std(attention_data);
        pooled_std = sqrt((std_rest^2 + std_attention^2) / 2);
        cohens_d = abs(mean_rest - mean_attention) / pooled_std;
        
        % 2. 分离度 (Separation Index)
        separation_index = abs(mean_rest - mean_attention) / (std_rest + std_attention);
        
        % 3. 统计显著性 (t-test)
        [~, p_value] = ttest2(rest_data, attention_data);
        
        % 4. 重叠系数
        overlap_coef = calculate_overlap(rest_data, attention_data);
        
        % 5. 综合推荐度评分 (0-100分)
        score_d = min(cohens_d / 2 * 100, 100);
        score_sep = min(separation_index * 50, 100);
        score_p = (p_value < 0.001) * 40 + (p_value < 0.01) * 30 + (p_value < 0.05) * 20;
        score_overlap = (1 - overlap_coef) * 100;
        recommend_score = (score_d * 0.3 + score_sep * 0.3 + score_p * 0.2 + score_overlap * 0.2);
        
        % 填充结果表
        results_table{feat_idx+1, 1} = feat_name;
        results_table{feat_idx+1, 2} = cohens_d;
        results_table{feat_idx+1, 3} = separation_index;
        results_table{feat_idx+1, 4} = p_value;
        results_table{feat_idx+1, 5} = sprintf('%.4f±%.4f', mean_rest, std_rest);
        results_table{feat_idx+1, 6} = sprintf('%.4f±%.4f', mean_attention, std_attention);
        results_table{feat_idx+1, 7} = overlap_coef;
        results_table{feat_idx+1, 8} = recommend_score;
        results_table{feat_idx+1, 9} = sprintf('%d/%d', length(rest_data), length(attention_data));
        
        % 打印详细结果
        fprintf('  %s: Cohen''s d=%.3f, 分离度=%.3f, p=%.6f, 推荐度=%.1f\n', ...
                feat_name, cohens_d, separation_index, p_value, recommend_score);
    end
    
    % 保存当前窗口的结果
    window_results{window_idx} = results_table;
    
    % 找到当前窗口的最佳特征
    scores = cell2mat(results_table(2:end, 8));
    scores = scores(~isnan(scores));
    if ~isempty(scores)
        [max_score, max_idx] = max(scores);
        window_best_features{window_idx} = results_table{max_idx + 1, 1};
        window_scores(window_idx) = max_score;
        fprintf('  >> 最佳特征: %s (推荐度: %.1f)\n', window_best_features{window_idx}, max_score);
    end
end

%% 窗口大小综合比较
fprintf('\n\n========== 窗口大小综合比较 ==========\n');
fprintf('%-10s %-20s %15s %15s\n', '窗口大小', '最佳特征', '最高推荐度', '平均推荐度');
fprintf('%s\n', repmat('-', 1, 70));

% 计算每个窗口的平均推荐度
window_avg_scores = zeros(n_windows, 1);
for w = 1:n_windows
    results_table = window_results{w};
    if size(results_table, 1) > 1
        all_scores = cell2mat(results_table(2:end, 8));
        all_scores = all_scores(~isnan(all_scores));
        window_avg_scores(w) = mean(all_scores);
    end
    
    fprintf('%-10s %-20s %15.2f %15.2f\n', ...
            window_sizes{w}, window_best_features{w}, window_scores(w), window_avg_scores(w));
end

% 找到最佳窗口大小（基于最高推荐度）
[best_max_score, best_window_idx] = max(window_scores);
best_window_name = window_sizes{best_window_idx};

fprintf('\n推荐窗口大小: %s (最佳特征推荐度: %.2f, 平均推荐度: %.2f)\n', ...
        best_window_name, best_max_score, window_avg_scores(best_window_idx));
fprintf('%s\n', repmat('=', 1, 70));
%% 可视化对比
fprintf('\n生成可视化图表...\n');

% === 图1: 窗口大小比较条形图 ===
figure('Position', [100, 100, 1200, 500]);

% 子图1: 各窗口的最高推荐度
subplot(1, 2, 1);
bar(window_scores);
set(gca, 'XTickLabel', window_sizes);
xlabel('窗口大小', 'FontSize', 12);
ylabel('最高推荐度', 'FontSize', 12);
title('各窗口最佳特征的推荐度', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
% 添加数值标注
for i = 1:n_windows
    text(i, window_scores(i), sprintf('%.1f', window_scores(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
end

% 子图2: 各窗口的平均推荐度
subplot(1, 2, 2);
bar(window_avg_scores);
set(gca, 'XTickLabel', window_sizes);
xlabel('窗口大小', 'FontSize', 12);
ylabel('平均推荐度', 'FontSize', 12);
title('各窗口所有特征的平均推荐度', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
% 添加数值标注
for i = 1:n_windows
    text(i, window_avg_scores(i), sprintf('%.1f', window_avg_scores(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
end

sgtitle('不同窗口大小的综合比较', 'FontSize', 15, 'FontWeight', 'bold');

% === 图2: 每个特征在不同窗口下的表现 ===
figure('Position', [150, 150, 1400, 900]);
for feat_idx = 1:n_features
    subplot(2, 3, feat_idx);
    feat_name = feature_names{feat_idx};
    
    % 收集该特征在各窗口的推荐度
    feat_scores = zeros(n_windows, 1);
    for w = 1:n_windows
        results_table = window_results{w};
        % 查找特征行
        for row = 2:size(results_table, 1)
            if strcmp(results_table{row, 1}, feat_name)
                feat_scores(w) = results_table{row, 8};
                break;
            end
        end
    end
    
    bar(feat_scores);
    set(gca, 'XTickLabel', window_sizes);
    xlabel('窗口大小', 'FontSize', 10);
    ylabel('推荐度', 'FontSize', 10);
    title(feat_name, 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    ylim([0, max(feat_scores)*1.2]);
    
    % 添加数值标注
    for i = 1:n_windows
        if feat_scores(i) > 0
            text(i, feat_scores(i), sprintf('%.1f', feat_scores(i)), ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
        end
    end
end
sgtitle('各特征在不同窗口大小下的表现', 'FontSize', 15, 'FontWeight', 'bold');

% === 图3: 最佳窗口的详细箱线图 ===
best_features = window_features{best_window_idx};
figure('Position', [200, 200, 1400, 800]);
for feat_idx = 1:n_features
    subplot(2, 3, feat_idx);
    feat_name = feature_names{feat_idx};
    
    rest_data = best_features.(feat_name).rest;
    attention_data = best_features.(feat_name).attention;
    
    rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
    attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
    
    if ~isempty(rest_data) && ~isempty(attention_data)
        data_combined = [rest_data; attention_data];
        group = [ones(length(rest_data), 1); 2*ones(length(attention_data), 1)];
        
        boxplot(data_combined, group, 'Labels', {'静息', '注意力'}, 'Colors', 'br');
        title(feat_name, 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('特征值', 'FontSize', 10);
        grid on;
        
        % 添加均值标记
        hold on;
        plot(1, mean(rest_data), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
        plot(2, mean(attention_data), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
        hold off;
    end
end
sgtitle(sprintf('最佳窗口 (%s) 的特征分布', best_window_name), 'FontSize', 15, 'FontWeight', 'bold');

% === 图4: 最佳窗口的Top 3特征密度图 ===
best_results_table = window_results{best_window_idx};
if size(best_results_table, 1) > 1
    scores = cell2mat(best_results_table(2:end, 8));
    [~, sort_idx] = sort(scores, 'descend');
    top_3_indices = sort_idx(1:min(3, length(sort_idx)));
    
    figure('Position', [250, 250, 1200, 400]);
    for i = 1:length(top_3_indices)
        feat_idx = top_3_indices(i);
        feat_name = best_results_table{feat_idx + 1, 1};
        feat_score = best_results_table{feat_idx + 1, 8};
        
        subplot(1, 3, i);
        
        rest_data = best_features.(feat_name).rest;
        attention_data = best_features.(feat_name).attention;
        
        rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
        attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
        
        if ~isempty(rest_data) && ~isempty(attention_data)
            hold on;
            [f_rest, x_rest] = ksdensity(rest_data);
            [f_att, x_att] = ksdensity(attention_data);
            
            plot(x_rest, f_rest, 'b-', 'LineWidth', 2.5, 'DisplayName', '静息');
            plot(x_att, f_att, 'r-', 'LineWidth', 2.5, 'DisplayName', '注意力');
            
            xlabel('特征值', 'FontSize', 11);
            ylabel('概率密度', 'FontSize', 11);
            title(sprintf('%s (推荐度: %.1f)', feat_name, feat_score), ...
                  'FontSize', 12, 'FontWeight', 'bold');
            legend('Location', 'best', 'FontSize', 10);
            grid on;
            hold off;
        end
    end
    sgtitle(sprintf('最佳窗口 (%s) Top 3 特征的概率密度分布', best_window_name), ...
            'FontSize', 15, 'FontWeight', 'bold');
end


%% 保存结果
fprintf('\n保存结果...\n');
try
    % 保存到Excel (多个sheet)
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    results_file = fullfile(root_folder, sprintf('多窗口特征对比结果_%s.xlsx', timestamp));
    
    % Sheet1: 窗口综合比较
    summary_table = cell(n_windows + 1, 4);
    summary_table(1, :) = {'窗口大小', '最佳特征', '最高推荐度', '平均推荐度'};
    for w = 1:n_windows
        summary_table{w+1, 1} = window_sizes{w};
        summary_table{w+1, 2} = window_best_features{w};
        summary_table{w+1, 3} = window_scores(w);
        summary_table{w+1, 4} = window_avg_scores(w);
    end
    T_summary = cell2table(summary_table(2:end, :), 'VariableNames', summary_table(1, :));
    writetable(T_summary, results_file, 'Sheet', '窗口综合比较');
    
    % Sheet2-N: 各窗口的详细结果
    for w = 1:n_windows
        sheet_name = sprintf('窗口_%s', window_sizes{w});
        results_table = window_results{w};
        if size(results_table, 1) > 1
            T = cell2table(results_table(2:end, :), 'VariableNames', results_table(1, :));
            writetable(T, results_file, 'Sheet', sheet_name);
        end
    end
    
    fprintf('结果已保存到: %s\n', results_file);
catch ME
    % 如果Excel保存失败，保存到MAT文件
    warning('Excel保存失败: %s', ME.message);
    results_file = fullfile(root_folder, sprintf('多窗口特征对比结果_%s.mat', timestamp));
    save(results_file, 'window_results', 'window_features', 'window_sizes', ...
         'window_best_features', 'window_scores', 'window_avg_scores', ...
         'best_window_name', 'best_window_idx');
    fprintf('结果已保存到MAT文件: %s\n', results_file);
end

fprintf('\n========== 分析完成 ==========\n');
fprintf('推荐配置:\n');
fprintf('  - 最佳窗口大小: %s\n', best_window_name);
fprintf('  - 最佳特征: %s\n', window_best_features{best_window_idx});
fprintf('  - 推荐度得分: %.2f/100\n', best_max_score);
fprintf('  - 窗口平均得分: %.2f/100\n', window_avg_scores(best_window_idx));
fprintf('========================================\n');

%% 辅助函数

function overlap = calculate_overlap(data1, data2)
    % 计算两个分布的重叠系数
    [f1, x1] = ksdensity(data1);
    [f2, x2] = ksdensity(data2);
    
    % 统一x轴范围
    x_min = min([x1, x2]);
    x_max = max([x1, x2]);
    x_common = linspace(x_min, x_max, 200);
    
    % 插值到相同的x轴
    f1_interp = interp1(x1, f1, x_common, 'linear', 0);
    f2_interp = interp1(x2, f2, x_common, 'linear', 0);
    
    % 计算重叠面积
    overlap = trapz(x_common, min(f1_interp, f2_interp));
end

function interpretation = interpret_cohens_d(d)
    % 解释Cohen's d的大小
    d = abs(d);
    if d < 0.2
        interpretation = '极小效应';
    elseif d < 0.5
        interpretation = '小效应';
    elseif d < 0.8
        interpretation = '中等效应';
    else
        interpretation = '大效应';
    end
end

function star = get_significance_star(p)
    % 根据p值返回显著性星号
    if p < 0.001
        star = '***';
    elseif p < 0.01
        star = '**';
    elseif p < 0.05
        star = '*';
    else
        star = 'n.s.';
    end
end