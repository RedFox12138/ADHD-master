%% 按个体标识分类数据文件
% 功能：根据文件名中的个体标识，将mat文件复制到对应的子目录
% 适用场景：整理不同受试者的脑电数据
% 
% 使用方法：
%   1. 直接运行脚本，会弹出对话框选择源目录和目标目录
%   2. 或者修改下面的配置区直接指定路径
%
% 示例：
%   文件名包含 "XY" 的文件 → 复制到 目标目录/XY/ 文件夹
%   文件名包含 "CC" 的文件 → 复制到 目标目录/CC/ 文件夹

clc;
clear;
close all;

fprintf('========================================\n');
fprintf('按个体标识分类数据文件\n');
fprintf('========================================\n\n');

%% ========== 用户配置区 ==========

% 方式1: 手动指定路径
% source_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\预处理处理后的mat\6s';  % B目录：源文件所在位置
% target_folder = 'D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\总和\按个体分类';  % A目录：已有个体子目录的目标位置

% 方式2: 用户选择路径（推荐）
target_folder = uigetdir('D:\Pycharm_Projects\ADHD-master\data', '选择目标目录A（已包含个体子文件夹，如CC、YH、XY）');
if target_folder == 0
    error('用户取消了目标目录选择');
end

source_folder = uigetdir(target_folder, '选择源目录B（包含待分类的mat文件）');
if source_folder == 0
    error('用户取消了源目录选择');
end

% 个体标识列表将从目标目录的子文件夹自动读取
subject_ids = {};  % 将从A目录的子文件夹读取

% 文件扩展名
file_extension = '*.mat';

% 是否复制文件（false=移动文件）
copy_mode = true;  % true=复制, false=移动

% 是否显示详细日志
verbose = true;

%% 获取所有mat文件
fprintf('源目录: %s\n', source_folder);
fprintf('目标目录: %s\n', target_folder);
fprintf('模式: %s\n', ternary(copy_mode, '复制', '移动'));
fprintf('\n正在扫描文件...\n');

mat_files = dir(fullfile(source_folder, file_extension));
n_files = length(mat_files);

if n_files == 0
    error('源目录中未找到mat文件！');
end

fprintf('找到 %d 个mat文件\n\n', n_files);

%% 从目标目录读取个体子文件夹
fprintf('正在读取目标目录的个体子文件夹...\n');

% 获取目标目录下的所有子文件夹
dir_info = dir(target_folder);
subject_ids = {};

for i = 1:length(dir_info)
    if dir_info(i).isdir && ~strcmp(dir_info(i).name, '.') && ~strcmp(dir_info(i).name, '..')
        subject_ids{end+1} = dir_info(i).name;
    end
end

if isempty(subject_ids)
    error('目标目录中未找到任何子文件夹！请确保A目录包含个体子目录（如CC、YH、XY）');
end

fprintf('找到 %d 个个体子目录: %s\n', length(subject_ids), strjoin(subject_ids, ', '));

% 询问用户是否确认
response = input('是否使用这些子目录作为个体标识？(Y/n): ', 's');
if ~isempty(response) && ~strcmpi(response, 'y') && ~strcmpi(response, 'yes')
    error('用户取消了操作');
end
fprintf('\n');

%% 分类文件
fprintf('========== 开始分类文件 ==========\n\n');

% 统计信息
stats = struct();
for i = 1:length(subject_ids)
    stats.(subject_ids{i}) = 0;
end
stats.unmatched = 0;
unmatched_files = {};

% 处理每个文件
for i = 1:n_files
    filename = mat_files(i).name;
    source_path = fullfile(source_folder, filename);
    
    % 查找匹配的个体标识
    matched = false;
    for j = 1:length(subject_ids)
        subject_id = subject_ids{j};
        
        % 检查文件名是否包含该个体标识
        if contains(filename, subject_id, 'IgnoreCase', false)
            % 匹配成功
            target_path = fullfile(target_folder, subject_id, filename);
            
            % 复制或移动文件
            try
                if copy_mode
                    copyfile(source_path, target_path);
                    if verbose
                        fprintf('[%d/%d] 复制: %s → %s\n', i, n_files, filename, subject_id);
                    end
                else
                    movefile(source_path, target_path);
                    if verbose
                        fprintf('[%d/%d] 移动: %s → %s\n', i, n_files, filename, subject_id);
                    end
                end
                
                stats.(subject_id) = stats.(subject_id) + 1;
                matched = true;
                break;  % 找到匹配后退出循环
                
            catch ME
                warning('处理文件失败: %s\n错误: %s', filename, ME.message);
            end
        end
    end
    
    % 未匹配的文件
    if ~matched
        stats.unmatched = stats.unmatched + 1;
        unmatched_files{end+1} = filename;
        if verbose
            fprintf('[%d/%d] ⚠️  未匹配: %s\n', i, n_files, filename);
        end
    end
end

%% 显示统计结果
fprintf('\n========== 分类统计 ==========\n');
fprintf('%-15s %10s\n', '个体标识', '文件数');
fprintf('%s\n', repmat('-', 1, 30));

total_matched = 0;
for i = 1:length(subject_ids)
    subject_id = subject_ids{i};
    count = stats.(subject_id);
    total_matched = total_matched + count;
    fprintf('%-15s %10d\n', subject_id, count);
end

fprintf('%s\n', repmat('-', 1, 30));
fprintf('%-15s %10d\n', '已匹配总数', total_matched);
fprintf('%-15s %10d\n', '未匹配', stats.unmatched);
fprintf('%-15s %10d\n', '文件总数', n_files);

% 显示未匹配的文件
if stats.unmatched > 0
    fprintf('\n未匹配的文件列表:\n');
    for i = 1:length(unmatched_files)
        fprintf('  %d. %s\n', i, unmatched_files{i});
    end
    
    % 询问是否将未匹配文件复制到单独文件夹
    fprintf('\n');
    response = input('是否将未匹配文件复制到"未分类"文件夹？(y/N): ', 's');
    if strcmpi(response, 'y') || strcmpi(response, 'yes')
        unmatched_folder = fullfile(target_folder, '未分类');
        if ~exist(unmatched_folder, 'dir')
            mkdir(unmatched_folder);
        end
        
        for i = 1:length(unmatched_files)
            filename = unmatched_files{i};
            source_path = fullfile(source_folder, filename);
            target_path = fullfile(unmatched_folder, filename);
            
            try
                if copy_mode
                    copyfile(source_path, target_path);
                else
                    movefile(source_path, target_path);
                end
            catch ME
                warning('处理未匹配文件失败: %s', filename);
            end
        end
        fprintf('已将 %d 个未匹配文件移至"未分类"文件夹\n', length(unmatched_files));
    end
end

%% 完成
fprintf('\n========== 分类完成 ==========\n');
fprintf('源目录(B): %s\n', source_folder);
fprintf('目标目录(A): %s\n', target_folder);
fprintf('个体子目录数: %d\n', length(subject_ids));
fprintf('操作模式: %s\n', ternary(copy_mode, '复制', '移动'));
fprintf('处理文件数: %d\n', n_files);
fprintf('成功分类: %d\n', total_matched);
fprintf('未匹配: %d\n', stats.unmatched);
fprintf('==============================\n');

%% 辅助函数

function result = ternary(condition, true_val, false_val)
    % 三元运算符
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
