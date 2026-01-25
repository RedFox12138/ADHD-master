% --- 特征提取与对比：批量处理文件 (V5.0 - 受试者级别分析) ---
% 该脚本用于批量处理受试者文件夹，每个子文件夹代表一个受试者
% 提取静息和注意力阶段的多种特征，并进行受试者级别的统计分析
% 前10-40s为静息阶段，40s后为注意力阶段。
%
% 版本更新 (V5.0):
% - 改为基于受试者（子文件夹）的分析结构
% - 支持三种熵特征：XSampEn、SampEn、cXMSE
% - 配对t检验分析静息与注意力阶段差异
% - 计算Cohen's d效应量
% - 生成详细的统计报告和受试者特征对比图
%
% 特征说明：
% - XSampEn: 交叉样本熵，分析前后两部分信号的交叉复杂度
% - SampEn: 样本熵，反映信号的复杂度和不可预测性  
% - cXMSE: 复合多尺度交叉熵，分析两段信号的交叉多尺度复杂度
%
% 统计输出：
% - Cohen's d: 效应量大小 (|d|<0.2极小, 0.2-0.5小, 0.5-0.8中等, >0.8大)
% - p值: 配对t检验显著性水平
% - 显著性标记: *** p<0.001, ** p<0.01, * p<0.05, n.s. 不显著

clc;
clear;
close all;

% --- 用户设定参数 ---
Fs = 250; % 采样率 (Hz)
window_length = 6; % 窗长 (秒)
step_size = 2; % 滑动步长 (秒)
perm_wt_val_w = 4; % WPE_IA_Composite 的加权排列熵指数
inv_alpha_val_w = 0.6; % WPE_IA_Composite 的Alpha倒数指数

% 定义要计算的特征列表（可扩展）
feature_names = {'XSampEn', 'SampEn', 'cXMSE'};
% 特征说明：
% - XSampEn: 交叉样本熵，分析前后两部分信号的交叉复杂度
% - SampEn: 样本熵，反映信号的复杂度和不可预测性
% - cXMSE: 复合多尺度交叉熵，分析两段信号的交叉多尺度复杂度
n_features = length(feature_names);

% 定义两个核心时间段（静息和注意力）
time_periods.names = {'静息', '注意力'};
time_periods.ranges = {[10, 40], [40, Inf]}; % 前40s为静息，40s后为注意力
time_periods.var_names = {'Resting', 'Attention'};
time_periods.colors = {[0, 0.4470, 0.7410], [0.8500, 0.3250, 0.0980]}; % 蓝和橙

% --- 程序主逻辑 ---

% 1. 让用户选择包含受试者子文件夹的根目录
folder_path = uigetdir('D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\微信小程序\TXT文件\预处理后的完整数据，未分段', '选择包含受试者文件夹的根目录');
if folder_path == 0
    error('用户取消了文件夹选择');
end

% 2. 获取所有子文件夹（每个子文件夹代表一个受试者）
subject_folders = dir(folder_path);
subject_folders = subject_folders([subject_folders.isdir]); % 只保留文件夹
subject_folders = subject_folders(~ismember({subject_folders.name}, {'.', '..'})); % 排除 . 和 ..

if isempty(subject_folders)
    error('在指定的文件夹中未找到任何子文件夹（受试者）。');
end

num_subjects = length(subject_folders);
fprintf('找到 %d 个受试者文件夹\n', num_subjects);

% 3. 初始化用于存储受试者级别结果的数组（动态支持多个特征）
% 动态初始化所有特征的存储结构
subject_data = struct();
% 初始化计算时间统计结构
timing_stats = struct();
for feat_idx = 1:n_features
    feat_name = feature_names{feat_idx};
    % 为每个特征创建存储字段（使用有效的字段名）
    safe_feat_name = matlab.lang.makeValidName(feat_name);
    subject_data.(safe_feat_name).resting_means = zeros(num_subjects, 1); % 每个受试者的静息均值
    subject_data.(safe_feat_name).attention_means = zeros(num_subjects, 1); % 每个受试者的注意力均值
    subject_data.(safe_feat_name).resting_all_values = cell(num_subjects, 1); % 受试者所有文件的静息值
    subject_data.(safe_feat_name).attention_all_values = cell(num_subjects, 1); % 受试者所有文件的注意力值
    subject_data.(safe_feat_name).resting_time_series = cell(num_subjects, 1); % 每个受试者的静息时序数据
    subject_data.(safe_feat_name).attention_time_series = cell(num_subjects, 1); % 每个受试者的注意力时序数据
    subject_data.(safe_feat_name).display_name = feat_name; % 保存原始显示名称
    
    % 初始化该特征的时间统计
    timing_stats.(safe_feat_name).total_time = 0; % 总计算时间（秒）
    timing_stats.(safe_feat_name).sample_count = 0; % 样本计数（窗口数）
    timing_stats.(safe_feat_name).all_times = []; % 所有单次计算时间
    timing_stats.(safe_feat_name).display_name = feat_name; % 显示名称
end

% 受试者名称和时间点
subject_names = cell(num_subjects, 1);
subject_resting_time_points = cell(num_subjects, 1);
subject_attention_time_points = cell(num_subjects, 1);

% 添加feature目录到路径
feature_path = fullfile(fileparts(mfilename('fullpath')), 'feature');
if exist(feature_path, 'dir')
    addpath(feature_path);
end

% 4. 串行处理每个受试者（每个子文件夹）
fprintf('--- 开始处理所有受试者 ---\n');

for subj_idx = 1:num_subjects
    subject_name = subject_folders(subj_idx).name;
    subject_path = fullfile(folder_path, subject_name);
    subject_names{subj_idx} = subject_name;
    
    fprintf('\n========== 处理受试者 %d/%d: %s ==========\n', subj_idx, num_subjects, subject_name);
    
    % 获取该受试者文件夹中的所有txt文件
    file_list = dir(fullfile(subject_path, '*.txt'));
    
    if isempty(file_list)
        warning('受试者 %s 的文件夹中未找到任何 .txt 文件，跳过。', subject_name);
        % 标记为NaN
        for feat_idx_skip = 1:n_features
            safe_name_skip = matlab.lang.makeValidName(feature_names{feat_idx_skip});
            subject_data.(safe_name_skip).resting_means(subj_idx) = NaN;
            subject_data.(safe_name_skip).attention_means(subj_idx) = NaN;
            subject_data.(safe_name_skip).resting_all_values{subj_idx} = [];
            subject_data.(safe_name_skip).attention_all_values{subj_idx} = [];
        end
        continue;
    end
    
    num_files = length(file_list);
    fprintf('  找到 %d 个文件\n', num_files);
    
    % 为当前受试者的所有文件初始化临时存储
    temp_feature_data = struct();
    temp_resting_time_series = struct();
    temp_attention_time_series = struct();
    temp_resting_time_points = [];
    temp_attention_time_points = [];
    
    % 为每个文件单独存储时序数据（用于绘制单独的时序图）
    file_time_series_data = struct();
    
    for feat_idx_temp = 1:n_features
        safe_name_temp = matlab.lang.makeValidName(feature_names{feat_idx_temp});
        temp_feature_data.(safe_name_temp).all_resting_values = [];
        temp_feature_data.(safe_name_temp).all_attention_values = [];
        temp_resting_time_series.(safe_name_temp) = [];
        temp_attention_time_series.(safe_name_temp) = [];
        
        % 初始化文件级别的时序数据存储
        file_time_series_data.(safe_name_temp) = cell(num_files, 1);
    end
    
    % 处理该受试者的每个文件
    for file_idx = 1:num_files
        file_name = file_list(file_idx).name;
        full_file_path = fullfile(subject_path, file_name);
        
        fprintf('  处理文件 %d/%d: %s\n', file_idx, num_files, file_name);

        try
            % a. 加载数据
            data = importdata(full_file_path);
            eeg_data = data(:, 1);
            t = (0:length(eeg_data)-1) / Fs;
            
            fprintf('    信号长度: %.2f 秒\n', t(end));

            % b. 初始化单个文件的结果存储
            file_results = struct();

            % c. 对静息和注意力两个阶段进行特征计算
            for j = 1:numel(time_periods.names)
                phase_name_var = time_periods.var_names{j};
                current_time_range = time_periods.ranges{j};

                % 如果是注意力阶段，动态调整结束时间
                if strcmp(phase_name_var, 'Attention')
                    % 确保注意力阶段的结束时间不超过信号总时长
                    end_time = t(end);
                    current_time_range = [current_time_range(1), end_time];
                end

                % 提取该时间段的数据索引
                if isinf(current_time_range(2))
                    phase_idx_global = find(t >= current_time_range(1));
                else
                    phase_idx_global = find(t >= current_time_range(1) & t < current_time_range(2));
                end
                
                if isempty(phase_idx_global)
                    warning('受试者 %s 文件 %s 中未找到时间段 %s 的数据。', subject_name, file_name, time_periods.names{j});
                    file_results.(phase_name_var).features = [];
                    file_results.(phase_name_var).time_points = [];
                    continue;
                end
                
                % 转换为样本点数
                window_samples = round(window_length * Fs);
                step_samples = round(step_size * Fs);

                % 计算滑动窗口数量
                n_windows = floor((length(phase_idx_global) - window_samples) / step_samples) + 1;
                
                % 动态预分配数组（支持所有特征）
                features_array = struct();
                for feat_idx_pre = 1:n_features
                    safe_name = matlab.lang.makeValidName(feature_names{feat_idx_pre});
                    features_array.(safe_name) = zeros(1, n_windows);
                end
                time_points = zeros(1, n_windows); % 存储每个窗口的中心时间
                
                % 在每个窗口上计算特征
                for win = 1:n_windows
                    start_idx = phase_idx_global(1) + (win-1)*step_samples;
                    end_idx = start_idx + window_samples - 1;
                    
                    if end_idx > length(eeg_data)
                        continue;
                    end
                    
                    segment = eeg_data(start_idx:end_idx);
                    
                    try
                        % 动态计算所有特征
                        temp_features = struct();
                        
                        % 根据 feature_names 计算对应特征
                        for feat_idx_inner = 1:n_features
                            feat_name_inner = feature_names{feat_idx_inner};
                            safe_name_inner = matlab.lang.makeValidName(feat_name_inner);
                            
                            % 开始计时
                            tic;
                            
                            switch feat_name_inner
                                case 'SampEn'
                                    % 样本熵，反映信号的复杂度和不可预测性
                                    sampen_result = SampEn(segment);
                                    temp_features.(safe_name_inner) = sampen_result(3);
                                
                                case 'XSampEn'
                                    % 交叉样本熵，分析前后两部分信号的交叉复杂度
                                    mid_point = floor(length(segment) / 2);
                                    if mid_point > 10
                                        sig1 = segment(1:mid_point);
                                        sig2 = segment(mid_point+1:end);
                                        xsamp_result = XSampEn(sig1, sig2);
                                        temp_features.(safe_name_inner) = xsamp_result(3);
                                    else
                                        temp_features.(safe_name_inner) = NaN;
                                    end
                                
                                case 'cXMSE'
                                    % 复合多尺度交叉熵，分析两段信号的交叉多尺度复杂度
                                    mid_point = floor(length(segment) / 2);
                                    if mid_point > 30
                                        sig1 = segment(1:mid_point);
                                        sig2 = segment(mid_point+1:end);
                                        Mobj = struct('Func', @XSampEn);
                                        [~, CI] = cXMSEn(sig1, sig2, Mobj, 'Scales', 3);
                                        temp_features.(safe_name_inner) = CI;
                                    else
                                        temp_features.(safe_name_inner) = NaN;
                                    end
                                
                                otherwise
                                    warning('未知特征类型: %s，跳过', feat_name_inner);
                                    temp_features.(safe_name_inner) = NaN;
                            end
                            
                            % 结束计时并记录
                            elapsed_time = toc;
                            if ~isnan(temp_features.(safe_name_inner))
                                timing_stats.(safe_name_inner).total_time = timing_stats.(safe_name_inner).total_time + elapsed_time;
                                timing_stats.(safe_name_inner).sample_count = timing_stats.(safe_name_inner).sample_count + 1;
                                timing_stats.(safe_name_inner).all_times = [timing_stats.(safe_name_inner).all_times, elapsed_time];
                            end
                        end
                        
                        % 将计算结果存储到对应的特征数组中
                        for feat_idx_inner = 1:n_features
                            safe_name_inner = matlab.lang.makeValidName(feature_names{feat_idx_inner});
                            features_array.(safe_name_inner)(win) = temp_features.(safe_name_inner);
                        end
                    catch ME
                        % 如果计算失败，所有特征都标记为NaN
                        for feat_idx_inner = 1:n_features
                            safe_name_inner = matlab.lang.makeValidName(feature_names{feat_idx_inner});
                            features_array.(safe_name_inner)(win) = NaN;
                        end
                    end
                    
                    % 计算窗口中心时间
                    center_time = t(start_idx) + window_length/2;
                    time_points(win) = center_time;
                end
                
                % 保存结果，移除NaN值（动态处理所有特征）
                first_valid_idx = [];
                for feat_idx_save = 1:n_features
                    safe_name_save = matlab.lang.makeValidName(feature_names{feat_idx_save});
                    valid_idx_current = ~isnan(features_array.(safe_name_save));
                    
                    file_results.(phase_name_var).(safe_name_save) = features_array.(safe_name_save)(valid_idx_current);
                    
                    % 第一个特征的有效索引用于时间点
                    if feat_idx_save == 1
                        first_valid_idx = valid_idx_current;
                    end
                end
                file_results.(phase_name_var).time_points = time_points(first_valid_idx);
            end

            % d. 从 file_results 中提取当前文件的所有特征值并累积到受试者的临时存储
            for feat_idx_extract = 1:n_features
                safe_name_extract = matlab.lang.makeValidName(feature_names{feat_idx_extract});
                
                % 静息阶段 - 将当前文件的值添加到受试者的所有值中
                if isfield(file_results.Resting, safe_name_extract) && ~isempty(file_results.Resting.(safe_name_extract))
                    temp_feature_data.(safe_name_extract).all_resting_values = [...
                        temp_feature_data.(safe_name_extract).all_resting_values, ...
                        file_results.Resting.(safe_name_extract)];
                    
                    % 保存时序数据（用于绘图）
                    temp_resting_time_series.(safe_name_extract) = [...
                        temp_resting_time_series.(safe_name_extract), ...
                        file_results.Resting.(safe_name_extract)];
                end
                
                % 注意力阶段 - 将当前文件的值添加到受试者的所有值中
                if isfield(file_results.Attention, safe_name_extract) && ~isempty(file_results.Attention.(safe_name_extract))
                    temp_feature_data.(safe_name_extract).all_attention_values = [...
                        temp_feature_data.(safe_name_extract).all_attention_values, ...
                        file_results.Attention.(safe_name_extract)];
                    
                    % 保存时序数据（用于绘图）
                    temp_attention_time_series.(safe_name_extract) = [...
                        temp_attention_time_series.(safe_name_extract), ...
                        file_results.Attention.(safe_name_extract)];
                end
            end
            
            % e. 保存时间点
            if isfield(file_results, 'Resting') && isfield(file_results.Resting, 'time_points')
                temp_resting_time_points = [temp_resting_time_points, file_results.Resting.time_points];
            end
            if isfield(file_results, 'Attention') && isfield(file_results.Attention, 'time_points')
                temp_attention_time_points = [temp_attention_time_points, file_results.Attention.time_points];
            end
            
            % f. 保存该文件的时序数据（用于后续单独绘图）
            for feat_idx_file = 1:n_features
                safe_name_file = matlab.lang.makeValidName(feature_names{feat_idx_file});
                file_time_series_data.(safe_name_file){file_idx} = struct();
                file_time_series_data.(safe_name_file){file_idx}.file_name = file_name;
                
                if isfield(file_results, 'Resting') && isfield(file_results.Resting, safe_name_file)
                    file_time_series_data.(safe_name_file){file_idx}.resting_values = file_results.Resting.(safe_name_file);
                    file_time_series_data.(safe_name_file){file_idx}.resting_times = file_results.Resting.time_points;
                else
                    file_time_series_data.(safe_name_file){file_idx}.resting_values = [];
                    file_time_series_data.(safe_name_file){file_idx}.resting_times = [];
                end
                
                if isfield(file_results, 'Attention') && isfield(file_results.Attention, safe_name_file)
                    file_time_series_data.(safe_name_file){file_idx}.attention_values = file_results.Attention.(safe_name_file);
                    file_time_series_data.(safe_name_file){file_idx}.attention_times = file_results.Attention.time_points;
                else
                    file_time_series_data.(safe_name_file){file_idx}.attention_values = [];
                    file_time_series_data.(safe_name_file){file_idx}.attention_times = [];
                end
            end

        catch ME
            warning('处理文件 %s 时出错: %s', file_name, ME.message);
        end
    end
    
    % g. 为该受试者的每个文件绘制时序图
    fprintf('  绘制受试者 %s 的单个样本时序图...\n', subject_name);
    
    % 创建受试者专属的时序图文件夹
    subject_timeseries_folder = fullfile(folder_path, '单样本时序图', subject_name);
    if ~exist(subject_timeseries_folder, 'dir')
        mkdir(subject_timeseries_folder);
    end
    
    for file_idx = 1:num_files
        current_file_name = file_list(file_idx).name;
        [~, file_basename, ~] = fileparts(current_file_name);
        
        % 为每个特征绘制该文件的时序图
        for feat_idx_plot = 1:n_features
            safe_name_plot = matlab.lang.makeValidName(feature_names{feat_idx_plot});
            display_name_plot = feature_names{feat_idx_plot};
            
            % 获取该文件的时序数据
            if isempty(file_time_series_data.(safe_name_plot){file_idx})
                continue;
            end
            
            file_data = file_time_series_data.(safe_name_plot){file_idx};
            resting_vals = file_data.resting_values;
            resting_times = file_data.resting_times;
            attention_vals = file_data.attention_values;
            attention_times = file_data.attention_times;
            
            % 如果该文件没有任何有效数据，跳过
            if isempty(resting_vals) && isempty(attention_vals)
                continue;
            end
            
            % 创建图形（不显示）
            fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 500]);
            
            % 绘制静息阶段（蓝色）
            if ~isempty(resting_vals)
                plot(resting_times, resting_vals, 'b.-', 'LineWidth', 1.5, 'MarkerSize', 6);
                hold on;
            end
            
            % 绘制注意力阶段（红色）
            if ~isempty(attention_vals)
                plot(attention_times, attention_vals, 'r.-', 'LineWidth', 1.5, 'MarkerSize', 6);
            end
            
            % 添加垂直分界线（40秒处）
            if ~isempty(resting_times) || ~isempty(attention_times)
                y_limits = ylim;
                line([40, 40], y_limits, 'Color', 'k', 'LineStyle', '--', 'LineWidth', 2);
            end
            
            hold off;
            
            % 设置图形属性
            xlabel('时间 (秒)', 'FontSize', 12);
            ylabel(display_name_plot, 'FontSize', 12);
            title(sprintf('受试者: %s | 样本: %s | 特征: %s', subject_name, file_basename, display_name_plot), ...
                  'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
            legend({'静息阶段', '注意力阶段', '阶段分界(40s)'}, 'Location', 'best');
            grid on;
            
            % 保存图形
            output_filename = fullfile(subject_timeseries_folder, ...
                sprintf('%s_%s.png', file_basename, safe_name_plot));
            saveas(fig, output_filename);
            close(fig);
        end
    end
    
    fprintf('  受试者 %s 的单样本时序图已保存到: %s\n', subject_name, subject_timeseries_folder);
    
    % h. 聚合该受试者的所有数据并保存时序数据
    fprintf('  计算受试者 %s 的特征均值...\n', subject_name);
    for feat_idx_subj = 1:n_features
        safe_name_subj = matlab.lang.makeValidName(feature_names{feat_idx_subj});
        
        % 计算静息阶段的均值（所有文件的所有窗口的均值）
        if ~isempty(temp_feature_data.(safe_name_subj).all_resting_values)
            subject_data.(safe_name_subj).resting_means(subj_idx) = ...
                mean(temp_feature_data.(safe_name_subj).all_resting_values, 'omitnan');
            subject_data.(safe_name_subj).resting_all_values{subj_idx} = ...
                temp_feature_data.(safe_name_subj).all_resting_values;
            subject_data.(safe_name_subj).resting_time_series{subj_idx} = ...
                temp_resting_time_series.(safe_name_subj);
        else
            subject_data.(safe_name_subj).resting_means(subj_idx) = NaN;
            subject_data.(safe_name_subj).resting_all_values{subj_idx} = [];
            subject_data.(safe_name_subj).resting_time_series{subj_idx} = [];
        end
        
        % 计算注意力阶段的均值（所有文件的所有窗口的均值）
        if ~isempty(temp_feature_data.(safe_name_subj).all_attention_values)
            subject_data.(safe_name_subj).attention_means(subj_idx) = ...
                mean(temp_feature_data.(safe_name_subj).all_attention_values, 'omitnan');
            subject_data.(safe_name_subj).attention_all_values{subj_idx} = ...
                temp_feature_data.(safe_name_subj).all_attention_values;
            subject_data.(safe_name_subj).attention_time_series{subj_idx} = ...
                temp_attention_time_series.(safe_name_subj);
        else
            subject_data.(safe_name_subj).attention_means(subj_idx) = NaN;
            subject_data.(safe_name_subj).attention_all_values{subj_idx} = [];
            subject_data.(safe_name_subj).attention_time_series{subj_idx} = [];
        end
    end
    
    % 保存该受试者的时间点
    subject_resting_time_points{subj_idx} = temp_resting_time_points;
    subject_attention_time_points{subj_idx} = temp_attention_time_points;
    
    fprintf('  受试者 %s 处理完成\n', subject_name);
end

% 定义有效受试者索引：使用第一个特征的数据来判断（所有特征应该同步）
first_feat_safe_name = matlab.lang.makeValidName(feature_names{1});
valid_indices = ~isnan(subject_data.(first_feat_safe_name).resting_means) & ...
                ~isnan(subject_data.(first_feat_safe_name).attention_means);

total_valid_subjects = sum(valid_indices);
if total_valid_subjects == 0
    disp('没有成功处理的受试者，无法进行最终统计。');
    return;
end

fprintf('\n--- 处理完成：共 %d 个有效受试者 ---\n', total_valid_subjects);

%% ========== 每个受试者内部统计检验分析 ==========
fprintf('\n\n========== 受试者内部配对t检验和效应量分析 ==========\n');

% 创建输出文件夹
stats_output_folder = fullfile(folder_path, '受试者统计检验结果');
if ~exist(stats_output_folder, 'dir')
    mkdir(stats_output_folder);
end

figure_output_folder = fullfile(folder_path, '受试者特征对比图');
if ~exist(figure_output_folder, 'dir')
    mkdir(figure_output_folder);
end

% 为每个受试者生成统计报告
valid_subject_names = subject_names(valid_indices);
valid_idx_list = find(valid_indices);

% 初始化汇总表格
summary_results = cell(total_valid_subjects + 1, n_features * 3 + 1);
summary_results{1, 1} = '受试者';
for feat_idx = 1:n_features
    col_start = (feat_idx - 1) * 3 + 2;
    summary_results{1, col_start} = [feature_names{feat_idx} '_p值'];
    summary_results{1, col_start + 1} = [feature_names{feat_idx} '_Cohen_d'];
    summary_results{1, col_start + 2} = [feature_names{feat_idx} '_显著性'];
end

% 对每个受试者进行统计分析
for subj_idx = 1:total_valid_subjects
    original_subj_idx = valid_idx_list(subj_idx);
    subj_name = valid_subject_names{subj_idx};
    
    fprintf('\n--- 受试者 %d/%d: %s ---\n', subj_idx, total_valid_subjects, subj_name);
    fprintf('%-20s %12s %12s %12s %12s %12s %10s\n', ...
            '特征名称', '静息均值', '注意力均值', 'Cohen''s d', 'p值', '显著性', '效应大小');
    fprintf('%s\n', repmat('-', 1, 100));
    
    summary_results{subj_idx + 1, 1} = subj_name;
    
    % 对每个特征进行统计分析
    for feat_idx = 1:n_features
        safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
        feat_name = subject_data.(safe_name).display_name;
        
        % 获取该受试者的静息和注意力数据
        rest_values = subject_data.(safe_name).resting_all_values{original_subj_idx};
        att_values = subject_data.(safe_name).attention_all_values{original_subj_idx};
        
        if isempty(rest_values) || isempty(att_values)
            fprintf('%-20s %s\n', feat_name, '数据不足');
            col_start = (feat_idx - 1) * 3 + 2;
            summary_results{subj_idx + 1, col_start} = NaN;
            summary_results{subj_idx + 1, col_start + 1} = NaN;
            summary_results{subj_idx + 1, col_start + 2} = 'N/A';
            continue;
        end
        
        % 移除NaN值
        rest_values = rest_values(~isnan(rest_values));
        att_values = att_values(~isnan(att_values));
        
        if length(rest_values) < 2 || length(att_values) < 2
            fprintf('%-20s %s\n', feat_name, '样本数不足');
            col_start = (feat_idx - 1) * 3 + 2;
            summary_results{subj_idx + 1, col_start} = NaN;
            summary_results{subj_idx + 1, col_start + 1} = NaN;
            summary_results{subj_idx + 1, col_start + 2} = 'N/A';
            continue;
        end
        
        % 1. 配对t检验（需要等长数据，这里用独立样本t检验）
        [h, p_value] = ttest2(rest_values, att_values);
        
        % 2. Cohen's d (独立样本效应量)
        mean_rest = mean(rest_values);
        mean_att = mean(att_values);
        std_pooled = sqrt((std(rest_values)^2 + std(att_values)^2) / 2);
        cohens_d = (mean_rest - mean_att) / std_pooled;
        
        % 3. 效应大小解释
        effect_size = interpret_cohens_d(cohens_d);
        
        % 4. 显著性标记
        significance = get_significance_star(p_value);
        
        % 打印结果
        fprintf('%-20s %12.4f %12.4f %12.4f %12.6f %10s %10s\n', ...
                feat_name, mean_rest, mean_att, abs(cohens_d), p_value, ...
                significance, effect_size);
        
        % 保存到汇总表格
        col_start = (feat_idx - 1) * 3 + 2;
        summary_results{subj_idx + 1, col_start} = p_value;
        summary_results{subj_idx + 1, col_start + 1} = abs(cohens_d);
        summary_results{subj_idx + 1, col_start + 2} = significance;
    end
end

fprintf('\n%s\n', repmat('=', 1, 100));
fprintf('显著性水平: *** p<0.001, ** p<0.01, * p<0.05, n.s. 不显著\n');
fprintf('Cohen''s d 解释: |d|<0.2 极小效应, 0.2-0.5 小效应, 0.5-0.8 中等效应, >0.8 大效应\n');

% 保存汇总统计结果
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
summary_filename = fullfile(stats_output_folder, ['受试者统计汇总_' timestamp '.xlsx']);

try
    writecell(summary_results, summary_filename);
    fprintf('\n受试者统计汇总已保存到: %s\n', summary_filename);
catch
    warning('无法保存Excel文件，尝试保存为CSV格式...');
    csv_filename = fullfile(stats_output_folder, ['受试者统计汇总_' timestamp '.csv']);
    writecell(summary_results, csv_filename);
    fprintf('受试者统计汇总已保存到: %s\n', csv_filename);
end

%% ========== 跨受试者汇总统计（可选参考） ==========
fprintf('\n\n========== 跨受试者汇总统计（仅供参考） ==========\n');
fprintf('%-20s %12s %12s %12s %12s\n', ...
        '特征名称', '静息均值±std', '注意力均值±std', '显著受试者数', '总受试者数');
fprintf('%s\n', repmat('-', 1, 80));

for feat_idx = 1:n_features
    safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
    display_name = subject_data.(safe_name).display_name;
    
    valid_resting_means = subject_data.(safe_name).resting_means(valid_indices);
    valid_attention_means = subject_data.(safe_name).attention_means(valid_indices);
    
    % 统计有多少受试者显示显著差异
    significant_count = 0;
    for subj_idx = 1:total_valid_subjects
        col_start = (feat_idx - 1) * 3 + 2;
        p_val = summary_results{subj_idx + 1, col_start};
        if ~isnan(p_val) && p_val < 0.05
            significant_count = significant_count + 1;
        end
    end
    
    fprintf('%-20s %12s %12s %12d %12d\n', ...
            display_name, ...
            sprintf('%.4f±%.4f', mean(valid_resting_means, 'omitnan'), std(valid_resting_means, 'omitnan')), ...
            sprintf('%.4f±%.4f', mean(valid_attention_means, 'omitnan'), std(valid_attention_means, 'omitnan')), ...
            significant_count, total_valid_subjects);
end

fprintf('\n--- 所有受试者统计分析完毕 ---\n');

%% ========== 计算时间统计报告 ==========
fprintf('\n\n========== 特征计算时间统计 ==========\n');
fprintf('%-20s %15s %15s %15s %15s %15s\n', ...
        '特征名称', '总样本数', '总时间(秒)', '平均时间(ms)', '最小时间(ms)', '最大时间(ms)');
fprintf('%s\n', repmat('-', 1, 100));

for feat_idx = 1:n_features
    safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
    display_name = timing_stats.(safe_name).display_name;
    
    total_samples = timing_stats.(safe_name).sample_count;
    total_time = timing_stats.(safe_name).total_time;
    all_times = timing_stats.(safe_name).all_times;
    
    if total_samples > 0
        avg_time_ms = (total_time / total_samples) * 1000; % 转换为毫秒
        min_time_ms = min(all_times) * 1000;
        max_time_ms = max(all_times) * 1000;
        
        fprintf('%-20s %15d %15.2f %15.4f %15.4f %15.4f\n', ...
                display_name, total_samples, total_time, avg_time_ms, min_time_ms, max_time_ms);
    else
        fprintf('%-20s %15s\n', display_name, '无有效数据');
    end
end

fprintf('\n说明:\n');
fprintf('  - 总样本数: 所有受试者所有文件中成功计算的窗口数量\n');
fprintf('  - 总时间: 该特征在所有样本上的累计计算时间\n');
fprintf('  - 平均时间: 单个样本（窗口）的平均计算时间\n');
fprintf('  - 最小/最大时间: 所有样本中计算时间的范围\n');

% 保存时间统计结果
timing_output_folder = fullfile(folder_path, '特征计算时间统计');
if ~exist(timing_output_folder, 'dir')
    mkdir(timing_output_folder);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
timing_filename = fullfile(timing_output_folder, ['计算时间统计_' timestamp '.txt']);

fid = fopen(timing_filename, 'w');
fprintf(fid, '========== 特征计算时间统计报告 ==========\n');
fprintf(fid, '生成时间: %s\n\n', datestr(now));
fprintf(fid, '%-20s %15s %15s %15s %15s %15s\n', ...
        '特征名称', '总样本数', '总时间(秒)', '平均时间(ms)', '最小时间(ms)', '最大时间(ms)');
fprintf(fid, '%s\n', repmat('-', 1, 100));

for feat_idx = 1:n_features
    safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
    display_name = timing_stats.(safe_name).display_name;
    
    total_samples = timing_stats.(safe_name).sample_count;
    total_time = timing_stats.(safe_name).total_time;
    all_times = timing_stats.(safe_name).all_times;
    
    if total_samples > 0
        avg_time_ms = (total_time / total_samples) * 1000;
        min_time_ms = min(all_times) * 1000;
        max_time_ms = max(all_times) * 1000;
        
        fprintf(fid, '%-20s %15d %15.2f %15.4f %15.4f %15.4f\n', ...
                display_name, total_samples, total_time, avg_time_ms, min_time_ms, max_time_ms);
    else
        fprintf(fid, '%-20s %15s\n', display_name, '无有效数据');
    end
end

fprintf(fid, '\n\n说明:\n');
fprintf(fid, '  - 总样本数: 所有受试者所有文件中成功计算的窗口数量\n');
fprintf(fid, '  - 总时间: 该特征在所有样本上的累计计算时间\n');
fprintf(fid, '  - 平均时间: 单个样本（窗口）的平均计算时间\n');
fprintf(fid, '  - 最小/最大时间: 所有样本中计算时间的范围\n');
fclose(fid);

fprintf('\n计算时间统计报告已保存到: %s\n', timing_filename);
fprintf('--- 计算时间统计完成 ---\n');

fprintf('\n所有受试者的单样本时序图已在数据处理过程中保存完成！\n');

%% ========== 4. 按个体统计特征随日期的变化趋势 ==========
fprintf('\n\n========== 按个体统计特征随日期的变化趋势 ==========\n');

% 创建个体变化趋势输出文件夹
individual_trend_folder = fullfile(folder_path, '个体特征变化趋势');
if ~exist(individual_trend_folder, 'dir')
    mkdir(individual_trend_folder);
end

% 为每个个体生成变化趋势分析
for subj_trend_idx = 1:total_valid_subjects
    original_subj_idx = valid_idx_list(subj_trend_idx);
    subj_name = valid_subject_names{subj_trend_idx};
    
    fprintf('\n--- 处理受试者 %d/%d: %s ---\n', subj_trend_idx, total_valid_subjects, subj_name);
    
    % 获取该受试者的所有文件
    subject_path = fullfile(folder_path, subj_name);
    file_list = dir(fullfile(subject_path, '*.txt'));
    
    if isempty(file_list)
        warning('受试者 %s 无数据文件，跳过', subj_name);
        continue;
    end
    
    % 为每个文件提取日期信息和特征均值
    file_dates = [];
    file_resting_means = struct();
    file_attention_means = struct();
    file_names_list = {};
    
    for feat_idx = 1:n_features
        safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
        file_resting_means.(safe_name) = [];
        file_attention_means.(safe_name) = [];
    end
    
    % 遍历该受试者的每个文件，提取特征和日期
    for file_idx = 1:length(file_list)
        file_name = file_list(file_idx).name;
        full_file_path = fullfile(subject_path, file_name);
        file_names_list{file_idx} = file_name;
        
        % 尝试从文件名中提取日期（假设格式包含日期信息）
        % 文件名前四位数字为MMDD格式：例如1201表示12月01日
        file_date = extract_date_from_filename(file_name);
        if isempty(file_date)
            % 如果无法从文件名提取，使用文件的修改时间
            file_info = dir(full_file_path);
            file_date = file_info.datenum;
        end
        % 如果提取到的是MMDD数值，直接使用；否则使用datenum
        if ~isempty(file_date) && file_date > 100
            % 是MMDD格式的数值，直接使用
            file_dates = [file_dates; file_date];
        else
            % 使用文件修改时间
            file_info = dir(full_file_path);
            file_dates = [file_dates; file_info.datenum];
        end
        
        % 重新计算该文件的静息和注意力特征均值
        try
            data = importdata(full_file_path);
            eeg_data = data(:, 1);
            t = (0:length(eeg_data)-1) / Fs;
            
            % 对每个特征计算该文件的特征值
            for feat_idx = 1:n_features
                feat_name = feature_names{feat_idx};
                safe_name = matlab.lang.makeValidName(feat_name);
                
                % 初始化该文件的特征值存储
                resting_values = [];
                attention_values = [];
                
                % 处理两个时间段
                for phase_idx = 1:2
                    phase_name_var = time_periods.var_names{phase_idx};
                    current_time_range = time_periods.ranges{phase_idx};
                    
                    if strcmp(phase_name_var, 'Attention')
                        end_time = t(end);
                        current_time_range = [current_time_range(1), end_time];
                    end
                    
                    % 提取时间段数据
                    if isinf(current_time_range(2))
                        phase_idx_global = find(t >= current_time_range(1));
                    else
                        phase_idx_global = find(t >= current_time_range(1) & t < current_time_range(2));
                    end
                    
                    if isempty(phase_idx_global)
                        continue;
                    end
                    
                    window_samples = round(window_length * Fs);
                    step_samples = round(step_size * Fs);
                    n_windows = floor((length(phase_idx_global) - window_samples) / step_samples) + 1;
                    
                    phase_features = [];
                    
                    % 计算该时间段的所有特征值
                    for win = 1:n_windows
                        start_idx = phase_idx_global(1) + (win-1)*step_samples;
                        end_idx = start_idx + window_samples - 1;
                        
                        if end_idx > length(eeg_data)
                            continue;
                        end
                        
                        segment = eeg_data(start_idx:end_idx);
                        
                        try
                            switch feat_name
                                case 'SampEn'
                                    result = SampEn(segment);
                                    feature_val = result(3);
                                case 'XSampEn'
                                    mid_point = floor(length(segment) / 2);
                                    if mid_point > 10
                                        sig1 = segment(1:mid_point);
                                        sig2 = segment(mid_point+1:end);
                                        result = XSampEn(sig1, sig2);
                                        feature_val = result(3);
                                    else
                                        feature_val = NaN;
                                    end
                                case 'cXMSE'
                                    mid_point = floor(length(segment) / 2);
                                    if mid_point > 30
                                        sig1 = segment(1:mid_point);
                                        sig2 = segment(mid_point+1:end);
                                        Mobj = struct('Func', @XSampEn);
                                        [~, CI] = cXMSEn(sig1, sig2, Mobj, 'Scales', 3);
                                        feature_val = CI;
                                    else
                                        feature_val = NaN;
                                    end
                                otherwise
                                    feature_val = NaN;
                            end
                            
                            if ~isnan(feature_val)
                                phase_features = [phase_features, feature_val];
                            end
                        catch
                            continue;
                        end
                    end
                    
                    % 计算该阶段的平均值
                    if ~isempty(phase_features)
                        phase_mean = mean(phase_features, 'omitnan');
                        if strcmp(phase_name_var, 'Resting')
                            resting_values = [resting_values, phase_mean];
                        else
                            attention_values = [attention_values, phase_mean];
                        end
                    end
                end
                
                % 保存该文件该特征的平均值
                if ~isempty(resting_values)
                    file_resting_means.(safe_name) = [file_resting_means.(safe_name), mean(resting_values)];
                else
                    file_resting_means.(safe_name) = [file_resting_means.(safe_name), NaN];
                end
                
                if ~isempty(attention_values)
                    file_attention_means.(safe_name) = [file_attention_means.(safe_name), mean(attention_values)];
                else
                    file_attention_means.(safe_name) = [file_attention_means.(safe_name), NaN];
                end
            end
        catch ME
            warning('处理受试者 %s 的文件 %s 时出错: %s', subj_name, file_name, ME.message);
            for feat_idx = 1:n_features
                safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
                file_resting_means.(safe_name) = [file_resting_means.(safe_name), NaN];
                file_attention_means.(safe_name) = [file_attention_means.(safe_name), NaN];
            end
        end
    end
    
    % 按日期排序
    if ~isempty(file_dates)
        [sorted_dates, sort_idx] = sort(file_dates);
        sorted_file_names = file_names_list(sort_idx);
        
        % 生成日期字符串用于显示 (MMDD格式)
        date_str_display = cell(length(sorted_dates), 1);
        for date_idx = 1:length(sorted_dates)
            if sorted_dates(date_idx) > 1000 % 说明是MMDD格式的数值
                mm = floor(sorted_dates(date_idx) / 100);
                dd = mod(sorted_dates(date_idx), 100);
                date_str_display{date_idx} = sprintf('%02d月%02d日', mm, dd);
            else
                date_str_display{date_idx} = datestr(sorted_dates(date_idx), 'yyyy-mm-dd');
            end
        end
        date_str_display = char(date_str_display);
        
        % 生成变化趋势数据文件
        individual_stats_file = fullfile(individual_trend_folder, [subj_name '_特征变化趋势.txt']);
        fid = fopen(individual_stats_file, 'w');
        
        fprintf(fid, '========== 受试者 %s 特征随日期变化统计 ==========\n', subj_name);
        fprintf(fid, '生成时间: %s\n\n', datestr(now));
        fprintf(fid, '%-20s %-20s', '日期', '数据文件');
        for feat_idx = 1:n_features
            fprintf(fid, ' %15s_静息 %15s_注意', feature_names{feat_idx}, feature_names{feat_idx});
        end
        fprintf(fid, '\n%s\n', repmat('-', 1, 150));
        
        % 输出每个数据点
        for data_idx = 1:length(sort_idx)
            original_idx = sort_idx(data_idx);
            fprintf(fid, '%-20s %-20s', date_str_display(data_idx,:), sorted_file_names{data_idx});
            
            for feat_idx = 1:n_features
                safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
                rest_val = file_resting_means.(safe_name)(original_idx);
                att_val = file_attention_means.(safe_name)(original_idx);
                
                if isnan(rest_val)
                    fprintf(fid, ' %15s %15s', 'N/A', 'N/A');
                else
                    fprintf(fid, ' %15.6f %15.6f', rest_val, att_val);
                end
            end
            fprintf(fid, '\n');
        end
        
        fclose(fid);
        fprintf('  已生成变化趋势数据文件: %s\n', individual_stats_file);
        
        % 绘制变化趋势图
        fig = figure('Units', 'normalized', 'Position', [0.05, 0.05, 0.9, 0.85], ...
                     'Name', ['变化趋势 - ' subj_name], 'Visible', 'off');
        
        n_cols_trend = min(n_features, 2);
        n_rows_trend = ceil(n_features / n_cols_trend);
        
        for feat_idx = 1:n_features
            safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
            display_name = feature_names{feat_idx};
            
            subplot(n_rows_trend, n_cols_trend, feat_idx);
            
            % 获取排序后的数据
            resting_vals = file_resting_means.(safe_name)(sort_idx);
            attention_vals = file_attention_means.(safe_name)(sort_idx);
            x_axis = 1:length(sort_idx);
            
            % 移除NaN值用于绘图
            valid_rest = ~isnan(resting_vals);
            valid_att = ~isnan(attention_vals);
            
            hold on;
            if any(valid_rest)
                plot(x_axis(valid_rest), resting_vals(valid_rest), 'b-o', 'LineWidth', 2, 'MarkerSize', 8, ...
                     'DisplayName', '静息');
            end
            if any(valid_att)
                plot(x_axis(valid_att), attention_vals(valid_att), 'r-s', 'LineWidth', 2, 'MarkerSize', 8, ...
                     'DisplayName', '注意力');
            end
            hold off;
            
            xlabel('测试序号', 'FontSize', 11);
            ylabel(['特征值'], 'FontSize', 11);
            title(['特征: ' display_name], 'FontSize', 12, 'FontWeight', 'bold');
            legend('Location', 'best');
            grid on;
            
            % 设置x轴标签为日期
            xticks(x_axis);
            xticklabels(date_str_display);
            xtickangle(45);
        end
        
        sgtitle(['个体特征变化趋势: ' strrep(subj_name, '_', '\_')], ...
                'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'tex');
        
        % 保存变化趋势图
        trend_fig_path = fullfile(individual_trend_folder, ['变化趋势_' subj_name '.png']);
        saveas(fig, trend_fig_path);
        close(fig);
        
        fprintf('  已生成变化趋势图: %s\n', trend_fig_path);
    end
end

fprintf('\n--- 个体特征变化趋势分析完成 ---\n');
fprintf('所有结果已保存到: %s\n', individual_trend_folder);

%% ========== 5. 绘制每个受试者的特征箱线图和均值对比图 ==========
fprintf('\n========== 开始绘制受试者特征对比图 ==========\n');

% 为每个受试者绘制特征对比图
for subj_plot_idx = 1:total_valid_subjects
    subj_name = valid_subject_names{subj_plot_idx};
    fprintf('  绘制受试者 %d/%d: %s\n', subj_plot_idx, total_valid_subjects, subj_name);
    
    % 为该受试者绘制所有特征的对比图
    fig = figure('Units', 'normalized', 'Position', [0.05, 0.05, 0.9, 0.8], ...
                 'Name', ['受试者特征对比 - ' subj_name], ...
                 'Visible', 'off');
    
    % 计算子图布局
    n_cols = min(n_features, 3);
    n_rows = ceil(n_features / n_cols);
    
    % 获取该受试者在有效受试者列表中的索引
    valid_idx_list = find(valid_indices);
    original_subj_idx = valid_idx_list(subj_plot_idx);
    
    for feat_idx = 1:n_features
        safe_name = matlab.lang.makeValidName(feature_names{feat_idx});
        display_name = subject_data.(safe_name).display_name;
        
        % 获取该受试者该特征的所有值
        rest_values = subject_data.(safe_name).resting_all_values{original_subj_idx};
        att_values = subject_data.(safe_name).attention_all_values{original_subj_idx};
        
        if isempty(rest_values) || isempty(att_values)
            continue;
        end
        
        % 创建子图
        subplot(n_rows, n_cols, feat_idx);
        hold on;
        
        % 绘制箱线图
        data_combined = [rest_values(:); att_values(:)];
        groups = [ones(length(rest_values), 1); 2*ones(length(att_values), 1)];
        boxplot(data_combined, groups, 'Labels', {'静息', '注意力'}, ...
                'Colors', [0, 0.4470, 0.7410; 0.8500, 0.3250, 0.0980]);
        
        % 添加均值点
        mean_rest = mean(rest_values, 'omitnan');
        mean_att = mean(att_values, 'omitnan');
        plot(1, mean_rest, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 2);
        plot(2, mean_att, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 2);
        
        % 标题和标签
        title(strrep(display_name, '_', '\_'), 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');
        ylabel('特征值', 'FontSize', 10);
        grid on;
        
        % 添加均值文本
        text(1, mean_rest, sprintf('%.3f', mean_rest), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 9);
        text(2, mean_att, sprintf('%.3f', mean_att), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 9);
        
        hold off;
    end
    
    % 添加总标题
    sgtitle(['受试者: ' strrep(subj_name, '_', '\_')], 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'tex');
    
    % 保存图片
    output_path = fullfile(figure_output_folder, ['箱线图_' subj_name '.png']);
    saveas(fig, output_path);
    close(fig);
end

fprintf('所有受试者特征对比图已保存到: %s\n', figure_output_folder);
fprintf('--- 绘图完成 (共 %d 个受试者) ---\n', total_valid_subjects);

%% ========== 辅助函数 ==========

function interpretation = interpret_cohens_d(d)
    % 解释Cohen's d的大小（效应量）
    % 输入：
    %   d - Cohen's d值
    % 输出：
    %   interpretation - 效应大小的文字描述
    
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
    % 根据p值返回显著性星号标记
    % 输入：
    %   p - p值
    % 输出：
    %   star - 显著性标记字符串
    
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

function date_val = extract_date_from_filename(filename)
    % 从文件名中提取日期
    % 文件名前四位数字为MMDD格式（月日）
    % 例如：1201表示12月01日，0101表示1月01日
    % 为了正确排序（12月在前，1月在后），对1-6月的日期加上1300
    
    date_val = [];
    
    % 移除文件扩展名
    [~, name, ~] = fileparts(filename);
    
    % 提取文件名前四位数字
    pattern = '^\d{4}';
    tokens = regexp(name, pattern, 'match');
    
    if ~isempty(tokens)
        try
            mmdd_str = tokens{1};
            mmdd_val = str2double(mmdd_str);
            
            % 提取月份和日期
            mm = floor(mmdd_val / 100);
            dd = mod(mmdd_val, 100);
            
            % 验证月份和日期的有效性
            if mm >= 1 && mm <= 12 && dd >= 1 && dd <= 31
                % 为了正确排序：12月在前，1月在后
                % 将1-6月的值加上1300，使其排在12月之后
                if mm >= 1 && mm <= 6
                    date_val = mmdd_val + 1300; % 例如0101变成1401
                else
                    date_val = mmdd_val; % 7-12月保持原值
                end
                return;
            end
        catch
        end
    end
    
    % 如果提取失败，返回空值
end