%% 批量脑电样本熵统计分析脚本
% 功能：批量读取预处理后的脑电数据，计算样本熵，并进行统计检验
% 作者：自动生成
% 日期：2025年12月5日

clc;
close all;
clear all;

%% ========== 用户配置区 ==========
% 是否手动选择文件夹（true: 弹出对话框选择；false: 使用下方指定路径）
manual_select = true;

% 数据文件夹路径（当 manual_select = false 时使用）
data_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat\';  % 存放 .mat 文件的文件夹

% .mat 文件中的变量名（请根据实际数据修改）
rest_var_name = 'rest_samples';      % 静息段信号的变量名
task_var_name = 'attention_samples';      % 注意力段信号的变量名

% 显著性水平
alpha_level = 0.05;

% 图表字体设置
font_sizes = struct();
font_sizes.title = 18;
font_sizes.axis_label = 16;
font_sizes.legend = 14;
%% ====================================

fprintf('========== 批量样本熵分析开始 ==========\n');

%% 1. 获取所有 .mat 文件
% 选择数据文件夹
if manual_select
    % 弹出对话框手动选择文件夹
    full_data_folder = uigetdir(pwd, '请选择包含 .mat 文件的数据文件夹');
    if full_data_folder == 0
        error('用户取消了文件夹选择，程序终止。');
    end
    fprintf('已选择文件夹: %s\n\n', full_data_folder);
else
    % 使用配置的路径
    full_data_folder = data_folder;
    % 如果是相对路径，转换为绝对路径
    if ~isAbsolutePath(full_data_folder)
        full_data_folder = fullfile(fileparts(mfilename('fullpath')), data_folder);
    end
end

% 检查文件夹是否存在
if ~exist(full_data_folder, 'dir')
    error('数据文件夹不存在: %s\n请检查路径配置！', full_data_folder);
end

% 获取所有 .mat 文件
mat_files = dir(fullfile(full_data_folder, '*.mat'));
num_files = length(mat_files);

if num_files == 0
    error('在文件夹 %s 中未找到任何 .mat 文件！', full_data_folder);
end

fprintf('找到 %d 个 .mat 文件，准备处理...\n\n', num_files);

%% 2. 批量读取并计算样本熵
% 初始化动态数组存储结果（因为每个文件可能有多段数据）
All_Rest = [];  % 静息段样本熵（所有段）
All_Task = [];  % 注意力段样本熵（所有段）
file_names = {}; % 文件名记录（对应每一段）
segment_info = []; % 记录每段属于哪个文件

% 循环处理每个文件
for i = 1:num_files
    % 当前文件路径
    current_file = fullfile(full_data_folder, mat_files(i).name);
    
    fprintf('[%d/%d] 正在处理: %s\n', i, num_files, mat_files(i).name);
    
    try
        % 加载 .mat 文件
        data = load(current_file);
        
        % 检查变量是否存在
        if ~isfield(data, rest_var_name) || ~isfield(data, task_var_name)
            warning('文件 %s 中缺少必要变量，跳过...', mat_files(i).name);
            continue;
        end
        
        rest_signal = data.(rest_var_name);  % n×len 矩阵
        task_signal = data.(task_var_name);  % n×len 矩阵
        
        % 检查数据维度，取最小值
        num_rest = size(rest_signal, 1);
        num_task = size(task_signal, 1);
        num_segments = min(num_rest, num_task);
        
        if num_rest ~= num_task
            warning('文件 %s 中静息段(%d)和注意力段(%d)数量不匹配，取最小值: %d', ...
                mat_files(i).name, num_rest, num_task, num_segments);
        end
        
        fprintf('  发现 %d 段配对数据\n', num_segments);
        
        % 逐段计算样本熵
        for seg = 1:num_segments
            % 计算静息段样本熵
            Samp_rest = SampEn(rest_signal(seg, :));
            rest_entropy = Samp_rest(3);  % 取 SampEn 返回值的第3个元素
            
            % 计算注意力段样本熵
            Samp_task = SampEn(task_signal(seg, :));
            task_entropy = Samp_task(3);
            
            % 存储结果
            All_Rest = [All_Rest; rest_entropy];
            All_Task = [All_Task; task_entropy];
            file_names = [file_names; {sprintf('%s (段%d)', mat_files(i).name, seg)}];
            segment_info = [segment_info; i];
            
            fprintf('    段 %d - 静息: %.6f, 注意力: %.6f\n', seg, rest_entropy, task_entropy);
        end
        
    catch ME
        warning('处理文件 %s 时出错: %s', mat_files(i).name, ME.message);
        fprintf('  错误详情: %s\n', ME.getReport());
    end
    
    fprintf('\n');
end

%% 3. 数据清理（移除包含 NaN 或 Inf 的样本）
valid_idx = ~isnan(All_Rest) & ~isnan(All_Task) & ~isinf(All_Rest) & ~isinf(All_Task);
All_Rest_clean = All_Rest(valid_idx);
All_Task_clean = All_Task(valid_idx);
valid_file_names = file_names(valid_idx);
num_valid = sum(valid_idx);

fprintf('========== 数据汇总 ==========\n');
fprintf('总数据段数: %d\n', length(All_Rest));
fprintf('有效数据段数: %d\n', num_valid);
fprintf('处理文件数: %d\n', num_files);
fprintf('静息段样本熵 - 均值: %.6f, 标准差: %.6f\n', ...
    mean(All_Rest_clean), std(All_Rest_clean));
fprintf('注意力段样本熵 - 均值: %.6f, 标准差: %.6f\n\n', ...
    mean(All_Task_clean), std(All_Task_clean));

if num_valid < 3
    error('有效样本数少于3个，无法进行统计检验！');
end

%% 4. 计算差值
Diff = All_Rest_clean - All_Task_clean;

fprintf('========== 差值统计 ==========\n');
fprintf('差值均值: %.6f\n', mean(Diff));
fprintf('差值标准差: %.6f\n', std(Diff));
fprintf('差值范围: [%.6f, %.6f]\n\n', min(Diff), max(Diff));

%% 5. 正态性检验
fprintf('========== 正态性检验 ==========\n');

% 根据样本量选择检验方法
if num_valid >= 3 && num_valid <= 50
    % 样本量较小，使用 Shapiro-Wilk 检验
    % 注意：MATLAB 原生不支持 Shapiro-Wilk，这里使用 Lilliefors 检验代替
    [h_norm, p_norm] = lillietest(Diff);
    test_name = 'Lilliefors';
else
    % 样本量较大，使用 Kolmogorov-Smirnov 检验
    [h_norm, p_norm] = kstest((Diff - mean(Diff)) / std(Diff));
    test_name = 'Kolmogorov-Smirnov';
end

fprintf('正态性检验方法: %s\n', test_name);
fprintf('P 值: %.6f\n', p_norm);

if h_norm == 0
    fprintf('结论: 数据符合正态分布 (p > %.2f)\n\n', alpha_level);
    is_normal = true;
else
    fprintf('结论: 数据不符合正态分布 (p < %.2f)\n\n', alpha_level);
    is_normal = false;
end

%% 6. 统计检验
fprintf('========== 配对样本统计检验 ==========\n');

if is_normal
    % 正态分布 -> 配对样本 t 检验
    [h, p_value, ci, stats] = ttest(All_Rest_clean, All_Task_clean);
    test_method = '配对样本 t 检验 (Paired t-test)';
    fprintf('检验方法: %s\n', test_method);
    fprintf('t 统计量: %.6f\n', stats.tstat);
    fprintf('自由度: %d\n', stats.df);
    fprintf('P 值: %.6f\n', p_value);
    fprintf('95%% 置信区间: [%.6f, %.6f]\n', ci(1), ci(2));
else
    % 非正态分布 -> Wilcoxon 符号秩检验
    [p_value, h, stats] = signrank(All_Rest_clean, All_Task_clean);
    test_method = 'Wilcoxon 符号秩检验 (Wilcoxon Signed-Rank Test)';
    fprintf('检验方法: %s\n', test_method);
    fprintf('符号秩统计量: %.6f\n', stats.signedrank);
    fprintf('P 值: %.6f\n', p_value);
end

% 判断显著性
if h == 1
    fprintf('结论: 静息段与注意力段样本熵存在显著差异 (p < %.2f) ***\n', alpha_level);
else
    fprintf('结论: 静息段与注意力段样本熵无显著差异 (p >= %.2f)\n', alpha_level);
end

%% 7. 计算效应量 (Cohen's d)
% Cohen's d = (均值差) / 合并标准差
mean_diff = mean(All_Rest_clean) - mean(All_Task_clean);
pooled_std = sqrt((std(All_Rest_clean)^2 + std(All_Task_clean)^2) / 2);
cohens_d = mean_diff / pooled_std;

fprintf('\n========== 效应量 ==========\n');
fprintf('Cohen''s d: %.6f\n', cohens_d);

% 效应量大小判断
if abs(cohens_d) < 0.2
    effect_size = '极小 (negligible)';
elseif abs(cohens_d) < 0.5
    effect_size = '小 (small)';
elseif abs(cohens_d) < 0.8
    effect_size = '中等 (medium)';
else
    effect_size = '大 (large)';
end
fprintf('效应量级别: %s\n\n', effect_size);

%% 8. 可视化：带连线的箱线图
fprintf('========== 生成可视化图表 ==========\n');

figure('Position', [100, 100, 900, 600]);
hold on; box on; grid on;

% 准备数据（拼接成两列）
data_matrix = [All_Rest_clean, All_Task_clean];

% 绘制箱线图
boxplot_handles = boxplot(data_matrix, 'Labels', {'静息段', '注意力段'}, ...
    'Colors', [0.3 0.6 0.9; 0.9 0.4 0.4], 'Symbol', 'o', 'Widths', 0.5);

% 美化箱线图
set(boxplot_handles, 'LineWidth', 1.5);

% 绘制连线（每个样本从静息到注意力的变化）
x_positions = [1, 2];  % 静息段和注意力段的 x 坐标
for i = 1:num_valid
    plot(x_positions, [All_Rest_clean(i), All_Task_clean(i)], ...
        '-o', 'Color', [0.5, 0.5, 0.5, 0.3], 'LineWidth', 0.8, ...
        'MarkerSize', 4, 'MarkerFaceColor', [0.7, 0.7, 0.7]);
end

% 添加均值标记
mean_rest = mean(All_Rest_clean);
mean_task = mean(All_Task_clean);
plot(1, mean_rest, 'rd', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'LineWidth', 2);
plot(2, mean_task, 'rd', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'LineWidth', 2);

% 图表标注
ylabel('样本熵 (Sample Entropy)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
xlabel('实验条件', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);

% 标题显示统计结果
if h == 1
    sig_marker = '***';
else
    sig_marker = 'n.s.';
end

title_str = sprintf('静息段 vs 注意力段样本熵对比\n%s | P = %.4f %s | Cohen''s d = %.3f | N = %d', ...
    test_method, p_value, sig_marker, cohens_d, num_valid);
title(title_str, 'FontName', 'SimSun', 'FontSize', font_sizes.title, 'Interpreter', 'none');

% 添加图例
legend({'', '', '个体变化轨迹', '均值'}, 'Location', 'best', ...
    'FontName', 'SimSun', 'FontSize', font_sizes.legend);

hold off;

%% 9. 保存结果到文件
fprintf('========== 保存结果 ==========\n');

% 保存数值结果
results = struct();
results.All_Rest = All_Rest_clean;
results.All_Task = All_Task_clean;
results.Diff = Diff;
results.FileNames = valid_file_names;
results.SegmentInfo = segment_info(valid_idx);  % 记录每段来自哪个文件
results.Statistics.TestMethod = test_method;
results.Statistics.PValue = p_value;
results.Statistics.Significant = h;
results.Statistics.CohensD = cohens_d;
results.Statistics.EffectSize = effect_size;
results.Statistics.NumSamples = num_valid;
results.Statistics.NumFiles = num_files;

save_path = fullfile(full_data_folder, 'sampen_analysis_results.mat');
save(save_path, 'results');
fprintf('统计结果已保存至: %s\n', save_path);

% 保存图表
fig_path = fullfile(full_data_folder, 'sampen_boxplot.png');
saveas(gcf, fig_path);
fprintf('图表已保存至: %s\n', fig_path);

fprintf('\n========== 批量样本熵分析完成 ==========\n');

%% ========== 辅助函数 ==========
% 判断路径是否为绝对路径
function isAbsolute = isAbsolutePath(pathStr)
    % Windows: 以盘符开头 (如 C:\) 或 UNC 路径 (\\server\)
    % Unix/Mac: 以 / 开头
    if ispc
        isAbsolute = ~isempty(regexp(pathStr, '^[A-Za-z]:\\', 'once')) || ...
                     startsWith(pathStr, '\\');
    else
        isAbsolute = startsWith(pathStr, '/');
    end
end
