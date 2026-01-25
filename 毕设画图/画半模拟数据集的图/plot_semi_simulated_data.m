%% 绘制半模拟数据集脚本
% 用途：绘制纯净脑电、眼电信号以及不同信噪比合成的数据
% 参考 plot_artifacts.m 的风格

clear; close all; clc;

%% 配置参数
data_folder = fileparts(mfilename('fullpath')); % 当前脚本所在文件夹
fs = 250; % 采样率 (Hz)

%% 1. 绘制纯净信号 (Pure_Data, HEOG, VEOG)
fprintf('========== 绘制纯净信号 ==========\n');

pure_files = {
    'Pure_Data.mat', '纯净脑电信号 (Pure EEG)';
    'HEOG.mat', '纯净水平眼电 (Pure HEOG)';
    'VEOG.mat', '纯净垂直眼电 (Pure VEOG)'
};

for i = 1:size(pure_files, 1)
    filename = pure_files{i, 1};
    title_str = pure_files{i, 2};
    mat_path = fullfile(data_folder, filename);
    
    if ~exist(mat_path, 'file')
        warning('未找到文件: %s', mat_path);
        continue;
    end
    
    fprintf('正在处理: %s ...\n', filename);
    
    % 加载数据
    data_struct = load(mat_path);
    if isfield(data_struct, 'seg')
        signal = data_struct.seg;
    else
        % 尝试获取第一个变量
        vars = fieldnames(data_struct);
        signal = data_struct.(vars{1});
    end
    
    % 如果是多维数据，取第一个样本
    if size(signal, 1) > 1 && size(signal, 2) > 1
        signal = signal(1, :); % 取第一行
    end
    
    % 确保是列向量
    signal = signal(:);
    
    % 构建时间轴
    N = length(signal);
    t = (0:N-1) / fs;
    
    % 绘图 - 创建新的独立图形窗口
    figure('Position', [100, 100, 1000, 600], 'Color', 'white', 'Name', title_str);
    
    % 先plot
    plot(t, signal, 'b', 'LineWidth', 2.5);
    
    % 后设置坐标轴属性 (确保FontSize不被重置)
    set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
    
    % 设置标签 (使用大字体)
    xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 28, 'FontWeight', 'bold');
    
    % 限制范围
    xlim([0, max(t)]);
    ylim([-50, 100]); % 固定纵坐标范围
    grid on;
    
    fprintf('  已生成独立图形.\n');
end

%% 2. 绘制纯净测试信号 (Test_Pure_SNR*)
fprintf('\n========== 绘制纯净测试信号 (不同SNR) ==========\n');

pure_test_files = {
    'Test_Pure_SNR4dB.mat', '纯净信号 SNR=4dB';
};

for i = 1:size(pure_test_files, 1)
    filename = pure_test_files{i, 1};
    title_str = pure_test_files{i, 2};
    mat_path = fullfile(data_folder, filename);
    
    if ~exist(mat_path, 'file')
        warning('未找到文件: %s', mat_path);
        continue;
    end
    
    fprintf('正在处理: %s ...\n', filename);
    
    % 加载数据
    data_struct = load(mat_path);
    if isfield(data_struct, 'seg')
        signal = data_struct.seg;
    else
        % 尝试获取第一个变量
        vars = fieldnames(data_struct);
        signal = data_struct.(vars{1});
    end
    
    % 如果是多维数据，取第一个样本
    if size(signal, 1) > 1 && size(signal, 2) > 1
        signal = signal(1, :); % 取第一行
    end
    
    % 确保是列向量
    signal = signal(:);
    
    % 构建时间轴
    N = length(signal);
    t = (0:N-1) / fs;
    
    % 绘图 - 创建新的独立图形窗口
    figure('Position', [100, 100, 1000, 600], 'Color', 'white', 'Name', title_str);
    
    % 先plot
    plot(t, signal, 'b', 'LineWidth', 2.5);
    
    % 后设置坐标轴属性
    set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
    
    % 设置标签
    xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 28, 'FontWeight', 'bold');
    
    % 限制范围
    xlim([0, max(t)]);
    ylim([-50, 100]); % 固定纵坐标范围
    grid on;
    
    fprintf('  已生成独立图形.\n');
end

%% 3. 绘制污染测试信号 (Test_Contaminated_SNR*)
fprintf('\n========== 绘制污染测试信号 (不同SNR) ==========\n');

contaminated_test_files = {
    'Test_Contaminated_SNR-8dB.mat', '污染信号 SNR=-8dB';
    'Test_Contaminated_SNR-6dB.mat', '污染信号 SNR=-6dB';
    'Test_Contaminated_SNR-4dB.mat', '污染信号 SNR=-4dB';
    'Test_Contaminated_SNR-2dB.mat', '污染信号 SNR=-2dB';
    'Test_Contaminated_SNR0dB.mat', '污染信号 SNR=0dB';
    'Test_Contaminated_SNR2dB.mat', '污染信号 SNR=2dB';
    'Test_Contaminated_SNR4dB.mat', '污染信号 SNR=4dB';
};

for i = 1:size(contaminated_test_files, 1)
    filename = contaminated_test_files{i, 1};
    title_str = contaminated_test_files{i, 2};
    mat_path = fullfile(data_folder, filename);
    
    if ~exist(mat_path, 'file')
        warning('未找到文件: %s', mat_path);
        continue;
    end
    
    fprintf('正在处理: %s ...\n', filename);
    
    % 加载数据
    data_struct = load(mat_path);
    if isfield(data_struct, 'seg')
        signal = data_struct.seg;
    else
        % 尝试获取第一个变量
        vars = fieldnames(data_struct);
        signal = data_struct.(vars{1});
    end
    
    % 如果是多维数据，取第一个样本
    if size(signal, 1) > 1 && size(signal, 2) > 1
        signal = signal(1, :); % 取第一行
    end
    
    % 确保是列向量
    signal = signal(:);
    
    % 构建时间轴
    N = length(signal);
    t = (0:N-1) / fs;
    
    % 绘图 - 创建新的独立图形窗口
    figure('Position', [100, 100, 1000, 600], 'Color', 'white', 'Name', title_str);
    
    % 先plot
    plot(t, signal, 'b', 'LineWidth', 2.5);
    
    % 后设置坐标轴属性
    set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
    
    % 设置标签
    xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
    ylabel('Amplitude (μV)', 'FontSize', 28, 'FontWeight', 'bold');
    
    % 限制范围
    xlim([0, max(t)]);
    ylim([-50, 100]); % 固定纵坐标范围
    grid on;
    
    fprintf('  已生成独立图形.\n');
end

fprintf('\n========== 全部完成！==========\n');
