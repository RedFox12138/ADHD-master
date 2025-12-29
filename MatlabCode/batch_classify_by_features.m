%% 批量特征计算与文件分类脚本
% 对文件夹内的所有mat文件进行批量特征计算
% 根据静息阶段和注意力阶段的样本熵和TBR均值进行分类
clc;
close all;
clear all;

% --- 用户需要设定的参数 ---
input_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat'; % 输入文件夹路径
output_folder_sampen = 'D:\Pycharm_Projects\ADHD-master\data\分类结果\静息样本熵大于注意力'; % 静息样本熵 > 注意力样本熵
output_folder_tbr = 'D:\Pycharm_Projects\ADHD-master\data\分类结果\静息TBR小于注意力'; % 静息TBR < 注意力TBR
Fs = 250; % 采样率 (Hz)

% 特征计算参数
theta_band = [4, 8];
beta_band = [14, 25];

% 检查输入文件夹是否存在
if ~exist(input_folder, 'dir')
    error('输入文件夹不存在: %s', input_folder);
end

% 创建输出文件夹
if ~exist(output_folder_sampen, 'dir')
    mkdir(output_folder_sampen);
    fprintf('创建文件夹: %s\n', output_folder_sampen);
end

if ~exist(output_folder_tbr, 'dir')
    mkdir(output_folder_tbr);
    fprintf('创建文件夹: %s\n', output_folder_tbr);
end

% 获取所有mat文件
mat_files = dir(fullfile(input_folder, '*.mat'));
n_files = length(mat_files);

fprintf('========== 批量处理开始 ==========\n');
fprintf('输入文件夹: %s\n', input_folder);
fprintf('找到 %d 个mat文件\n\n', n_files);

% 统计变量
count_sampen = 0;  % 符合样本熵条件的文件数
count_tbr = 0;     % 符合TBR条件的文件数
count_processed = 0; % 成功处理的文件数
count_failed = 0;    % 处理失败的文件数

% 创建结果记录表
results = cell(n_files, 7);
results(1, :) = {'文件名', '静息样本熵均值', '注意力样本熵均值', '静息TBR均值', '注意力TBR均值', '样本熵分类', 'TBR分类'};

%% 批量处理每个文件
for file_idx = 1:n_files
    filename = mat_files(file_idx).name;
    filepath = fullfile(input_folder, filename);
    
    fprintf('--- [%d/%d] 处理文件: %s ---\n', file_idx, n_files, filename);
    
    try
        % 加载数据
        data = load(filepath);
        
        % 检查是否包含必需的字段
        if ~isfield(data, 'rest_samples') || ~isfield(data, 'attention_samples')
            fprintf('  警告: 文件缺少rest_samples或attention_samples字段，跳过\n\n');
            count_failed = count_failed + 1;
            continue;
        end
        
        rest_samples = data.rest_samples;
        attention_samples = data.attention_samples;
        
        % 检查样本是否为空
        if isempty(rest_samples) || isempty(attention_samples)
            fprintf('  警告: 静息或注意力样本为空，跳过\n\n');
            count_failed = count_failed + 1;
            continue;
        end
        
        fprintf('  静息样本数: %d, 注意力样本数: %d\n', ...
                size(rest_samples, 1), size(attention_samples, 1));
        
        % 计算静息阶段特征
        n_rest = size(rest_samples, 1);
        rest_sampen = zeros(n_rest, 1);
        rest_tbr = zeros(n_rest, 1);
        
        for i = 1:n_rest
            segment = rest_samples(i, :);
            Samp = SampEn(segment);
            rest_sampen(i) = Samp(3);
            rest_tbr(i) = compute_power_ratio(segment, Fs, theta_band, beta_band);
        end
        
        % 计算注意力阶段特征
        n_attention = size(attention_samples, 1);
        attention_sampen = zeros(n_attention, 1);
        attention_tbr = zeros(n_attention, 1);
        
        for i = 1:n_attention
            segment = attention_samples(i, :);
            Samp = SampEn(segment);
            attention_sampen(i) = Samp(3);
            attention_tbr(i) = compute_power_ratio(segment, Fs, theta_band, beta_band);
        end
        
        % 计算均值
        mean_rest_sampen = mean(rest_sampen);
        mean_attention_sampen = mean(attention_sampen);
        mean_rest_tbr = mean(rest_tbr);
        mean_attention_tbr = mean(attention_tbr);
        
        fprintf('  静息样本熵均值: %.4f, 注意力样本熵均值: %.4f\n', ...
                mean_rest_sampen, mean_attention_sampen);
        fprintf('  静息TBR均值: %.4f, 注意力TBR均值: %.4f\n', ...
                mean_rest_tbr, mean_attention_tbr);
        
        % 判断并分类
        sampen_class = '不符合';
        tbr_class = '不符合';
        
        % 样本熵分类: 静息 > 注意力
        if mean_rest_sampen > mean_attention_sampen
            dest_file = fullfile(output_folder_sampen, filename);
            copyfile(filepath, dest_file);
            count_sampen = count_sampen + 1;
            sampen_class = '符合';
            fprintf('  ✓ 样本熵条件满足，已复制到: %s\n', output_folder_sampen);
        else
            fprintf('  × 样本熵条件不满足 (静息%.4f <= 注意力%.4f)\n', ...
                    mean_rest_sampen, mean_attention_sampen);
        end
        
        % TBR分类: 静息 < 注意力
        if mean_rest_tbr < mean_attention_tbr
            dest_file = fullfile(output_folder_tbr, filename);
            copyfile(filepath, dest_file);
            count_tbr = count_tbr + 1;
            tbr_class = '符合';
            fprintf('  ✓ TBR条件满足，已复制到: %s\n', output_folder_tbr);
        else
            fprintf('  × TBR条件不满足 (静息%.4f >= 注意力%.4f)\n', ...
                    mean_rest_tbr, mean_attention_tbr);
        end
        
        % 记录结果
        results(file_idx + 1, :) = {filename, mean_rest_sampen, mean_attention_sampen, ...
                                     mean_rest_tbr, mean_attention_tbr, sampen_class, tbr_class};
        
        count_processed = count_processed + 1;
        fprintf('\n');
        
    catch ME
        fprintf('  错误: %s\n', ME.message);
        fprintf('  错误位置: %s (line %d)\n\n', ME.stack(1).name, ME.stack(1).line);
        count_failed = count_failed + 1;
    end
end

%% 输出统计结果
fprintf('========== 处理完成 ==========\n');
fprintf('总文件数: %d\n', n_files);
fprintf('成功处理: %d\n', count_processed);
fprintf('处理失败: %d\n', count_failed);
fprintf('符合样本熵条件的文件数: %d (静息样本熵 > 注意力样本熵)\n', count_sampen);
fprintf('符合TBR条件的文件数: %d (静息TBR < 注意力TBR)\n', count_tbr);
fprintf('================================\n\n');

%% 保存结果到Excel
try
    results_file = fullfile(input_folder, sprintf('分类结果_%s.xlsx', datestr(now, 'yyyymmdd_HHMMSS')));
    
    % 创建表格
    T = cell2table(results(2:end, :), 'VariableNames', results(1, :));
    
    % 写入Excel
    writetable(T, results_file);
    fprintf('结果已保存到: %s\n', results_file);
catch
    fprintf('警告: 无法保存Excel文件，尝试保存为mat文件\n');
    results_file = fullfile(input_folder, sprintf('分类结果_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
    save(results_file, 'results');
    fprintf('结果已保存到: %s\n', results_file);
end

fprintf('--- 批量处理全部完成 ---\n');
