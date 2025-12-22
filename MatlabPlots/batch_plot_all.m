close all;
clear all;
% 批量处理所有绘图数据文件
% 自动查找并绘制所有由Python生成的*_original.mat和*_processed.mat文件

% 设置数据文件夹路径
data_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\figures';

% 如果数据文件夹不存在，提示用户
if ~exist(data_folder, 'dir')
    fprintf('警告: 数据文件夹不存在: %s\n', data_folder);
    fprintf('请先运行Python脚本 ProcessRestAttentionDataset.py 生成数据\n');
    fprintf('或修改脚本中的 data_folder 变量指向正确的路径\n');
    return;
end

% 切换到数据文件夹
cd(data_folder);

% 查找所有原始信号文件
original_files = dir('*_original.mat');

if isempty(original_files)
    fprintf('未找到原始信号数据文件！\n');
    fprintf('请先运行Python脚本 ProcessRestAttentionDataset.py 生成数据\n');
    return;
end

fprintf('找到 %d 个原始信号文件\n', length(original_files));

% 只处理前10个文件
num_to_process = min(10, length(original_files));
fprintf('只处理前 %d 个文件\n', num_to_process);
fprintf('开始批量生成图片...\n');
fprintf('=================================================================\n');

% 遍历文件
for i = 1:num_to_process
    original_name = original_files(i).name;
    % 构造对应的processed文件名
    processed_name = strrep(original_name, '_original.mat', '_processed.mat');
    
    % 检查processed文件是否存在
    if ~isfile(processed_name)
        fprintf('\n[%d/%d] 警告: 未找到对应的处理后文件: %s\n', i, num_to_process, processed_name);
        continue;
    end
    
    % 构造保存的图片名称
    save_name = strrep(original_name, '_original.mat', '_对比图');
    
    fprintf('\n[%d/%d] 处理: %s\n', i, num_to_process, original_name);
    fprintf('        对应: %s\n', processed_name);
    
    try
        % 调用绘图函数
        plot_signal_comparison(original_name, processed_name, save_name);
    catch ME
        fprintf('错误: %s\n', ME.message);
        continue;
    end
end

fprintf('\n=================================================================\n');
fprintf('批量处理完成！共处理 %d 个文件\n', num_to_process);
fprintf('图片保存在: %s\n', data_folder);
fprintf('=================================================================\n');

% 提示生成的文件格式
fprintf('\n生成的文件格式：\n');
fprintf('  - PNG: 高分辨率位图（300 DPI）\n');
fprintf('  - EPS: 矢量图（推荐用于学术论文）\n');
fprintf('  - PDF: 矢量图（通用格式）\n');
