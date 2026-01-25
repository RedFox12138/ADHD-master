%% 绘制真实的眼动伪影脚本
% 用途：绘制Brain (脑电)、EyeMove (眼动)、Wink (眨眼) 信号
% 模仿 plot_single_file.m 的大字体风格

clear; close all; clc;

%% 配置参数
data_folder = fileparts(mfilename('fullpath')); % 当前脚本所在文件夹
fs = 250; % 假设采样率为500Hz (根据项目常用设置)

% 定义要绘制的文件
files = {
    'Brain_1.mat', '脑电信号 (Brain)';
    'EyeMove_1.mat', '眼动信号 (EyeMove)';
    'Wink_1.mat', '眨眼信号 (Wink)'
};

%% 循环处理每个文件
for i = 1:size(files, 1)
    filename = files{i, 1};
    title_str = files{i, 2};
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
    
    % 确保是列向量
    signal = signal(:);
    
    %构建时间轴
    N = length(signal);
    t = (0:N-1) / fs;
    
    % 绘图
    figure('Position', [100, 100, 1000, 600], 'Color', 'none');
    
    % 先plot
    plot(t, signal, 'b', 'LineWidth', 2.5);
    
    % 限制范围 (必须在set之前设置)
    xlim([0, max(t)]);
    ylim([-50, 100]); % 固定纵坐标范围
    
    % 后设置坐标轴属性 (确保FontSize不被重置)
    set(gca, 'Color', 'none', 'FontSize', 28, 'LineWidth', 1.5);
    
    % 设置标签 (使用大字体)
    xlabel('Time (s)', 'FontSize', 28, 'FontWeight', 'bold');
    ylabel('Amplitude (mV)', 'FontSize', 28, 'FontWeight', 'bold');
    
    grid on;
    
    fprintf('  已生成图形.\n');
end

fprintf('全部完成！\n');
