% --- WPE_IA_Composite特征提取与对比：批量处理文件 (V3.0) ---
% 该脚本用于批量处理指定文件夹中的所有txt文件，
% 提取静息和注意力阶段的WPE_IA_Composite特征。
% 前40s为静息阶段，40s后为注意力阶段。

clc;
clear all;
close all;

% --- 用户设定参数 ---
Fs = 250; % 采样率 (Hz)
window_length = 6; % 窗长 (秒)
step_size = 2; % 滑动步长 (秒)
perm_wt_val_w = 4; % WPE_IA_Composite 的加权排列熵指数
inv_alpha_val_w = 0.6; % WPE_IA_Composite 的Alpha倒数指数

% 定义两个核心时间段（静息和注意力）
time_periods.names = {'静息', '注意力'};
time_periods.ranges = {[10, 40], [40, Inf]}; % 前40s为静息，40s后为注意力
time_periods.var_names = {'Resting', 'Attention'};
time_periods.colors = {[0, 0.4470, 0.7410], [0.8500, 0.3250, 0.0980]}; % 蓝和橙

% --- 程序主逻辑 ---

% 1. 让用户选择包含txt文件的文件夹
folder_path = uigetdir('D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\微信小程序\TXT文件\预处理后的完整数据，未分段', '选择包含txt文件的文件夹');
if folder_path == 0
    error('用户取消了文件夹选择');
end

% 2. 获取文件夹中的所有txt文件
file_list = dir(fullfile(folder_path, '*.txt'));
if isempty(file_list)
    error('在指定的文件夹中未找到任何 .txt 文件。');
end

% 3. 初始化用于存储结果的数组（3个特征）
num_files = length(file_list);

% WPE_IA_Composite
resting_means_wpe_ia = zeros(num_files, 1);
attention_means_wpe_ia = zeros(num_files, 1);
resting_time_series_wpe_ia = cell(num_files, 1);
attention_time_series_wpe_ia = cell(num_files, 1);

% SampEn
resting_means_sampen = zeros(num_files, 1);
attention_means_sampen = zeros(num_files, 1);
resting_time_series_sampen = cell(num_files, 1);
attention_time_series_sampen = cell(num_files, 1);

% PermEn_Weighted
resting_means_permen = zeros(num_files, 1);
attention_means_permen = zeros(num_files, 1);
resting_time_series_permen = cell(num_files, 1);
attention_time_series_permen = cell(num_files, 1);

% 时间点（共用）
resting_time_points = cell(num_files, 1);
attention_time_points = cell(num_files, 1);

% 添加feature目录到路径
feature_path = fullfile(fileparts(mfilename('fullpath')), 'feature');
if exist(feature_path, 'dir')
    addpath(feature_path);
end

% 4. 串行处理每个文件（避免并行问题）
fprintf('--- 开始处理文件夹中的所有文件 ---\n');

for i = 1:num_files
    file_name = file_list(i).name;
    full_file_path = fullfile(folder_path, file_name);

    fprintf('\n正在处理文件 %d/%d: %s\n', i, num_files, file_name);

    try
        % a. 加载数据
        data = importdata(full_file_path);
        eeg_data = data(:, 1);
        t = (0:length(eeg_data)-1) / Fs;
        
        fprintf('  信号长度: %.2f 秒\n', t(end));

        % b. 初始化单个文件的结果存储
        file_results = struct();

        % c. 对静息和注意力两个阶段进行WPE_IA_Composite计算
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
                warning('文件 %s 中未找到时间段 %s 的数据。', file_name, time_periods.names{j});
                file_results.(phase_name_var).features = [];
                file_results.(phase_name_var).time_points = [];
                continue;
            end
            
            % 转换为样本点数
            window_samples = round(window_length * Fs);
            step_samples = round(step_size * Fs);

            % 计算滑动窗口数量
            n_windows = floor((length(phase_idx_global) - window_samples) / step_samples) + 1;
            
            % 预分配数组（3个特征）
            features_wpe_ia = zeros(1, n_windows);
            features_sampen = zeros(1, n_windows);
            features_permen = zeros(1, n_windows);
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
                    % 计算 WPE_IA_Composite 特征
                    perm_wt_val = getPermEn(segment, 'variant', 'weighted');
                    inv_alpha_val = calculateInverseAlpha(segment, Fs);
                    wpe_ia_composite = (perm_wt_val^perm_wt_val_w) * (inv_alpha_val^inv_alpha_val_w);
                    features_wpe_ia(win) = wpe_ia_composite;
                    
                    % 计算 PermEn_Weighted 特征
                    features_permen(win) = perm_wt_val;
                    
                    % 计算 SampEn 特征
                    sampen_result = SampEn(segment);
                    features_sampen(win) = sampen_result(3); % 取第3个值
                catch
                    features_wpe_ia(win) = NaN;
                    features_sampen(win) = NaN;
                    features_permen(win) = NaN;
                end
                
                % 计算窗口中心时间
                center_time = t(start_idx) + window_length/2;
                time_points(win) = center_time;
            end
            
            % 保存结果，移除NaN值
            valid_idx_wpe_ia = ~isnan(features_wpe_ia);
            valid_idx_sampen = ~isnan(features_sampen);
            valid_idx_permen = ~isnan(features_permen);
            
            file_results.(phase_name_var).wpe_ia = features_wpe_ia(valid_idx_wpe_ia);
            file_results.(phase_name_var).sampen = features_sampen(valid_idx_sampen);
            file_results.(phase_name_var).permen = features_permen(valid_idx_permen);
            file_results.(phase_name_var).time_points = time_points(valid_idx_wpe_ia); % Time points are the same
        end

        % d. 从 file_results 中提取当前文件的所有特征值
        current_resting_wpe_ia = file_results.Resting.wpe_ia;
        current_attention_wpe_ia = file_results.Attention.wpe_ia;
        current_resting_sampen = file_results.Resting.sampen;
        current_attention_sampen = file_results.Attention.sampen;
        current_resting_permen = file_results.Resting.permen;
        current_attention_permen = file_results.Attention.permen;

        % 保存 WPE_IA_Composite
        if ~isempty(current_resting_wpe_ia)
            resting_means_wpe_ia(i) = mean(current_resting_wpe_ia, 'omitnan');
            resting_time_series_wpe_ia{i} = current_resting_wpe_ia;
            resting_time_points{i} = file_results.Resting.time_points;
        else
            resting_means_wpe_ia(i) = NaN;
            resting_time_series_wpe_ia{i} = [];
            resting_time_points{i} = [];
        end
        
        if ~isempty(current_attention_wpe_ia)
            attention_means_wpe_ia(i) = mean(current_attention_wpe_ia, 'omitnan');
            attention_time_series_wpe_ia{i} = current_attention_wpe_ia;
            attention_time_points{i} = file_results.Attention.time_points;
        else
            attention_means_wpe_ia(i) = NaN;
            attention_time_series_wpe_ia{i} = [];
            attention_time_points{i} = [];
        end
        
        % 保存 SampEn
        if ~isempty(current_resting_sampen)
            resting_means_sampen(i) = mean(current_resting_sampen, 'omitnan');
            resting_time_series_sampen{i} = current_resting_sampen;
        else
            resting_means_sampen(i) = NaN;
            resting_time_series_sampen{i} = [];
        end
        
        if ~isempty(current_attention_sampen)
            attention_means_sampen(i) = mean(current_attention_sampen, 'omitnan');
            attention_time_series_sampen{i} = current_attention_sampen;
        else
            attention_means_sampen(i) = NaN;
            attention_time_series_sampen{i} = [];
        end
        
        % 保存 PermEn_Weighted
        if ~isempty(current_resting_permen)
            resting_means_permen(i) = mean(current_resting_permen, 'omitnan');
            resting_time_series_permen{i} = current_resting_permen;
        else
            resting_means_permen(i) = NaN;
            resting_time_series_permen{i} = [];
        end
        
        if ~isempty(current_attention_permen)
            attention_means_permen(i) = mean(current_attention_permen, 'omitnan');
            attention_time_series_permen{i} = current_attention_permen;
        else
            attention_means_permen(i) = NaN;
            attention_time_series_permen{i} = [];
        end

    catch ME
        warning('处理文件 %s 时发生错误: %s', file_name, ME.message);
        % 标记为NaN，以便后续统计排除
        resting_means_wpe_ia(i) = NaN;
        attention_means_wpe_ia(i) = NaN;
        resting_means_sampen(i) = NaN;
        attention_means_sampen(i) = NaN;
        resting_means_permen(i) = NaN;
        attention_means_permen(i) = NaN;
        resting_time_series_wpe_ia{i} = [];
        attention_time_series_wpe_ia{i} = [];
        resting_time_series_sampen{i} = [];
        attention_time_series_sampen{i} = [];
        resting_time_series_permen{i} = [];
        attention_time_series_permen{i} = [];
    end
end

% 定义有效索引：同时具有静息和注意力阶段有效数据的文件
valid_indices = ~isnan(resting_means_wpe_ia) & ~isnan(attention_means_wpe_ia);

% 筛选有效的时序数据
valid_resting_time_series_wpe_ia = resting_time_series_wpe_ia(valid_indices);
valid_attention_time_series_wpe_ia = attention_time_series_wpe_ia(valid_indices);
valid_resting_time_series_sampen = resting_time_series_sampen(valid_indices);
valid_attention_time_series_sampen = attention_time_series_sampen(valid_indices);
valid_resting_time_series_permen = resting_time_series_permen(valid_indices);
valid_attention_time_series_permen = attention_time_series_permen(valid_indices);
valid_resting_time_points = resting_time_points(valid_indices);
valid_attention_time_points = attention_time_points(valid_indices);

total_valid_files = sum(valid_indices);
if total_valid_files == 0
    disp('没有成功处理的文件，无法进行最终统计。');
    return;
end

% 计算统计结果
valid_resting_means_wpe_ia = resting_means_wpe_ia(valid_indices);
valid_attention_means_wpe_ia = attention_means_wpe_ia(valid_indices);
valid_resting_means_sampen = resting_means_sampen(valid_indices);
valid_attention_means_sampen = attention_means_sampen(valid_indices);
valid_resting_means_permen = resting_means_permen(valid_indices);
valid_attention_means_permen = attention_means_permen(valid_indices);

mean_greater_count_wpe_ia = sum(valid_resting_means_wpe_ia > valid_attention_means_wpe_ia);
mean_greater_count_sampen = sum(valid_resting_means_sampen > valid_attention_means_sampen);
mean_greater_count_permen = sum(valid_resting_means_permen > valid_attention_means_permen);

% 打印最终结果
fprintf('\n--- 最终统计结果 (基于 %d 个成功处理的文件) ---\n', total_valid_files);
fprintf('WPE_IA_Composite: 静息均值 > 注意力均值的比例: %.2f%%\n', mean_greater_count_wpe_ia / total_valid_files * 100);
fprintf('SampEn: 静息均值 > 注意力均值的比例: %.2f%%\n', mean_greater_count_sampen / total_valid_files * 100);
fprintf('PermEn_Weighted: 静息均值 > 注意力均值的比例: %.2f%%\n', mean_greater_count_permen / total_valid_files * 100);

fprintf('\n--- 所有文件处理完毕 ---\n');

% --- 5. 绘制所有有效文件的特征时序图（3个特征） ---
fprintf('\n--- 开始绘制特征时序图 ---\n');

% 创建输出文件夹用于保存图片
output_folder = fullfile(folder_path, '特征时序图');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% 定义特征信息
feature_info = struct();
feature_info(1).name = 'WPE_IA_Composite';
feature_info(1).rest_data = valid_resting_time_series_wpe_ia;
feature_info(1).att_data = valid_attention_time_series_wpe_ia;

feature_info(2).name = 'SampEn';
feature_info(2).rest_data = valid_resting_time_series_sampen;
feature_info(2).att_data = valid_attention_time_series_sampen;

feature_info(3).name = 'PermEn_Weighted';
feature_info(3).rest_data = valid_resting_time_series_permen;
feature_info(3).att_data = valid_attention_time_series_permen;

% 为每个文件和每个特征单独绘图
for i = 1:total_valid_files
    % 获取原始文件索引和文件名
    valid_idx_list = find(valid_indices);
    original_idx = valid_idx_list(i);
    file_name = file_list(original_idx).name;
    [~, file_name_only] = fileparts(file_name);
    
    fprintf('  绘制 [%d/%d]: %s\n', i, total_valid_files, file_name);
    
    % 为每个特征绘制一张子图
    for feat_idx = 1:3
        feat = feature_info(feat_idx);
        
        if isempty(feat.rest_data{i}) || isempty(feat.att_data{i})
            continue;
        end
        
        % 创建新图形
        fig = figure('Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.6], ...
                     'Name', [feat.name ' - ' file_name_only], ...
                     'Visible', 'off');
        hold on;
        
        % 计算当前文件的均值
        mean_resting = mean(feat.rest_data{i}, 'omitnan');
        mean_attention = mean(feat.att_data{i}, 'omitnan');
        
        % 收集当前文件的所有数据点
        all_features = [feat.rest_data{i}, feat.att_data{i}];
        all_times = [valid_resting_time_points{i}, valid_attention_time_points{i}];
        
        % 获取Y轴范围
        yl = [min(all_features)*0.95, max(all_features)*1.05];
        if yl(1) == yl(2)
            yl = [yl(1)-0.1, yl(2)+0.1];
        end
        ylim(yl);
        
        % 添加背景色块区分时间段
        patch([0, 40, 40, 0], [yl(1), yl(1), yl(2), yl(2)], ...
              time_periods.colors{1}, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        patch([40, max(all_times)+5, max(all_times)+5, 40], [yl(1), yl(1), yl(2), yl(2)], ...
              time_periods.colors{2}, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        % 添加阶段分隔线
        line([40, 40], yl, 'Color', 'k', 'LineWidth', 2, 'LineStyle', ':', 'HandleVisibility', 'off');
        
        % 绘制静息阶段数据点和线条
        plot(valid_resting_time_points{i}, feat.rest_data{i}, ...
             '-o', 'Color', [0, 0.4470, 0.7410], 'LineWidth', 2, ...
             'MarkerFaceColor', [0, 0.4470, 0.7410], 'MarkerSize', 6, ...
             'DisplayName', '静息阶段');
        
        % 绘制静息阶段均值线
        line([0, 40], [mean_resting, mean_resting], ...
             'Color', [0, 0.4470, 0.7410], 'LineStyle', '--', 'LineWidth', 3, ...
             'DisplayName', sprintf('静息均值 = %.4f', mean_resting));
        
        % 绘制注意力阶段数据点和线条
        plot(valid_attention_time_points{i}, feat.att_data{i}, ...
             '-o', 'Color', [0.8500, 0.3250, 0.0980], 'LineWidth', 2, ...
             'MarkerFaceColor', [0.8500, 0.3250, 0.0980], 'MarkerSize', 6, ...
             'DisplayName', '注意力阶段');
        
        % 绘制注意力阶段均值线
        line([40, max(all_times)+5], [mean_attention, mean_attention], ...
             'Color', [0.8500, 0.3250, 0.0980], 'LineStyle', '--', 'LineWidth', 3, ...
             'DisplayName', sprintf('注意力均值 = %.4f', mean_attention));
        
        % 添加阶段标注
        text(20, yl(2)*0.95, '静息阶段 (0-40s)', ...
             'FontSize', 12, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
             'BackgroundColor', 'w', 'EdgeColor', 'k');
        text(40 + (max(all_times)-40)/2, yl(2)*0.95, '注意力阶段 (40s-)', ...
             'FontSize', 12, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
             'BackgroundColor', 'w', 'EdgeColor', 'k');
        
        % 添加标签和标题
        xlabel('时间 (秒)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel([strrep(feat.name, '_', '\_') ' 特征值'], 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');
        title([strrep(feat.name, '_', '\_') ' - ' strrep(file_name_only, '_', '\_')], ...
              'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'tex');
        grid on;
        box on;
        
        % 设置坐标轴范围
        xlim([0, max(all_times)+5]);
        
        % 添加图例
        lgd = legend('show', 'Location', 'best', 'FontSize', 10);
        lgd.Box = 'on';
        
        hold off;
        
        % 保存图片
        output_path = fullfile(output_folder, [file_name_only '_' feat.name '.png']);
        saveas(fig, output_path);
        close(fig);
    end
end

fprintf('所有时序图已保存到: %s\n', output_folder);
fprintf('--- 绘图完成 (共 %d 个样本 × 3 个特征 = %d 张图) ---\n', total_valid_files, total_valid_files * 3);