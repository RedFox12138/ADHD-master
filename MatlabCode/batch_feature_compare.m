% --- 样本熵特征提取与对比：批量处理文件 (V2.0 多线程版) ---
% 该脚本用于批量处理指定文件夹中的所有txt文件，
% 提取静息和注意力阶段的样本熵特征。注意力阶段的
% 结束时间将根据信号实际长度动态调整。

clc;
clear all;
close all;
theta_band = [4, 8];  
beta_band = [14, 25]; 
% --- 用户设定参数 ---
Fs = 250; % 采样率 (Hz)
window_length =8; % 窗长 (秒)
step_size = 0.5; % 滑动步长 (秒)

% 定义两个核心时间段（静息和注意力）
time_periods.names = {'静息', '注意力'};
time_periods.ranges = {[10, 70], [80, 140]}; % 注意力阶段的135s是最大值
time_periods.var_names = {'Resting', 'Attention'};
time_periods.colors = {[0, 0.4470, 0.7410], [0.8500, 0.3250, 0.0980]}; % 蓝和橙

% --- 程序主逻辑 ---

% 1. 让用户选择包含txt文件的文件夹
folder_path = 'D:\Pycharm_Projects\ADHD-master\data\额头信号去眼电';

% 2. 获取文件夹中的所有txt文件
file_list = dir(fullfile(folder_path, '*.txt'));
if isempty(file_list)
    error('在指定的文件夹中未找到任何 .txt 文件。');
end

% 3. 初始化用于存储结果的数组
num_files = length(file_list);
resting_means = zeros(num_files, 1);
attention_means = zeros(num_files, 1);
resting_vars = zeros(num_files, 1);
attention_vars = zeros(num_files, 1);

% 新增：初始化时序数据存储
resting_time_series = cell(num_files, 1);
attention_time_series = cell(num_files, 1);
resting_time_points = cell(num_files, 1);
attention_time_points = cell(num_files, 1);

% 4. 并行处理每个文件
fprintf('--- 开始处理文件夹中的所有文件 (多线程模式) ---\n');

% 创建并行池（如果尚未创建）
if isempty(gcp('nocreate'))
    parpool; % 使用默认的工作线程数
end

parfor i = 1:num_files
    file_name = file_list(i).name;
    full_file_path = fullfile(folder_path, file_name);

    fprintf('\n正在处理文件 %d/%d: %s\n', i, num_files, file_name);

    try
        % a. 加载和预处理数据
        data = importdata(full_file_path);
        eeg_data = data(:, 1);
        plot_data = eeg_data;
%         [~, plot_data] = EEGPreprocess(eeg_data, Fs, "none");
        t = (0:length(eeg_data)-1) / Fs;

        % b. 初始化单个文件的结果存储
        file_results = struct();

        % c. 对静息和注意力两个阶段进行样本熵计算
        for j = 1:numel(time_periods.names)
            phase_name_var = time_periods.var_names{j};
            current_time_range = time_periods.ranges{j};

            % 如果是注意力阶段，动态调整结束时间
            if strcmp(phase_name_var, 'Attention')
                % 确保注意力阶段的结束时间不超过信号总时长
                end_time = min(current_time_range(2), t(end));
                current_time_range = [current_time_range(1), end_time];
            end

            % 提取该时间段的数据索引
            phase_idx_global = find(t >= current_time_range(1) & t < current_time_range(2));
            if isempty(phase_idx_global)
                warning('文件 %s 中未找到时间段 %s 的数据。', file_name, time_periods.names{j});
                file_results.(phase_name_var).ratios = NaN;
                file_results.(phase_name_var).time_points = NaN;
                continue;
            end
            
            % 转换为样本点数
            window_samples = round(window_length * Fs);
            step_samples = round(step_size * Fs);

            % 计算滑动窗口数量
            n_windows = floor((length(phase_idx_global) - window_samples) / step_samples) + 1;
            
            % 预分配数组
            ratios = zeros(1, n_windows);
            time_points = zeros(1, n_windows); % 存储每个窗口的中心时间
            
            % 在每个窗口上计算样本熵
            for win = 1:n_windows
                start_idx = phase_idx_global(1) + (win-1)*step_samples;
                end_idx = start_idx + window_samples - 1;
                
                if end_idx > length(eeg_data)
                    continue;
                end
                
                segment = eeg_data(start_idx:end_idx);
%                 segment = EEGPreprocess(segment, Fs, "none");
%                 Samp = FuzzEn(segment);
%                 ratios(win) = Samp(1); 
                
%               ratios(win) = compute_power_ratio(segment, Fs, theta_band, beta_band);
%               ratios(win) = calculateTBR(segment, 250)
%               Samp = SampEn(segment);
%               ratios(win) = Samp(3); 
              [feature,~,~] = calculateComplexity(segment,250);
              ratios(win)= feature;
                
                % 计算窗口中心时间
                center_time = t(start_idx) + window_length/2;
                time_points(win) = center_time;
            end
            
            % 保存结果，移除未计算的零值
            valid_idx = ratios ~= 0;
            file_results.(phase_name_var).ratios = ratios(valid_idx);
            file_results.(phase_name_var).time_points = time_points(valid_idx);
        end
        
        % d. 存储当前文件的均值和方差
        current_resting_ratios = file_results.Resting.ratios;
        current_attention_ratios = file_results.Attention.ratios;
        
        if ~isempty(current_resting_ratios)
            resting_means(i) = mean(current_resting_ratios, 'omitnan');
            resting_vars(i) = var(current_resting_ratios, 'omitnan');
            % 新增：保存时序数据
            resting_time_series{i} = current_resting_ratios;
            resting_time_points{i} = file_results.Resting.time_points;
        else
            resting_means(i) = NaN;
            resting_vars(i) = NaN;
            resting_time_series{i} = [];
            resting_time_points{i} = [];
        end
        
        if ~isempty(current_attention_ratios)
            attention_means(i) = mean(current_attention_ratios, 'omitnan');
            attention_vars(i) = var(current_attention_ratios, 'omitnan');
            % 新增：保存时序数据
            attention_time_series{i} = current_attention_ratios;
            attention_time_points{i} = file_results.Attention.time_points;
        else
            attention_means(i) = NaN;
            attention_vars(i) = NaN;
            attention_time_series{i} = [];
            attention_time_points{i} = [];
        end

    catch ME
        % 如果处理文件时出错，记录错误信息并跳过
        fprintf('处理文件 %s 时发生错误: %s\n', file_name, ME.message);
        resting_means(i) = NaN;
        attention_means(i) = NaN;
        resting_vars(i) = NaN;
        attention_vars(i) = NaN;
        resting_time_series{i} = [];
        attention_time_series{i} = [];
        resting_time_points{i} = [];
        attention_time_points{i} = [];
        continue;
    end
end

% 5. 最终统计和结果输出
% 移除NaN值，只对成功处理的文件进行统计
valid_indices = ~isnan(resting_means) & ~isnan(attention_means);
valid_resting_means = resting_means(valid_indices);
valid_attention_means = attention_means(valid_indices);
valid_resting_vars = resting_vars(valid_indices);
valid_attention_vars = attention_vars(valid_indices);

% 新增：筛选有效的时序数据
valid_resting_time_series = resting_time_series(valid_indices);
valid_attention_time_series = attention_time_series(valid_indices);
valid_resting_time_points = resting_time_points(valid_indices);
valid_attention_time_points = attention_time_points(valid_indices);

total_valid_files = length(valid_resting_means);
if total_valid_files == 0
    disp('没有成功处理的文件，无法进行最终统计。');
    return;
end

% 计算静息均值大于注意力均值的比例
mean_greater_count = sum(valid_resting_means > valid_attention_means);
mean_ratio = mean_greater_count / total_valid_files;

% 计算静息方差大于注意力方差的比例
var_greater_count = sum(valid_resting_vars > valid_attention_vars);
var_ratio = var_greater_count / total_valid_files;

% 打印最终结果
fprintf('\n\n--- 最终统计结果 (基于 %d 个成功处理的文件) ---\n', total_valid_files);
fprintf('静息阶段样本熵均值 > 注意力阶段的比例: %.2f%%\n', mean_ratio * 100);
fprintf('静息阶段样本熵方差 > 注意力阶段的比例: %.2f%%\n', var_ratio * 100);
fprintf('----------------------------------------------\n');
fprintf('--- 所有文件处理完毕 ---\n');

% --- 新增：绘制特征时序对比图（按照参考代码风格）---
% --- 新增：绘制特征时序对比图（每组数据单独绘制）---
% --- 新增：为每个文件单独绘制特征时序对比图 ---
for i = 1:total_valid_files
    if isempty(valid_resting_time_series{i}) || isempty(valid_attention_time_series{i})
        continue; % 跳过无效数据
    end
    
    % 创建单独的图形窗口
    fig = figure('Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.6], ...
                 'Name', ['样本熵特征时序 - ' file_list(valid_indices(i)).name]);
    hold on;
    
    % 获取当前文件名（不含扩展名）
    [~, file_name_only] = fileparts(file_list(valid_indices(i)).name);
    
    % 绘制静息阶段
    plot(valid_resting_time_points{i}, valid_resting_time_series{i}, ...
         '-o', 'Color', [0, 0.4470, 0.7410], 'LineWidth', 2, ...
         'MarkerFaceColor', [0, 0.4470, 0.7410], 'MarkerSize', 6, ...
         'DisplayName', '静息阶段');
    
    % 绘制静息阶段均值线
    mean_val_rest = mean(valid_resting_time_series{i}, 'omitnan');
    line([min(valid_resting_time_points{i}), max(valid_resting_time_points{i})], ...
         [mean_val_rest, mean_val_rest], 'Color', [0, 0.4470, 0.7410], ...
         'LineStyle', '--', 'LineWidth', 2, 'DisplayName', '静息均值');
    
    % 绘制注意力阶段
    plot(valid_attention_time_points{i}, valid_attention_time_series{i}, ...
         '-o', 'Color', [0.8500, 0.3250, 0.0980], 'LineWidth', 2, ...
         'MarkerFaceColor', [0.8500, 0.3250, 0.0980], 'MarkerSize', 6, ...
         'DisplayName', '注意力阶段');
    
    % 绘制注意力阶段均值线
    mean_val_att = mean(valid_attention_time_series{i}, 'omitnan');
    line([min(valid_attention_time_points{i}), max(valid_attention_time_points{i})], ...
         [mean_val_att, mean_val_att], 'Color', [0.8500, 0.3250, 0.0980], ...
         'LineStyle', '--', 'LineWidth', 2, 'DisplayName', '注意力均值');
    
    % 添加背景色块以区分时间段
    yl = ylim; % 获取当前Y轴范围
    for j = 1:numel(time_periods.names)
        time_range = time_periods.ranges{j};
        patch([time_range(1) time_range(2) time_range(2) time_range(1)], ...
              [yl(1) yl(1) yl(2) yl(2)], time_periods.colors{j}, ...
              'FaceAlpha', 0.1, 'EdgeColor', 'none');
    end
    
    % 添加分隔线
    line([70, 70], yl, 'Color', 'k', 'LineWidth', 1.5, 'LineStyle', ':');
    line([80, 80], yl, 'Color', 'k', 'LineWidth', 1.5, 'LineStyle', ':');
    
    % 添加阶段标注
    text(mean(time_periods.ranges{1}), yl(2)*0.95, '静息阶段', ...
         'FontSize', 12, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    text(mean(time_periods.ranges{2}), yl(2)*0.95, '注意力阶段', ...
         'FontSize', 12, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % 添加标签和标题
    xlabel('时间 (秒)', 'FontSize', 12);
    ylabel('样本熵值', 'FontSize', 12);
    title(['样本熵时序对比 - ' file_name_only], 'FontSize', 14, 'Interpreter', 'none');
    grid on;
    box on;
    
    % 设置坐标轴范围
    xlim([0, max(time_periods.ranges{2}) + 10]);
    
    % 添加图例
    legend('show', 'Location', 'best', 'FontSize', 10);
    
    hold off;
    
    % 可选：保存图片
    % saveas(fig, fullfile(folder_path, [file_name_only '_时序图.png']));
end