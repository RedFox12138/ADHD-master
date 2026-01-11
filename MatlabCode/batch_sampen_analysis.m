%% 按受试者批量样本熵统计分析脚本
% 功能：批量读取不同受试者的预处理脑电数据，为每个受试者单独计算样本熵和统计检验
% 修改日期：2026年1月4日

clc;
close all;
clear all;

%% ========== 用户配置区 ==========
% 是否手动选择文件夹（true: 弹出对话框选择；false: 使用下方指定路径）
manual_select = true;

% 根目录路径（当 manual_select = false 时使用）
% 根目录下应包含多个受试者文件夹，每个文件夹名即为受试者ID
root_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat\';

% .mat 文件中的变量名（请根据实际数据修改）
rest_var_name = 'rest_samples';      % 静息段信号的变量名
task_var_name = 'attention_samples';      % 注意力段信号的变量名

% 显著性水平
alpha_level = 0.05;

% 图表字体设置
font_sizes = struct();
font_sizes.title = 16;
font_sizes.axis_label = 14;
font_sizes.legend = 12;
%% ====================================

fprintf('========== 按受试者批量样本熵分析开始 ==========\n');

%% 1. 获取所有受试者文件夹
% 选择根目录
if manual_select
    % 弹出对话框手动选择文件夹
    full_root_folder = uigetdir(pwd, '请选择包含受试者子文件夹的根目录');
    if full_root_folder == 0
        error('用户取消了文件夹选择，程序终止。');
    end
    fprintf('已选择根目录: %s\n\n', full_root_folder);
else
    % 使用配置的路径
    full_root_folder = root_folder;
    % 如果是相对路径，转换为绝对路径
    if ~isAbsolutePath(full_root_folder)
        full_root_folder = fullfile(fileparts(mfilename('fullpath')), root_folder);
    end
end

% 检查文件夹是否存在
if ~exist(full_root_folder, 'dir')
    error('根目录不存在: %s\n请检查路径配置！', full_root_folder);
end

% 获取所有子文件夹（受试者）
all_items = dir(full_root_folder);
subject_folders = all_items([all_items.isdir] & ~ismember({all_items.name}, {'.', '..'}));
num_subjects = length(subject_folders);

if num_subjects == 0
    error('在根目录 %s 中未找到任何受试者子文件夹！', full_root_folder);
end

fprintf('找到 %d 个受试者文件夹，准备处理...\n\n', num_subjects);

% 创建结果保存文件夹
results_folder = fullfile(full_root_folder, '受试者统计结果');
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
    fprintf('创建结果文件夹: %s\n\n', results_folder);
end

%% 2. 逐个受试者处理
% 存储所有受试者的汇总结果
all_subjects_summary = cell(num_subjects + 1, 9);
all_subjects_summary(1, :) = {'受试者ID', '样本数', '静息均值', '静息标准差', ...
                              '注意力均值', '注意力标准差', 'P值', 'Cohen''s d', '是否显著'};

% 循环处理每个受试者
for subj_idx = 1:num_subjects
    subject_id = subject_folders(subj_idx).name;
    subject_folder = fullfile(full_root_folder, subject_id);
    
    fprintf('\n========================================\n');
    fprintf('处理受试者 [%d/%d]: %s\n', subj_idx, num_subjects, subject_id);
    fprintf('========================================\n');
    
    % 获取该受试者文件夹下的所有 .mat 文件
    mat_files = dir(fullfile(subject_folder, '*.mat'));
    num_files = length(mat_files);
    
    if num_files == 0
        warning('受试者 %s 的文件夹中未找到 .mat 文件，跳过。', subject_id);
        continue;
    end
    
    fprintf('找到 %d 个 .mat 文件\n\n', num_files);
    
    % 初始化该受试者的数据
    Subject_Rest = [];
    Subject_Task = [];
    file_names = {};
    
    % 读取并计算该受试者的所有样本熵
    for i = 1:num_files
        current_file = fullfile(subject_folder, mat_files(i).name);
        
        fprintf('  [%d/%d] 处理: %s\n', i, num_files, mat_files(i).name);
        
        try
            % 加载 .mat 文件
            data = load(current_file);
            
            % 检查变量是否存在
            if ~isfield(data, rest_var_name) || ~isfield(data, task_var_name)
                warning('    文件缺少必要变量，跳过...');
                continue;
            end
            
            rest_signal = data.(rest_var_name);
            task_signal = data.(task_var_name);
            
            % 检查数据维度
            num_rest = size(rest_signal, 1);
            num_task = size(task_signal, 1);
            num_segments = min(num_rest, num_task);
            
            if num_rest ~= num_task
                warning('    静息段(%d)和注意力段(%d)数量不匹配，取最小值: %d', ...
                    num_rest, num_task, num_segments);
            end
            
            fprintf('    发现 %d 段配对数据\n', num_segments);
            
            % 逐段计算样本熵
            for seg = 1:num_segments
                % 计算静息段样本熵
                Samp_rest = SampEn(rest_signal(seg, :));
                rest_entropy = Samp_rest(3);
                
                % 计算注意力段样本熵
                Samp_task = SampEn(task_signal(seg, :));
                task_entropy = Samp_task(3);
                
                % 存储结果
                Subject_Rest = [Subject_Rest; rest_entropy];
                Subject_Task = [Subject_Task; task_entropy];
                file_names = [file_names; {sprintf('%s_段%d', mat_files(i).name, seg)}];
                
                fprintf('      段%d - 静息: %.6f, 注意力: %.6f\n', seg, rest_entropy, task_entropy);
            end
            
        catch ME
            warning('    处理文件时出错: %s', ME.message);
        end
    end
    
    fprintf('\n');

    %% 3. 数据清理（移除包含 NaN 或 Inf 的样本）
    valid_idx = ~isnan(Subject_Rest) & ~isnan(Subject_Task) & ...
                ~isinf(Subject_Rest) & ~isinf(Subject_Task);
    Subject_Rest_clean = Subject_Rest(valid_idx);
    Subject_Task_clean = Subject_Task(valid_idx);
    valid_file_names = file_names(valid_idx);
    num_valid = sum(valid_idx);
    
    fprintf('--- 受试者 %s 数据汇总 ---\n', subject_id);
    fprintf('总数据段数: %d\n', length(Subject_Rest));
    fprintf('有效数据段数: %d\n', num_valid);
    fprintf('静息段样本熵 - 均值: %.6f, 标准差: %.6f\n', ...
        mean(Subject_Rest_clean), std(Subject_Rest_clean));
    fprintf('注意力段样本熵 - 均值: %.6f, 标准差: %.6f\n\n', ...
        mean(Subject_Task_clean), std(Subject_Task_clean));
    
    if num_valid < 3
        warning('受试者 %s 有效样本数少于3个，跳过统计检验。', subject_id);
        continue;
    end
    %% 4. 计算差值
    Diff = Subject_Rest_clean - Subject_Task_clean;
    
    fprintf('--- 差值统计 ---\n');
    fprintf('差值均值: %.6f\n', mean(Diff));
    fprintf('差值标准差: %.6f\n', std(Diff));
    fprintf('差值标准差: %.6f\n', std(Diff));
fprintf('差值范围: [%.6f, %.6f]\n\n', min(Diff), max(Diff));

    %% 5. 正态性检验
    fprintf('--- 正态性检验 ---\n');
    
    % 根据样本量选择检验方法
    if num_valid >= 3 && num_valid <= 50
        [h_norm, p_norm] = lillietest(Diff);
        test_name = 'Lilliefors';
    else
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

    %% 6. 统计检验
    fprintf('--- 配对样本统计检验 ---\n');
    
    if is_normal
        % 正态分布 -> 配对样本 t 检验
        [h, p_value, ci, stats] = ttest(Subject_Rest_clean, Subject_Task_clean);
        test_method = '配对t检验';
        fprintf('检验方法: %s\n', test_method);
        fprintf('t 统计量: %.6f\n', stats.tstat);
        fprintf('自由度: %d\n', stats.df);
        fprintf('P 值: %.6f\n', p_value);
        fprintf('95%% 置信区间: [%.6f, %.6f]\n', ci(1), ci(2));
    else
        % 非正态分布 -> Wilcoxon 符号秩检验
        [p_value, h, stats] = signrank(Subject_Rest_clean, Subject_Task_clean);
        test_method = 'Wilcoxon符号秩检验';
        fprintf('检验方法: %s\n', test_method);
        fprintf('符号秩统计量: %.6f\n', stats.signedrank);
        fprintf('P 值: %.6f\n', p_value);
    end
    
    % 判断显著性
    if h == 1
        fprintf('结论: 静息段与注意力段样本熵存在显著差异 (p < %.2f) ***\n', alpha_level);
        sig_str = '是';
    else
        fprintf('结论: 静息段与注意力段样本熵无显著差异 (p >= %.2f)\n', alpha_level);
        sig_str = '否';
    %% 7. 计算效应量 (Cohen's d)
    mean_diff = mean(Subject_Rest_clean) - mean(Subject_Task_clean);
    pooled_std = sqrt((std(Subject_Rest_clean)^2 + std(Subject_Task_clean)^2) / 2);
    cohens_d = mean_diff / pooled_std;
    
    fprintf('\n--- 效应量 ---\n');
    fprintf('Cohen''s d: %.6f\n', cohens_d);
    
    % 效应量大小判断
    if abs(cohens_d) < 0.2
        effect_size = '极小';
    elseif abs(cohens_d) < 0.5
        effect_size = '小';
    elseif abs(cohens_d) < 0.8
        effect_size = '中等';
    else
        effect_size = '大';
    end
    
%% 8. 可视化：带连线的箱线图
fprintf('========== 生成可视化图表 ==========\n');
    %% 8. 可视化：带连线的箱线图
    fprintf('--- 生成受试者 %s 的图表 ---\n', subject_id);
    
    fig = figure('Position', [100, 100, 900, 600]);
    hold on; box on; grid on;
    
    % 准备数据
    data_matrix = [Subject_Rest_clean, Subject_Task_clean];
    
    % 绘制箱线图
    boxplot_handles = boxplot(data_matrix, 'Labels', {'静息段', '注意力段'}, ...
        'Colors', [0.3 0.6 0.9; 0.9 0.4 0.4], 'Symbol', 'o', 'Widths', 0.5);
    set(boxplot_handles, 'LineWidth', 1.5);
    
    % 绘制连线
    x_positions = [1, 2];
    for i = 1:num_valid
        plot(x_positions, [Subject_Rest_clean(i), Subject_Task_clean(i)], ...
            '-o', 'Color', [0.5, 0.5, 0.5, 0.3], 'LineWidth', 0.8, ...
            'MarkerSize', 4, 'MarkerFaceColor', [0.7, 0.7, 0.7]);
    end
    
    % 添加均值标记
    mean_rest = mean(Subject_Rest_clean);
    mean_task = mean(Subject_Task_clean);
    plot(1, mean_rest, 'rd', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'LineWidth', 2);
    plot(2, mean_task, 'rd', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'LineWidth', 2);
    
    % 图表标注
    ylabel('样本熵 (Sample Entropy)', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    xlabel('实验条件', 'FontName', 'SimSun', 'FontSize', font_sizes.axis_label);
    
    % 标题
    if h == 1
        sig_marker = '***';
    else
        sig_marker = 'n.s.';
    end
    
    title_str = sprintf('受试者 %s - 静息段 vs 注意力段样本熵\n%s | P=%.4f %s | d=%.3f | N=%d', ...
        subject_id, test_method, p_value, sig_marker, cohens_d, num_valid);
    title(title_str, 'FontName', 'SimSun', 'FontSize', font_sizes.title, 'Interpreter', 'none');
    
    legend({'', '', '个体变化', '均值'}, 'Location', 'best', ...
        'FontName', 'SimSun', 'FontSize', font_sizes.legend);
    
    %% 9. 保存结果到文件
fprintf('========== 保存结果 ==========\n');
    %% 9. 保存该受试者的结果
    fprintf('--- 保存受试者 %s 的结果 ---\n', subject_id);
    
    % 创建受试者专属结果文件夹
    subject_result_folder = fullfile(results_folder, subject_id);
    if ~exist(subject_result_folder, 'dir')
        mkdir(subject_result_folder);
    end
    
    % 保存数值结果
    results = struct();
    results.SubjectID = subject_id;
    results.Rest = Subject_Rest_clean;
    results.Task = Subject_Task_clean;
    results.Diff = Diff;
    results.FileNames = valid_file_names;
    results.Statistics.TestMethod = test_method;
    results.Statistics.PValue = p_value;
    results.Statistics.Significant = h;
    results.Statistics.CohensD = cohens_d;
    results.Statistics.EffectSize = effect_size;
    results.Statistics.NumSamples = num_valid;
    results.Statistics.MeanRest = mean_rest;
    results.Statistics.StdRest = std(Subject_Rest_clean);
    results.Statistics.MeanTask = mean_task;
    results.Statistics.StdTask = std(Subject_Task_clean);
    
    save_path = fullfile(subject_result_folder, sprintf('%s_sampen_results.mat', subject_id));
    save(save_path, 'results');
    fprintf('  统计结果已保存: %s\n', save_path);
    
    % 保存图表
    fig_path = fullfile(subject_result_folder, sprintf('%s_sampen_boxplot.png', subject_id));
    saveas(fig, fig_path);
    fprintf('  图表已保存: %s\n', fig_path);
    
    close(fig);
    
    % 添加到汇总表
    all_subjects_summary{subj_idx + 1, 1} = subject_id;
    all_subjects_summary{subj_idx + 1, 2} = num_valid;
    all_subjects_summary{subj_idx + 1, 3} = mean_rest;
    all_subjects_summary{subj_idx + 1, 4} = std(Subject_Rest_clean);
    all_subjects_summary{subj_idx + 1, 5} = mean_task;
    all_subjects_summary{subj_idx + 1, 6} = std(Subject_Task_clean);
    all_subjects_summary{subj_idx + 1, 7} = p_value;
    all_subjects_summary{subj_idx + 1, 8} = cohens_d;
    all_subjects_summary{subj_idx + 1, 9} = sig_str;
    
    fprintf('\n');
end

%% 10. 生成所有受试者的汇总报告
fprintf('========================================\n');
fprintf('生成所有受试者汇总报告\n');
fprintf('========================================\n');

% 保存汇总表到Excel
try
    summary_file = fullfile(results_folder, '所有受试者汇总.xlsx');
    T = cell2table(all_subjects_summary(2:end, :), 'VariableNames', all_subjects_summary(1, :));
    writetable(T, summary_file);
    fprintf('汇总表已保存: %s\n', summary_file);
catch
    % 如果Excel保存失败，保存为CSV
    summary_file = fullfile(results_folder, '所有受试者汇总.csv');
    T = cell2table(all_subjects_summary(2:end, :), 'VariableNames', all_subjects_summary(1, :));
    writetable(T, summary_file);
    fprintf('汇总表已保存: %s\n', summary_file);
end

% 保存汇总MAT文件
summary_mat = fullfile(results_folder, '所有受试者汇总.mat');
save(summary_mat, 'all_subjects_summary');
fprintf('汇总MAT文件已保存: %s\n', summary_mat);

fprintf('\n========== 所有受试者样本熵分析完成 ==========\n');
fprintf('处理受试者总数: %d\n', num_subjects);
fprintf('结果保存位置: %s\n', results_folder);
fprintf('===================================
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
