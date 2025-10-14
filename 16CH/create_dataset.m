%% EEGLAB单文件预处理脚本 (适配TXT文件)
% 此版本专门用于加载和处理 Channel x Time 的 .txt 数据文件
% --- 新增功能：手动选择ICA成分 + 绘制每一步的波形对比图 ---

clear; close all; clc;
eeglab nogui;

%% ==================== 参数配置 (请在此处修改) ====================
% --- 输入与输出 ---
inputFile = 'Data\0821\0821 XY实验1.txt'; % <--- 修改为您TXT文件的完整路径
outputPath = 'Preprocessed\0821\'; % 输出路径
cedFile = 'standard128-10-20.ced'; % 电极位置文件

% --- 数据参数 ---
% channelNames = {'Pz', 'O1', 'Oz', 'O2'};
channelNames = {'F7', 'Fp1', 'Fp2', 'F8', 'F3', 'F1', 'F2','F4','C1','Cz','C2','Cpz'};
% 'C1', 'Cz', 'C2', 'Cpz'};
srate = 250;

% --- 预处理参数 ---
notchRange = [47.5 52.5];
bandpassRange = [0.1 60];
icaBrainThreshold = 0.7;
icaArtifactThreshold = 0.3;

%% ==================== 处理流程开始 ====================

% --- 新增：初始化用于存储中间结果的变量 ---
EEG_raw = [];
EEG_bandpassed = [];
EEG_notched = [];
EEG_rereferenced = [];
EEG_ica_cleaned = [];

% 创建输出目录
if ~exist(outputPath, 'dir')
mkdir(outputPath);
end

% 从完整路径中获取文件名
[~, inputFileName, ~] = fileparts(inputFile);

try
%% 1. 加载TXT数据
fprintf('\n开始处理文件: %s.txt\n', inputFileName);
fprintf('正在从TXT文件加载数据...\n');
eegData = readmatrix(inputFile);
if size(eegData, 1) > size(eegData, 2)
fprintf('数据维度为 %d x %d (采样点数 x 通道数)，正在进行转置...\n', size(eegData,1), size(eegData,2));
eegData = eegData';
end
eegData = eegData(1:12,:);

save('eeglabTest', 'eegData');

if size(eegData, 1) ~= length(channelNames)
error('数据中的通道数 (%d) 与 channelNames 列表中的数量 (%d) 不匹配！', ...
size(eegData, 1), length(channelNames));
end
fprintf('数据加载成功，维度: %d 通道 × %d 采样点。\n', size(eegData,1), size(eegData,2));

%% 2. 创建EEG结构并加载电极位置
EEG = pop_importdata('dataformat', 'array', 'data', eegData, 'srate', srate);
for ch = 1:EEG.nbchan
EEG.chanlocs(ch).labels = channelNames{ch};
end
EEG = pop_chanedit(EEG, 'lookup', cedFile);
fprintf('通道位置加载成功。\n');
% --- 新增：保存原始数据状态 ---
 rawData = EEG.data;
    Fs = EEG.srate;
    
    % 预先分配一个矩阵来存储处理后的数据，以提高效率
    processedData = zeros(size(rawData)-30);
    
    % 循环遍历每一个通道
    for ch = 1:EEG.nbchan
        fprintf('  - 正在处理通道 %d / %d\n', ch, EEG.nbchan);
        singleChannelData = rawData(ch, :);
        
        % 调用您的函数。我们使用 "none" 方法，因为它执行滤波并返回结果
        % 您的函数有两个输出 [d1, out]，根据您的代码，out是最终结果
        [~, processedChannel] = EEGPreprocess(singleChannelData, Fs, "none");
        
        % 检查输出是否为空，如果为空则表示该通道被剔除
        if isempty(processedChannel)
            fprintf('    警告: 通道 %d 的输出为空，可能已被函数剔除。将以0填充。\n', ch);
            processedData(ch, :) = zeros(1, EEG.pnts);
        else
            processedData(ch, :) = processedChannel;
        end
    end
    
    % 将所有通道处理完毕的数据，更新回EEG结构体
    EEG.data = processedData;
    
    % --- 保存滤波后状态 ---
    % 我们将您的函数处理结果保存在 EEG_bandpassed 中用于后续绘图
    EEG_bandpassed = EEG;
    % 陷波滤波在您的函数中已经完成，为了让后续绘图代码正常工作，我们复制一份结果
    EEG_notched = EEG;
    %全脑平均重参考
%     EEG = pop_reref(EEG, []);
%     EEG = pop_chanedit(EEG, 'lookup', cedFile);
%     % --- 新增：保存重参考后状态 ---
%     EEG_rereferenced = EEG;

%% 4. 独立成分分析 (ICA)
fprintf('正在运行ICA...\n');
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'interrupt', 'on');

% ===== 关键修复：计算ICA激活成分 =====
EEG.icaact = (EEG.icaweights * EEG.icasphere) * EEG.data(EEG.icachansind,:);

fprintf('正在使用ICLabel对成分进行分类...\n');
EEG = iclabel(EEG);

% ===== 绘制ICA分量波形图 =====
fprintf('正在绘制ICA分量波形图...\n');
icaFig = figure('Name', ['ICA Components Time Courses: ', inputFileName], 'Position', [50 50 1200 800], 'Color', 'w');

n_components = size(EEG.icaweights,1);
time_points = 1:min(100*srate, EEG.pnts); % 只显示前5秒数据
time_sec = EEG.times(time_points)/1000; % 转换为秒

% 确保icaact不为空
if isempty(EEG.icaact)
error('ICA激活成分计算失败！请检查数据或EEGLAB版本');
end

for ic = 1:n_components
subplot(n_components, 1, ic);
plot(time_sec, EEG.icaact(ic, time_points), 'b');
% 获取分类信息
[maxProb, maxIdx] = max(EEG.etc.ic_classification.ICLabel.classifications(ic,:));
componentType = EEG.etc.ic_classification.ICLabel.classes{maxIdx};
title(sprintf('IC %d: %s (%.1f%%)', ic, componentType, maxProb*100), 'FontSize', 10);
ylabel('Amplitude');
if strcmp(componentType, 'Eye') && maxProb > 0.5
set(gca, 'Color', [1 0.9 0.9]);
hold on;
plot(time_sec, EEG.icaact(ic, time_points), 'r', 'LineWidth', 1);
end
grid on;
if ic == n_components
xlabel('Time (seconds)');
else
set(gca, 'XTickLabel', []);
end
end
sgtitle(['ICA Components - ' inputFileName], 'FontSize', 12);

%% 5. 手动选择ICA成分
fprintf('请在弹出的窗口中选择要保留的ICA成分...\n');

% 创建选择界面
selectFig = figure('Name', '选择要保留的ICA成分', 'Position', [200 200 400 500], 'MenuBar', 'none', 'NumberTitle', 'off');
uicontrol('Style', 'text', 'Position', [20 450 360 30],...
    'String', '请勾选要保留的ICA成分:', 'FontSize', 12, 'HorizontalAlignment', 'left');

% 添加复选框
compCheckboxes = [];
for ic = 1:n_components
    compCheckboxes(ic) = uicontrol('Style', 'checkbox',...
        'Position', [20 420-ic*30 300 25],...
        'String', sprintf('IC %d: %s (%.1f%%)', ic, EEG.etc.ic_classification.ICLabel.classes{maxIdx}, maxProb*100),...
        'Value', 1, 'Tag', num2str(ic)); % 默认全选
end

% 添加确认按钮
uicontrol('Style', 'pushbutton', 'Position', [150 20 100 30],...
    'String', '确认选择', 'Callback', 'uiresume(gcbf)');

% 等待用户选择
uiwait(selectFig);

% 获取用户选择
selectedComps = [];
for ic = 1:n_components
    if get(compCheckboxes(ic), 'Value') == 1
        selectedComps(end+1) = ic;
    end
end

% 关闭选择窗口
close(selectFig);

% 剔除未选择的成分
if length(selectedComps) < n_components
    rejectComps = setdiff(1:n_components, selectedComps);
    fprintf('正在剔除以下成分: ');
    fprintf('%d ', rejectComps);
    fprintf('\n');
    EEG = pop_subcomp(EEG, rejectComps, 0);
    fprintf('已剔除 %d 个成分。\n', length(rejectComps));
else
    fprintf('未剔除任何成分。\n');
end

% --- 新增：保存ICA清理后状态 ---
EEG_ica_cleaned = EEG;

%% 6. 保存结果
fprintf('正在保存处理后的文件...\n');
eeg_data = double(EEG.data);
outputFilename = fullfile(outputPath, [inputFileName, '_preprocessed.mat']);
save(outputFilename, 'eeg_data');
fprintf('处理完成！结果已保存至:\n%s\n', outputFilename);
catch ME
fprintf('\n处理文件 %s.txt 时发生错误:\n', inputFileName);
fprintf('错误信息: %s\n', ME.message);
fprintf('错误发生在第 %d 行。\n', ME.stack(1).line);
end

% %% ==================== 新增：可视化处理步骤 ====================
% if ~isempty(EEG_ica_cleaned) % 仅在处理成功时绘图
% fprintf('\n正在生成处理步骤对比图...\n');
% % --- 绘图参数 ---
% plot_duration_s = 200; % 截取5秒的数据进行展示
% plot_channels = 1:EEG_raw.nbchan; % 要绘制的通道
% % 计算要绘制的时间窗
% time_points = 1:min(srate * plot_duration_s, EEG_raw.pnts);
% time_vector_s = EEG_raw.times(time_points) / 1000; % 转换为秒
% % 创建一个大的Figure窗口
% figure('Name', ['Preprocessing Steps Comparison: ', inputFileName], 'Position', [50 50 1600 900]);
% % 存储所有子图的句柄，用于链接坐标轴
% ax = [];
% % 1. 绘制原始数据
% ax(1) = subplot(5, 1, 1);
% plot(time_vector_s, EEG_raw.data(plot_channels, time_points));
% title('1. 原始数据 (Raw Data)', 'FontSize', 12);
% ylabel('Amplitude (\muV)');
% grid on;
% % 2. 绘制带通滤波后
% ax(2) = subplot(5, 1, 2);
% plot(time_vector_s, EEG_bandpassed.data(plot_channels, time_points));
% title('2. 带通滤波后 (0.1-60 Hz)', 'FontSize', 12);
% ylabel('Amplitude (\muV)');
% grid on;
% % 3. 绘制陷波滤波后
% ax(3) = subplot(5, 1, 3);
% plot(time_vector_s, EEG_notched.data(plot_channels, time_points));
% title('3. 陷波滤波后 (50 Hz Notch)', 'FontSize', 12);
% ylabel('Amplitude (\muV)');
% grid on;
% % % 4. 绘制重参考后
% % ax(4) = subplot(5, 1, 4);
% % plot(time_vector_s, EEG_rereferenced.data(plot_channels, time_points));
% % title('4. 全脑平均重参考后 (Average Rereference)', 'FontSize', 12);
% % ylabel('Amplitude (\muV)');
% % grid on;
% %
% % 5. 绘制ICA剔除伪迹后
% ax(5) = subplot(5, 1, 5);
% plot(time_vector_s, EEG_ica_cleaned.data(plot_channels, time_points));
% title('5. ICA伪迹剔除后 (ICA Cleaned)', 'FontSize', 12);
% ylabel('Amplitude (\muV)');
% xlabel('Time (seconds)', 'FontSize', 12);
% grid on;
% % 链接所有子图的X轴，这样缩放一个图时，其他图会同步缩放
% linkaxes(ax, 'x');
% % 统一Y轴范围，便于比较幅值变化
% linkaxes(ax, 'y');
% % 为整个Figure添加一个总标题
% sgtitle(['文件: ' inputFileName ' - 各预处理步骤波形对比 (前 ' num2str(plot_duration_s) ' 秒)'], 'FontSize', 16, 'FontWeight', 'bold');
% fprintf('对比图生成完毕！\n');
% else
% fprintf('\n由于处理过程中发生错误，未能生成对比图。\n');
% end

%% CSD的批量处理 (此部分保持不变)
% data_folder = 'D:\Pycharm_Projects\ADHD_Network\数据集\IEEE CONTROL采样率128\预处理后';
% coord_file = 'D:\Pycharm_Projects\ADHD_Network\数据集\IEEE CONTROL采样率128\Location.xlsx';
% save_file = 'D:\Pycharm_Projects\ADHD_Network\数据集\IEEE CONTROL采样率128\CSD后';
% % 运行批处理
% batch_csd_with_xlsx_coords(data_folder, coord_file,save_file);