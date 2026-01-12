%% 批量特征分析脚本 - 静息vs注意力特征对比
% 功能：对目录中所有样本计算特征，统计静息阶段大于/小于注意力阶段的数量
% 比较方式：
%   - 对每个.mat文件（大样本），计算其中所有静息小样本的特征平均值
%   - 对每个.mat文件（大样本），计算其中所有注意力小样本的特征平均值
%   - 比较该文件的静息平均值 vs 注意力平均值
%   - 统计有多少个文件的静息平均值 > 注意力平均值
% 作者：自动生成
% 日期：2026年1月8日

clc;
close all;
clear all;

%% 设置图形不显示（避免在无显示环境中报错）
set(0, 'DefaultFigureVisible', 'off');

%% ========== 用户配置区 ==========
% 选择包含.mat文件的目录
input_folder = uigetdir('D:\Pycharm_Projects\ADHD-master\data', '选择包含预处理后.mat文件的文件夹');
if input_folder == 0
    error('用户取消了文件夹选择');
end

Fs = 250; % 采样率 (Hz)

% 特征计算参数
theta_band = [4, 8];
beta_band = [14, 25];

%% 添加feature目录到路径
addpath(fullfile(fileparts(mfilename('fullpath')), 'feature'));

%% 定义要测试的特征（与CalculateFeature.m保持一致）
% 线性频谱特征 + 非线性动力学特征
% feature_names = {'SampEn', 'FuzzEn', 'XSampEn', 'SampEn2D', 'MvSampEn', ...  % 样本熵系列
%                  'MSEn_CI', 'MvMSE', 'cMSEn', 'cXMSE', 'cMvMSE', ...  % 多尺度熵系列
%                  'PermEn', 'PermEn_FineGrain', 'PermEn_Modified', 'PermEn_AmpAware', ...  % 排列熵系列
%                  'PermEn_Weighted', 'PermEn_Edge', 'PermEn_Uniquant', 'XPermEn', ...  % 排列熵变体
%                  'LZC', ...  % 其他复杂度特征
%                  'HFD', 'FDD_Mean', 'FDD_Std', ...  % 分形特征
%                  'TBR', 'Pope_Index', 'Inverse_Alpha', 'Beta_Alpha_Ratio', 'Spectral_Slope', ...  % 频谱特征
%                  'WPE_IA_Product', 'WPE_IA_Weighted', 'WPE_IA_Ratio', 'WPE_IA_Composite', ...  % 组合特征
%                  'Complexity_Activity', 'Complexity_Mobility', 'Complexity_Complexity'};  % Hjorth参数

feature_names = {'SampEn','PermEn_Weighted','WPE_IA_Composite','Inverse_Alpha'};
n_features = length(feature_names);

fprintf('========== 特征分析脚本 ==========\n');
fprintf('输入目录: %s\n', input_folder);
fprintf('特征数量: %d\n', n_features);
fprintf('特征列表: %s\n\n', strjoin(feature_names, ', '));

%% 获取所有mat文件
mat_files = dir(fullfile(input_folder, '*.mat'));
n_files = length(mat_files);

if n_files == 0
    error('未找到.mat文件！');
end

fprintf('找到 %d 个mat文件\n\n', n_files);

%% 初始化特征存储结构
% 为每个特征创建一个结构体，存储所有文件的静息和注意力特征平均值
% 每个文件对应一个平均值（文件内所有小样本的平均）
feature_data = struct();
for f = 1:n_features
    feature_data.(feature_names{f}).rest = [];      % 所有文件的静息阶段特征平均值
    feature_data.(feature_names{f}).attention = []; % 所有文件的注意力阶段特征平均值
end

%% ========== 第一步：遍历所有文件，计算特征 ==========
fprintf('========== 步骤1：批量计算特征 ==========\n');
count_processed = 0;
count_failed = 0;

for file_idx = 1:n_files
    filename = mat_files(file_idx).name;
    filepath = fullfile(input_folder, filename);
    
    fprintf('[%d/%d] 处理文件: %s\n', file_idx, n_files, filename);
    
    try
        % 加载数据
        data = load(filepath);
        
        % 检查必需字段
        if ~isfield(data, 'rest_samples') || ~isfield(data, 'attention_samples')
            fprintf('  ⚠ 警告: 缺少必需字段，跳过\n');
            count_failed = count_failed + 1;
            continue;
        end
        
        rest_samples = data.rest_samples;
        attention_samples = data.attention_samples;
        
        if isempty(rest_samples) || isempty(attention_samples)
            fprintf('  ⚠ 警告: 样本为空，跳过\n');
            count_failed = count_failed + 1;
            continue;
        end
        
        % 计算静息阶段特征
        rest_features = calculate_all_features(rest_samples, Fs, theta_band, beta_band);
        
        % 计算注意力阶段特征
        attention_features = calculate_all_features(attention_samples, Fs, theta_band, beta_band);
        
        % 存储特征值（每个文件的平均值）
        for f = 1:n_features
            fname = feature_names{f};
            if isfield(rest_features, fname) && ~isnan(rest_features.(fname))
                feature_data.(fname).rest = [feature_data.(fname).rest; rest_features.(fname)];
            end
            if isfield(attention_features, fname) && ~isnan(attention_features.(fname))
                feature_data.(fname).attention = [feature_data.(fname).attention; attention_features.(fname)];
            end
        end
        
        count_processed = count_processed + 1;
        fprintf('  ✓ 成功处理\n');
        
    catch ME
        fprintf('  ✗ 错误: %s\n', ME.message);
        count_failed = count_failed + 1;
    end
end

fprintf('\n处理完成！成功: %d, 失败: %d\n\n', count_processed, count_failed);

%% ========== 第二步：统计每个特征的判断条件数量（文件级别） ==========
fprintf('========== 步骤2：统计特征判断条件（文件级别） ==========\n');
fprintf('比较方式：每个文件的静息平均值 vs 注意力平均值\n\n');

% 初始化统计结果
stats = struct();
for f = 1:n_features
    fname = feature_names{f};
    stats.(fname).rest_greater = 0;     % 静息 > 注意力的数量
    stats.(fname).rest_less = 0;        % 静息 < 注意力的数量
    stats.(fname).equal = 0;            % 相等的数量
    stats.(fname).total = 0;            % 总数量
    stats.(fname).rest_greater_ratio = 0;  % 静息 > 注意力的比例
    stats.(fname).rest_less_ratio = 0;     % 静息 < 注意力的比例
end

% 对每个特征进行统计（基于文件级别的平均值）
for f = 1:n_features
    fname = feature_names{f};
    rest_vals = feature_data.(fname).rest;
    attention_vals = feature_data.(fname).attention;
    
    % 确保文件数量一致（每个文件都应该有静息和注意力的平均值）
    n_files_rest = length(rest_vals);
    n_files_attention = length(attention_vals);
    
    if n_files_rest == 0 || n_files_attention == 0
        fprintf('特征 %s: 无有效文件\n', fname);
        continue;
    end
    
    % 如果数量不一致，只比较公共部分
    n_files = min(n_files_rest, n_files_attention);
    rest_vals = rest_vals(1:n_files);
    attention_vals = attention_vals(1:n_files);
    
    % 统计（比较每个文件的静息平均值 vs 注意力平均值）
    rest_greater = sum(rest_vals > attention_vals);
    rest_less = sum(rest_vals < attention_vals);
    equal = sum(rest_vals == attention_vals);
    
    stats.(fname).rest_greater = rest_greater;
    stats.(fname).rest_less = rest_less;
    stats.(fname).equal = equal;
    stats.(fname).total = n_files;
    stats.(fname).rest_greater_ratio = rest_greater / n_files;
    stats.(fname).rest_less_ratio = rest_less / n_files;
    
    fprintf('特征 %20s: 静息>注意力: %4d (%.1f%%), 静息<注意力: %4d (%.1f%%), 相等: %4d, 总文件数: %4d\n', ...
        fname, rest_greater, rest_greater/n_files*100, ...
        rest_less, rest_less/n_files*100, equal, n_files);
end

%% ========== 第三步：找出数量最多的特征和判断条件 ==========
fprintf('\n========== 步骤3：找出最优特征 ==========\n');

max_count = 0;
best_feature = '';
best_condition = '';  % 'rest_greater' 或 'rest_less'

for f = 1:n_features
    fname = feature_names{f};
    
    if stats.(fname).rest_greater > max_count
        max_count = stats.(fname).rest_greater;
        best_feature = fname;
        best_condition = 'rest_greater';
    end
    
    if stats.(fname).rest_less > max_count
        max_count = stats.(fname).rest_less;
        best_feature = fname;
        best_condition = 'rest_less';
    end
end

if strcmp(best_condition, 'rest_greater')
    condition_text = '静息阶段 > 注意力阶段';
else
    condition_text = '静息阶段 < 注意力阶段';
end

fprintf('\n【最优特征】\n');
fprintf('特征名称: %s\n', best_feature);
fprintf('判断条件: %s\n', condition_text);
fprintf('满足条件的文件数: %d / %d (%.1f%%)\n', ...
    max_count, stats.(best_feature).total, ...
    max_count / stats.(best_feature).total * 100);

%% ========== 第四步：计算最优特征的统计特性 ==========
fprintf('\n========== 步骤4：计算统计特性 ==========\n');

rest_vals = feature_data.(best_feature).rest;
attention_vals = feature_data.(best_feature).attention;

% 确保数量一致（现在每个元素代表一个文件的平均值）
n_files = min(length(rest_vals), length(attention_vals));
rest_vals = rest_vals(1:n_files);
attention_vals = attention_vals(1:n_files);

fprintf('\n【静息阶段统计】\n');
fprintf('均值: %.4f\n', mean(rest_vals));
fprintf('标准差: %.4f\n', std(rest_vals));
fprintf('中位数: %.4f\n', median(rest_vals));
fprintf('最小值: %.4f\n', min(rest_vals));
fprintf('最大值: %.4f\n', max(rest_vals));

fprintf('\n【注意力阶段统计】\n');
fprintf('均值: %.4f\n', mean(attention_vals));
fprintf('标准差: %.4f\n', std(attention_vals));
fprintf('中位数: %.4f\n', median(attention_vals));
fprintf('最小值: %.4f\n', min(attention_vals));
fprintf('最大值: %.4f\n', max(attention_vals));

fprintf('\n【差值统计（静息 - 注意力）】\n');
diff_vals = rest_vals - attention_vals;
fprintf('均值差异: %.4f\n', mean(diff_vals));
fprintf('标准差: %.4f\n', std(diff_vals));
fprintf('中位数差异: %.4f\n', median(diff_vals));

% 配对t检验（需要至少2个样本）
if length(rest_vals) >= 2
    [h, p, ci, tstat] = ttest(rest_vals, attention_vals);
    fprintf('\n【配对t检验】\n');
    fprintf('p值: %.6f\n', p);
    fprintf('t统计量: %.4f\n', tstat.tstat);
    fprintf('自由度: %d\n', tstat.df);
    fprintf('显著性 (p<0.05): %s\n', iif(~isnan(h) && h, '是', '否'));
    fprintf('95%%置信区间: [%.4f, %.4f]\n', ci(1), ci(2));
    
    % 效应量（Cohen's d）
    pooled_std = sqrt((std(rest_vals)^2 + std(attention_vals)^2) / 2);
    if pooled_std > 0
        cohens_d = (mean(rest_vals) - mean(attention_vals)) / pooled_std;
        fprintf('\n【效应量】\n');
        fprintf('Cohen''s d: %.4f\n', cohens_d);
    else
        cohens_d = NaN;
        fprintf('\n【效应量】\n');
        fprintf('Cohen''s d: 无法计算（标准差为0）\n');
    end
else
    fprintf('\n【配对t检验】\n');
    fprintf('警告：样本数量不足（需要至少2个文件），无法进行t检验\n');
    fprintf('当前文件数: %d\n', length(rest_vals));
    h = NaN;
    p = NaN;
    ci = [NaN, NaN];
    tstat.tstat = NaN;
    tstat.df = NaN;
    cohens_d = NaN;
end

%% ========== 第五步：生成可视化 ==========
fprintf('\n========== 步骤5：生成可视化图表 ==========\n');

% 创建输出文件夹
output_folder = fullfile(input_folder, '..', '分类结果');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');

% 1. 生成所有特征的条形图
fig1 = figure('Position', [100, 100, 1400, 800]);
rest_greater_counts = zeros(n_features, 1);
rest_less_counts = zeros(n_features, 1);

for f = 1:n_features
    fname = feature_names{f};
    rest_greater_counts(f) = stats.(fname).rest_greater;
    rest_less_counts(f) = stats.(fname).rest_less;
end

% 创建分组条形图
bar_data = [rest_greater_counts, rest_less_counts];
bar(bar_data, 'grouped');
set(gca, 'XTickLabel', feature_names, 'XTickLabelRotation', 45);
legend({'静息 > 注意力', '静息 < 注意力'}, 'Location', 'best');
xlabel('特征名称');
ylabel('样本数量');
title('各特征的静息vs注意力对比统计');
grid on;

% 保存图表
saveas(fig1, fullfile(output_folder, sprintf('all_features_comparison_%s.png', timestamp)));
fprintf('已保存图表: all_features_comparison_%s.png\n', timestamp);

% 2. 生成最优特征的箱线图
fig2 = figure('Position', [100, 100, 800, 600]);
boxplot([rest_vals; attention_vals], [ones(length(rest_vals), 1); 2*ones(length(attention_vals), 1)], ...
    'Labels', {'静息', '注意力'});
ylabel(sprintf('%s 特征值', best_feature));
title(sprintf('最优特征 %s 的箱线图对比', best_feature));
grid on;

% 保存图表
saveas(fig2, fullfile(output_folder, sprintf('best_feature_boxplot_%s.png', timestamp)));
fprintf('已保存图表: best_feature_boxplot_%s.png\n', timestamp);

% 3. 生成最优特征的直方图
fig3 = figure('Position', [100, 100, 1200, 500]);

subplot(1, 2, 1);
histogram(rest_vals, 20, 'FaceColor', 'b', 'FaceAlpha', 0.5);
hold on;
histogram(attention_vals, 20, 'FaceColor', 'r', 'FaceAlpha', 0.5);
legend({'静息', '注意力'});
xlabel(sprintf('%s 特征值', best_feature));
ylabel('频数');
title('特征值分布直方图');
grid on;

subplot(1, 2, 2);
plot(1:length(rest_vals), rest_vals, 'b-o', 'MarkerSize', 4);
hold on;
plot(1:length(attention_vals), attention_vals, 'r-s', 'MarkerSize', 4);
legend({'静息', '注意力'});
xlabel('样本索引');
ylabel(sprintf('%s 特征值', best_feature));
title('特征值序列图');
grid on;

% 保存图表
saveas(fig3, fullfile(output_folder, sprintf('best_feature_distribution_%s.png', timestamp)));
fprintf('已保存图表: best_feature_distribution_%s.png\n', timestamp);

% 4. 生成特征比例饼图
fig4 = figure('Position', [100, 100, 1200, 500]);

subplot(1, 2, 1);
pie([stats.(best_feature).rest_greater, stats.(best_feature).rest_less, stats.(best_feature).equal], ...
    {sprintf('静息>注意力 (%.1f%%)', stats.(best_feature).rest_greater_ratio*100), ...
     sprintf('静息<注意力 (%.1f%%)', stats.(best_feature).rest_less_ratio*100), ...
     sprintf('相等 (%.1f%%)', stats.(best_feature).equal/stats.(best_feature).total*100)});
title(sprintf('最优特征 %s 的判断条件分布', best_feature));

% 前5个最优特征
subplot(1, 2, 2);
[sorted_greater, idx_greater] = sort(rest_greater_counts, 'descend');
top5_names = feature_names(idx_greater(1:min(5, n_features)));
top5_counts = sorted_greater(1:min(5, n_features));
barh(top5_counts);
set(gca, 'YTickLabel', top5_names);
xlabel('样本数量');
title('静息>注意力 TOP5特征');
grid on;

% 保存图表
saveas(fig4, fullfile(output_folder, sprintf('feature_pie_charts_%s.png', timestamp)));
fprintf('已保存图表: feature_pie_charts_%s.png\n', timestamp);

%% ========== 第六步：生成详细报告 ==========
fprintf('\n========== 步骤6：生成分析报告 ==========\n');

% 生成文本报告
report_file = fullfile(output_folder, sprintf('feature_analysis_report_%s.txt', timestamp));
fid = fopen(report_file, 'w');

fprintf(fid, '========================================\n');
fprintf(fid, '   特征分析报告\n');
fprintf(fid, '========================================\n');
fprintf(fid, '生成时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '输入目录: %s\n', input_folder);
fprintf(fid, '处理文件数: %d (成功: %d, 失败: %d)\n\n', n_files, count_processed, count_failed);

fprintf(fid, '========================================\n');
fprintf(fid, '   特征列表\n');
fprintf(fid, '========================================\n');
fprintf(fid, '总特征数: %d\n\n', n_features);
for f = 1:n_features
    fprintf(fid, '%2d. %s\n', f, feature_names{f});
end

fprintf(fid, '\n========================================\n');
fprintf(fid, '   各特征统计结果\n');
fprintf(fid, '========================================\n');
fprintf(fid, '%-25s %12s %12s %8s %8s\n', '特征名称', '静息>注意力', '静息<注意力', '相等', '总数');
fprintf(fid, '%s\n', repmat('-', 1, 70));

for f = 1:n_features
    fname = feature_names{f};
    fprintf(fid, '%-25s %8d(%5.1f%%) %8d(%5.1f%%) %8d %8d\n', ...
        fname, ...
        stats.(fname).rest_greater, stats.(fname).rest_greater_ratio*100, ...
        stats.(fname).rest_less, stats.(fname).rest_less_ratio*100, ...
        stats.(fname).equal, ...
        stats.(fname).total);
end

fprintf(fid, '\n========================================\n');
fprintf(fid, '   最优特征\n');
fprintf(fid, '========================================\n');
fprintf(fid, '特征名称: %s\n', best_feature);
fprintf(fid, '判断条件: %s\n', condition_text);
fprintf(fid, '满足条件数量: %d / %d (%.1f%%)\n\n', ...
    max_count, stats.(best_feature).total, ...
    max_count / stats.(best_feature).total * 100);

fprintf(fid, '========================================\n');
fprintf(fid, '   统计特性\n');
fprintf(fid, '========================================\n');

fprintf(fid, '\n【静息阶段】\n');
fprintf(fid, '  均值: %.6f\n', mean(rest_vals));
fprintf(fid, '  标准差: %.6f\n', std(rest_vals));
fprintf(fid, '  中位数: %.6f\n', median(rest_vals));
fprintf(fid, '  最小值: %.6f\n', min(rest_vals));
fprintf(fid, '  最大值: %.6f\n', max(rest_vals));

fprintf(fid, '\n【注意力阶段】\n');
fprintf(fid, '  均值: %.6f\n', mean(attention_vals));
fprintf(fid, '  标准差: %.6f\n', std(attention_vals));
fprintf(fid, '  中位数: %.6f\n', median(attention_vals));
fprintf(fid, '  最小值: %.6f\n', min(attention_vals));
fprintf(fid, '  最大值: %.6f\n', max(attention_vals));

fprintf(fid, '\n【差值统计（静息 - 注意力）】\n');
fprintf(fid, '  均值差异: %.6f\n', mean(diff_vals));
fprintf(fid, '  标准差: %.6f\n', std(diff_vals));
fprintf(fid, '  中位数差异: %.6f\n', median(diff_vals));

if length(rest_vals) >= 2
    fprintf(fid, '\n【配对t检验】\n');
    fprintf(fid, '  p值: %.6f\n', p);
    fprintf(fid, '  t统计量: %.4f\n', tstat.tstat);
    fprintf(fid, '  自由度: %d\n', tstat.df);
    fprintf(fid, '  显著性 (p<0.05): %s\n', iif(~isnan(h) && h, '是', '否'));
    fprintf(fid, '  95%%置信区间: [%.6f, %.6f]\n', ci(1), ci(2));
    
    fprintf(fid, '\n【效应量】\n');
    if ~isnan(cohens_d)
        fprintf(fid, '  Cohen''s d: %.4f\n', cohens_d);
        if abs(cohens_d) < 0.2
            effect_size = '小';
        elseif abs(cohens_d) < 0.5
            effect_size = '中等';
        elseif abs(cohens_d) < 0.8
            effect_size = '较大';
        else
            effect_size = '非常大';
        end
        fprintf(fid, '  效应量级别: %s\n', effect_size);
    else
        fprintf(fid, '  Cohen''s d: 无法计算\n');
        effect_size = '未知';
    end
else
    fprintf(fid, '\n【配对t检验】\n');
    fprintf(fid, '  警告：样本数量不足（需要至少2个文件），无法进行t检验\n');
    fprintf(fid, '  当前文件数: %d\n', length(rest_vals));
    effect_size = '未知';
end

fprintf(fid, '\n========================================\n');
fprintf(fid, '   结论\n');
fprintf(fid, '========================================\n');
fprintf(fid, '在所有%d个特征中，特征 "%s" 表现最好。\n', n_features, best_feature);
fprintf(fid, '使用判断条件 "%s" 时，有 %d/%d (%.1f%%) 的文件满足条件。\n', ...
    condition_text, max_count, stats.(best_feature).total, ...
    max_count / stats.(best_feature).total * 100);

if length(rest_vals) >= 2 && ~isnan(h)
    if h
        fprintf(fid, '\n配对t检验结果显示，静息阶段与注意力阶段的差异具有统计学显著性 (p=%.6f < 0.05)。\n', p);
    else
        fprintf(fid, '\n配对t检验结果显示，静息阶段与注意力阶段的差异不具有统计学显著性 (p=%.6f >= 0.05)。\n', p);
    end
    
    if ~isnan(cohens_d)
        fprintf(fid, '效应量 Cohen''s d = %.4f，属于%s效应。\n', cohens_d, effect_size);
    end
else
    fprintf(fid, '\n由于样本数量不足，无法进行统计检验。\n');
end

fprintf(fid, '\n========================================\n');
fprintf(fid, '   报告结束\n');
fprintf(fid, '========================================\n');

fclose(fid);
fprintf('已保存报告: %s\n', report_file);

%% ========== 保存数据 ==========
output_file = fullfile(output_folder, sprintf('feature_analysis_data_%s.mat', timestamp));

save(output_file, 'feature_data', 'stats', 'best_feature', 'best_condition', ...
    'rest_vals', 'attention_vals', 'h', 'p', 'tstat', 'cohens_d', ...
    'feature_names', 'input_folder', 'count_processed', 'count_failed');

fprintf('已保存数据: %s\n', output_file);

fprintf('\n========================================\n');
fprintf('分析完成！所有结果已保存到: %s\n', output_folder);
fprintf('========================================\n');

%% 辅助函数

% 内联if函数
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
