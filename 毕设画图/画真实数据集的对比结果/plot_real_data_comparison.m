%% 画真实数据集的对比结果脚本
% 参考 compute_real_data_frequency_metrics.m 读取数据
% 参考 plot_masking_visualization.m 画图风格
%
% 功能：选取三个索引数据，画出对比图
% 每个样本一张图，包含多个子图：
%   1. 原始数据
%   2~N. 各个方法的去噪结果（红色） vs 原始数据（蓝色）

clear; close all; clc;

%% ==================== 1. 参数设置 ====================
% 选取的三个样本索引 (可以根据需要修改)
selected_indices = [15, 32, 48]; 

% 结果目录优先级 (参考 compute_real_data_frequency_metrics.m)
primary_dir = 'D:\Pycharm_Projects\EOG Remove\复现的方法\训练完的模型和数据\真实数据集\结果';
fallback_dir = 'D:\Pycharm_Projects\EOG Remove\复现的方法\results';

% 画图参数 (参考 plot_masking_visualization.m)
FIG_WIDTH = 1200;
FIG_HEIGHT_PER_PLOT = 300; % 每个子图的高度，总高度根据方法数量动态调整
FONT_SIZE = 16;            % 字体稍小一点因为子图多，原参考是28
LINE_WIDTH = 1.5;
RAW_COLOR = 'b';           % 原始数据蓝色
CLEAN_COLOR = 'r';         % 去噪数据红色
FS = 250;                  % 假设采样率，如有变动需从文件读取

%% ==================== 2. 扫描并加载所有方法结果 ====================
fprintf('正在扫描结果文件...\n');

search_dirs = {};
if exist(primary_dir, 'dir'), search_dirs{end+1} = primary_dir; end
if exist(fallback_dir, 'dir'), search_dirs{end+1} = fallback_dir; end

if isempty(search_dirs)
    error('未找到任何结果目录。请确认路径配置。');
end

% 收集所有文件（去重：按方法名唯一）
file_map = containers.Map();
for d = 1:numel(search_dirs)
    dir_now = search_dirs{d};
    files = dir(fullfile(dir_now, '*_real_data_predictions.mat'));
    for i = 1:numel(files)
        method_name = strrep(files(i).name, '_real_data_predictions.mat', '');
        % 优先保留primary_dir中的文件
        if ~isKey(file_map, method_name) || strcmp(dir_now, primary_dir)
            file_map(method_name) = fullfile(dir_now, files(i).name);
        end
    end
end

method_names = file_map.keys;
num_methods = length(method_names);
fprintf('发现 %d 个方法: %s\n', num_methods, strjoin(method_names, ', '));

if num_methods == 0
    error('没有找到任何结果文件 (*_real_data_predictions.mat)');
end

% 加载数据到内存
method_data = containers.Map();
shared_original = [];
has_original = false;

for k = 1:num_methods
    m_name = method_names{k};
    f_path = file_map(m_name);
    fprintf('加载方法 [%s] ...\n', m_name);
    
    tmp = load(f_path);
    
    % 获取去噪数据
    cleaned = [];
    if isfield(tmp, 'cleaned_eeg'), cleaned = tmp.cleaned_eeg;
    elseif isfield(tmp, 'predictions'), cleaned = tmp.predictions;
    elseif isfield(tmp, 'clean_data'), cleaned = tmp.clean_data;
    end
    
    if isempty(cleaned)
        fprintf('  警告: 方法 %s 缺少去噪数据字段，跳过。\n', m_name);
        continue;
    end
    
    method_data(m_name) = cleaned;
    
    % 获取原始数据 (只取一份即可)
    if ~has_original
        original = [];
        if isfield(tmp, 'original'), original = tmp.original; end
        
        % 如果没有original，尝试重建 (参考 compute_metrics)
        if isempty(original) && isfield(tmp, 'extracted_eog')
            original = cleaned + tmp.extracted_eog;
        end
        
        if ~isempty(original)
            shared_original = original;
            has_original = true;
            fprintf('  已提取原始数据作为基准。\n');
            
            % 更新或者确认采样率
            if isfield(tmp, 'sampling_rate')
                FS = tmp.sampling_rate;
            elseif isfield(tmp, 'fs')
                FS = tmp.fs;
            end
        end
    end
end

if isempty(shared_original)
    error('无法在任何结果文件中找到或重建原始数据 (original 字段)');
end

[total_samples, total_len] = size(shared_original);
time_axis = (0:total_len-1) / FS;


%% ==================== 3. 循环画图 ====================
valid_methods = method_data.keys;
num_valid = length(valid_methods);
num_subplots = num_valid + 1; % 1个原始 + N个方法

% 检查索引是否越界
selected_indices = selected_indices(selected_indices <= total_samples);

for idx_i = 1:length(selected_indices)
    sample_idx = selected_indices(idx_i);
    fprintf('\n正在绘制样本 Index: %d ...\n', sample_idx);
    
    % 准备数据
    y_raw = double(shared_original(sample_idx, :));
    
    % 创建图形
    fig_h = num_subplots * FIG_HEIGHT_PER_PLOT;
    figure('Position', [100, 50, FIG_WIDTH, fig_h], 'Color', 'w', 'Name', sprintf('Sample %d Comparison', sample_idx));
    
    % --- 子图1: 原始数据 ---
    subplot(num_subplots, 1, 1);
    plot(time_axis, y_raw, 'Color', RAW_COLOR, 'LineWidth', LINE_WIDTH);
    title(sprintf('Sample %d: Original Data', sample_idx), 'FontSize', FONT_SIZE, 'FontWeight', 'bold');
    ylabel('\muV', 'FontSize', FONT_SIZE);
    set(gca, 'FontSize', FONT_SIZE, 'LineWidth', 1.2);
    grid on; xlim([time_axis(1), time_axis(end)]);
    % 图例
    legend({'Original'}, 'Location', 'best', 'FontSize', FONT_SIZE-4);
    
    % --- 子图2~N+1: 各方法对比 ---
    for m = 1:num_valid
        m_name = valid_methods{m};
        y_clean = double(method_data(m_name));
        y_clean_sample = y_clean(sample_idx, :);
        
        subplot(num_subplots, 1, m+1);
        hold on;
        % 先画原始数据 (蓝色，稍微透明一点或细一点以便对比?) 
        % 用户要求: "去噪结果也得和一份原始数据画在一起，原始数据是蓝色"
        h_raw = plot(time_axis, y_raw, 'Color', RAW_COLOR, 'LineWidth', LINE_WIDTH, 'DisplayName', 'Original');
        
        % 再画去噪结果 (红色)
        h_clean = plot(time_axis, y_clean_sample, 'Color', CLEAN_COLOR, 'LineWidth', LINE_WIDTH, 'DisplayName', ['Denoised (' m_name ')']);
        
        hold off;
        
        title(sprintf('Method: %s', m_name), 'FontSize', FONT_SIZE, 'FontWeight', 'bold');
        ylabel('\muV', 'FontSize', FONT_SIZE);
        set(gca, 'FontSize', FONT_SIZE, 'LineWidth', 1.2);
        grid on; xlim([time_axis(1), time_axis(end)]);
        
        % 图例
        legend([h_raw, h_clean], 'Location', 'best', 'FontSize', FONT_SIZE-4);
    end
    
    xlabel('Time (s)', 'FontSize', FONT_SIZE, 'FontWeight', 'bold');
end

fprintf('\n绘图完成！\n');
