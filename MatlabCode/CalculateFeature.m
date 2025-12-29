%% 批量特征对比分析脚本 - 寻找最佳区分特征
% 目标: 测试多个特征在区分静息/注意力阶段的效果
% 评估指标: 效应量(Cohen's d)、分离度、p值、ROC-AUC等
clc;
close all;
clear all;

%% ========== 用户配置区 ==========
input_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat\比较好的数据';
Fs = 250; % 采样率 (Hz)

% 特征计算参数
theta_band = [4, 8];
beta_band = [14, 25];

% 检查文件夹
if ~exist(input_folder, 'dir')
    error('输入文件夹不存在: %s', input_folder);
end

%% 获取所有mat文件
mat_files = dir(fullfile(input_folder, '*.mat'));
n_files = length(mat_files);

fprintf('========== 批量特征对比分析开始 ==========\n');
fprintf('输入文件夹: %s\n', input_folder);
fprintf('找到 %d 个mat文件\n\n', n_files);

%% 定义要测试的特征
feature_names = {'SampEn', 'FuzzEn', 'TBR', 'Complexity_Activity', ...
                 'Complexity_Mobility', 'Complexity_Complexity'};
n_features = length(feature_names);

% 初始化存储结构
all_features = struct();
for i = 1:n_features
    all_features.(feature_names{i}).rest = [];
    all_features.(feature_names{i}).attention = [];
end

%% 批量计算特征
fprintf('--- 开始批量计算特征 ---\n');
count_processed = 0;
count_failed = 0;

for file_idx = 1:n_files
    filename = mat_files(file_idx).name;
    filepath = fullfile(input_folder, filename);
    
    fprintf('[%d/%d] 处理: %s\n', file_idx, n_files, filename);
    
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
            all_features.SampEn.rest = [all_features.SampEn.rest; Samp(3)];
            
            % FuzzEn
            Fuzz = FuzzEn(segment);
            all_features.FuzzEn.rest = [all_features.FuzzEn.rest; Fuzz(1)];
            
            % TBR
            tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
            all_features.TBR.rest = [all_features.TBR.rest; tbr_val];
            
            % Complexity (Hjorth参数)
            [activity, mobility, complexity] = calculateComplexity(segment, Fs);
            all_features.Complexity_Activity.rest = [all_features.Complexity_Activity.rest; activity];
            all_features.Complexity_Mobility.rest = [all_features.Complexity_Mobility.rest; mobility];
            all_features.Complexity_Complexity.rest = [all_features.Complexity_Complexity.rest; complexity];
        end
        
        % 计算注意力阶段特征
        n_attention = size(attention_samples, 1);
        for i = 1:n_attention
            segment = attention_samples(i, :);
            
            % SampEn
            Samp = SampEn(segment);
            all_features.SampEn.attention = [all_features.SampEn.attention; Samp(3)];
            
            % FuzzEn
            Fuzz = FuzzEn(segment);
            all_features.FuzzEn.attention = [all_features.FuzzEn.attention; Fuzz(1)];
            
            % TBR
            tbr_val = compute_power_ratio(segment, Fs, theta_band, beta_band);
            all_features.TBR.attention = [all_features.TBR.attention; tbr_val];
            
            % Complexity
            [activity, mobility, complexity] = calculateComplexity(segment, Fs);
            all_features.Complexity_Activity.attention = [all_features.Complexity_Activity.attention; activity];
            all_features.Complexity_Mobility.attention = [all_features.Complexity_Mobility.attention; mobility];
            all_features.Complexity_Complexity.attention = [all_features.Complexity_Complexity.attention; complexity];
        end
        
        count_processed = count_processed + 1;
        
    catch ME
        fprintf('  错误: %s\n', ME.message);
        count_failed = count_failed + 1;
    end
end

fprintf('\n成功处理: %d 个文件\n', count_processed);
fprintf('处理失败: %d 个文件\n\n', count_failed);

%% 计算评估指标
fprintf('========== 特征区分能力评估 ==========\n\n');

% 初始化结果表
results_table = cell(n_features + 1, 8);
results_table(1, :) = {'特征名称', 'Cohen''s d', '分离度', 'p值', ...
                       '静息均值±std', '注意力均值±std', '重叠系数', '推荐度'};

for i = 1:n_features
    feat_name = feature_names{i};
    rest_data = all_features.(feat_name).rest;
    attention_data = all_features.(feat_name).attention;
    
    % 移除NaN和Inf
    rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
    attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
    
    if isempty(rest_data) || isempty(attention_data)
        fprintf('特征 %s: 数据不足,跳过\n', feat_name);
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
    % 定义为两组均值差与两组标准差之和的比值
    separation_index = abs(mean_rest - mean_attention) / (std_rest + std_attention);
    
    % 3. 统计显著性 (t-test)
    [~, p_value] = ttest2(rest_data, attention_data);
    
    % 4. 重叠系数 (Overlap Coefficient)
    % 使用核密度估计计算两个分布的重叠面积
    overlap_coef = calculate_overlap(rest_data, attention_data);
    
    % 5. 综合推荐度评分 (0-100分)
    % 基于Cohen's d、分离度、p值和重叠系数的综合评分
    score_d = min(cohens_d / 2 * 100, 100); % Cohen's d > 2 得满分
    score_sep = min(separation_index * 50, 100); % 分离度 > 2 得满分
    score_p = (p_value < 0.001) * 40 + (p_value < 0.01) * 30 + (p_value < 0.05) * 20;
    score_overlap = (1 - overlap_coef) * 100; % 重叠越少分数越高
    
    recommend_score = (score_d * 0.3 + score_sep * 0.3 + score_p * 0.2 + score_overlap * 0.2);
    
    % 填充结果表
    results_table{i+1, 1} = feat_name;
    results_table{i+1, 2} = cohens_d;
    results_table{i+1, 3} = separation_index;
    results_table{i+1, 4} = p_value;
    results_table{i+1, 5} = sprintf('%.4f±%.4f', mean_rest, std_rest);
    results_table{i+1, 6} = sprintf('%.4f±%.4f', mean_attention, std_attention);
    results_table{i+1, 7} = overlap_coef;
    results_table{i+1, 8} = recommend_score;
    
    % 打印详细结果
    fprintf('--- %s ---\n', feat_name);
    fprintf('  静息阶段: %.4f ± %.4f (n=%d)\n', mean_rest, std_rest, length(rest_data));
    fprintf('  注意力阶段: %.4f ± %.4f (n=%d)\n', mean_attention, std_attention, length(attention_data));
    fprintf('  Cohen''s d: %.4f (%s)\n', cohens_d, interpret_cohens_d(cohens_d));
    fprintf('  分离度: %.4f\n', separation_index);
    fprintf('  p值: %.6f %s\n', p_value, get_significance_star(p_value));
    fprintf('  重叠系数: %.4f (%.1f%%)\n', overlap_coef, overlap_coef*100);
    fprintf('  综合推荐度: %.1f/100\n\n', recommend_score);
end

%% 生成排序后的结果表
% 按推荐度排序
scores = cell2mat(results_table(2:end, 8));
[sorted_scores, sort_idx] = sort(scores, 'descend');
sorted_table = [results_table(1, :); results_table(sort_idx + 1, :)];

fprintf('\n========== 特征排名 (按推荐度排序) ==========\n');
fprintf('%-25s %10s %10s %12s %10s\n', '特征名称', 'Cohen''s d', '分离度', 'p值', '推荐度');
fprintf('%s\n', repmat('-', 1, 80));
for i = 2:size(sorted_table, 1)
    fprintf('%-25s %10.4f %10.4f %12.6f %10.1f\n', ...
            sorted_table{i, 1}, sorted_table{i, 2}, sorted_table{i, 3}, ...
            sorted_table{i, 4}, sorted_table{i, 8});
end
fprintf('%s\n\n', repmat('=', 1, 80));

%% 可视化对比
% 1. 箱线图对比 (所有特征)
figure('Position', [100, 100, 1400, 800]);
for i = 1:n_features
    subplot(2, 3, i);
    feat_name = feature_names{i};
    rest_data = all_features.(feat_name).rest;
    attention_data = all_features.(feat_name).attention;
    
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
sgtitle('所有特征的箱线图对比', 'FontSize', 14, 'FontWeight', 'bold');

% 2. 分布密度图 (Top 3特征)
top_3_indices = sort_idx(1:min(3, length(sort_idx)));
figure('Position', [150, 150, 1200, 400]);
for i = 1:length(top_3_indices)
    feat_idx = top_3_indices(i);
    feat_name = feature_names{feat_idx};
    
    subplot(1, 3, i);
    rest_data = all_features.(feat_name).rest;
    attention_data = all_features.(feat_name).attention;
    
    rest_data = rest_data(~isnan(rest_data) & ~isinf(rest_data));
    attention_data = attention_data(~isnan(attention_data) & ~isinf(attention_data));
    
    if ~isempty(rest_data) && ~isempty(attention_data)
        hold on;
        [f_rest, x_rest] = ksdensity(rest_data);
        [f_att, x_att] = ksdensity(attention_data);
        
        plot(x_rest, f_rest, 'b-', 'LineWidth', 2, 'DisplayName', '静息');
        plot(x_att, f_att, 'r-', 'LineWidth', 2, 'DisplayName', '注意力');
        
        xlabel('特征值', 'FontSize', 10);
        ylabel('概率密度', 'FontSize', 10);
        title(sprintf('%s (推荐度: %.1f)', feat_name, sorted_scores(i)), ...
              'FontSize', 12, 'FontWeight', 'bold');
        legend('Location', 'best', 'FontSize', 9);
        grid on;
        hold off;
    end
end
sgtitle('Top 3 特征的概率密度分布', 'FontSize', 14, 'FontWeight', 'bold');

% 3. 雷达图 (综合评估指标)
figure('Position', [200, 200, 800, 800]);
best_feat_idx = sort_idx(1);
best_feat_name = feature_names{best_feat_idx};

% 提取最佳特征的各项指标
best_cohens_d = results_table{best_feat_idx + 1, 2};
best_separation = results_table{best_feat_idx + 1, 3};
best_p_value = results_table{best_feat_idx + 1, 4};
best_overlap = results_table{best_feat_idx + 1, 7};

% 归一化到0-1
norm_cohens_d = min(best_cohens_d / 2, 1);
norm_separation = min(best_separation / 2, 1);
norm_p_value = 1 - min(best_p_value / 0.05, 1); % p值越小越好
norm_overlap = 1 - best_overlap; % 重叠越小越好

% 雷达图数据
categories = {'效应量\n(Cohen''s d)', '分离度', '显著性\n(1-p值)', '可区分性\n(1-重叠)'};
values = [norm_cohens_d, norm_separation, norm_p_value, norm_overlap];

% 绘制雷达图
theta = linspace(0, 2*pi, length(categories) + 1);
values_plot = [values, values(1)];

polarplot(theta, values_plot, 'r-o', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
hold on;
polarplot(theta, ones(size(theta)), 'k--', 'LineWidth', 1); % 参考线
thetaticks(rad2deg(theta(1:end-1)));
thetaticklabels(categories);
rlim([0, 1]);
title(sprintf('最佳特征: %s 综合评估', best_feat_name), ...
      'FontSize', 14, 'FontWeight', 'bold');
hold off;

%% 保存结果
try
    % 保存到Excel
    results_file = fullfile(input_folder, sprintf('特征对比结果_%s.xlsx', datestr(now, 'yyyymmdd_HHMMSS')));
    T = cell2table(sorted_table(2:end, :), 'VariableNames', sorted_table(1, :));
    writetable(T, results_file);
    fprintf('结果已保存到: %s\n', results_file);
catch
    % 保存到MAT文件
    results_file = fullfile(input_folder, sprintf('特征对比结果_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
    save(results_file, 'sorted_table', 'all_features');
    fprintf('结果已保存到: %s\n', results_file);
end

fprintf('\n========== 分析完成 ==========\n');
fprintf('最佳特征: %s (推荐度: %.1f/100)\n', best_feat_name, sorted_scores(1));

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