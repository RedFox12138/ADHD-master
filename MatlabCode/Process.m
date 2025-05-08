% 设置参数
inputFolder = "D:\pycharm Project\ADHD-master\data\oksQL7aHWZ0qkXkFP-oC05eZugE8\0416\0416 SF头顶风景画移动+心算1.txt";  % 输入文件夹路径
outputFolder = "D:\pycharm Project\ADHD-master\MatlabCode\";  % 输出文件夹路径
windowLength = 2;   % 窗长 (秒)
fs = 250;           % 采样率 (Hz) [假设为250Hz，请根据实际情况修改]


% 获取文件夹中所有.mat文件
fileList = dir(fullfile(inputFolder, '*.txt'));

% 处理每个文件
for fileIdx = 1:length(fileList)
    % 获取当前文件名
    currentFile = fileList(fileIdx).name;
    inputFile = fullfile(inputFolder, currentFile);
    
    % 输出文件将与输入文件同名，保存在输出文件夹
    [~, name, ~] = fileparts(currentFile);
    outputFile = fullfile(outputFolder, [name '_filtered.mat']);
    
    % 加载.mat文件数据
    dataStruct = load(inputFile);
    
    % 假设数据存储在名为'data'的变量中，如果不是请修改
    % 如果.mat文件包含多个变量，需要指定要处理的变量
    data = dataStruct;  % 请根据实际情况修改
    
    % 检查数据是否为单通道
    if size(data, 2) > 1
        error('输入数据应为单通道时序数据');
    end
    
    % 计算完整窗口的数量
    numWindows = floor(length(data) / windowSamples);
    
    % 预分配结果矩阵
    filteredData = zeros(numWindows, windowSamples);
    
    % 处理每个窗口
    for i = 1:numWindows
        % 提取数据
        startIdx = (i-1)*windowSamples + 1;
        endIdx = i*windowSamples;
        raw = data(startIdx:endIdx);
        
        % 串联滤波
        filtered = preprocess(raw);
        filteredData(i,:) = filtered;
    end
    
    % 保存结果到MAT文件
    save(outputFile, 'filteredData');
    
    disp(['处理完成: ' currentFile ' -> ' outputFile]);
end

disp('所有文件处理完成！');
%%
clear all;
% 参数设置
fs = 250;           % 采样率 (Hz)
windowLength = 2;    % 窗长 (秒)
stepSize = 2;        % 间隔 (秒)

% 1. 读取TXT文件数据
txtFilePath = 'D:\pycharm Project\ADHD-master\data\oksQL7aHWZ0qkXkFP-oC05eZugE8\0416\0416 SF头顶风景画移动+心算1.txt'; % 请替换为实际文件路径
rawData = load(txtFilePath); % 假设TXT文件包含单列数据

% 2. 计算窗口参数
samplesPerWindow = windowLength * fs;
samplesPerStep = stepSize * fs;
totalSamples = length(rawData);
numWindows = floor((totalSamples - samplesPerWindow) / samplesPerStep) + 1;

% 3. 计算每个窗口的θ/β功率比
theta_beta_ratio = zeros(numWindows, 1);

for i = 1:numWindows
    % 计算当前窗口的起始和结束样本
    startSample = (i-1)*samplesPerStep + 1;
    endSample = startSample + samplesPerWindow - 1;
    
    % 获取当前窗口信号
    windowSignal = rawData(startSample:endSample);
%     windowSignal = preprocess(windowSignal,250);
    ProSignal = EEGPreprocess(windowSignal,250);
    windowSignal = ProSignal;
    % 计算θ/β功率比
    theta_beta_ratio(i) = compute_power_ratio(windowSignal, fs, [4,8], [12,21]);
end

% 4. 计算时间轴 (秒)
timeAxis = (0:numWindows-1)' * stepSize + windowLength/2;

% 5. 选择10-70s和80-140s的数据段
segment1Indices = find(timeAxis >= 10 & timeAxis <= 70);
segment2Indices = find(timeAxis >= 80 & timeAxis <= 140);

segment1Ratios = theta_beta_ratio(segment1Indices);
segment2Ratios = theta_beta_ratio(segment2Indices);

% 6. 绘制箱型图对比
figure;
boxplot([segment1Ratios, segment2Ratios], 'Labels', {'10-70s', '80-140s'});
title('θ/β功率比箱型图对比 (2s窗口)');
ylabel('θ/β功率比');
grid on;

% 7. 计算并显示统计信息
meanSeg1 = mean(segment1Ratios);
meanSeg2 = mean(segment2Ratios);
stdSeg1 = std(segment1Ratios);
stdSeg2 = std(segment2Ratios);

fprintf('10-70s段: %d个窗口, 平均θ/β比: %.4f±%.4f\n', length(segment1Ratios), meanSeg1, stdSeg1);
fprintf('80-140s段: %d个窗口, 平均θ/β比: %.4f±%.4f\n', length(segment2Ratios), meanSeg2, stdSeg2);

% 根据图片中的判断标准
if meanSeg1 > meanSeg2
    fprintf('注意力水平提高 (θ/β比降低)\n');
else
    fprintf('注意力水平降低 (θ/β比升高)\n');
end
%%
% 参数设置
% 参数设置
fs = 250;               % 采样率
windowLength = 2* fs;  % 2秒窗口长度（500个采样点）
bands = {'delta', 'theta', 'alpha', 'smr','Bl','Bh'}; % 频段名称
bandRanges = [0.5, 4;    % delta: 0.5-4 Hz
              4, 8;      % theta: 4-8 Hz
              8, 12;     % alpha: 8-13 Hz
              12, 16;
              16, 20;
              20, 30];   % beta: 13-30 Hz

% 选择TXT文件
[fileName, folderPath] = uigetfile('*.txt', '选择要处理的TXT文件');
if fileName == 0
    return; % 用户取消了选择
end

% 读取TXT文件数据
filePath = fullfile(folderPath, fileName);
data = load(filePath); % 假设TXT文件包含一列数据

% 定义两个时间窗口（单位：秒）
window1_start = 10;  % 第一个窗口开始时间
window1_end = 70;    % 第一个窗口结束时间
window2_start = 80;  % 第二个窗口开始时间
window2_end = 140;   % 第二个窗口结束时间

% 转换为采样点索引
window1_start_idx = round(window1_start * fs) + 1;
window1_end_idx = round(window1_end * fs);
window2_start_idx = round(window2_start * fs) + 1;
window2_end_idx = round(window2_end * fs);

% 提取两个窗口的数据
data_window1 = data(window1_start_idx:window1_end_idx);
data_window2 = data(window2_start_idx:window2_end_idx);

% 计算每个窗口的2秒分段数量
numWindows1 = floor(length(data_window1) / windowLength);
numWindows2 = floor(length(data_window2) / windowLength);


nfft = 2^nextpow2(windowLength/2); 
% 初始化存储功率谱的数组
[pxx_temp, f] = pwelch(data_window1(1:windowLength), [], [], nfft, fs);
pxx_window1_all = zeros(length(f), numWindows1, length(bands));
pxx_window2_all = zeros(length(f), numWindows2, length(bands));

% 计算第一个窗口的功率谱
for winIdx = 1:numWindows1
    startIdx = (winIdx-1)*windowLength + 1;
    endIdx = winIdx*windowLength;
    precessData = preprocess(data_window1(startIdx:endIdx),250);
    [pxx, f] = pwelch(precessData, [], [], nfft, fs);
    
    for bandIdx = 1:length(bands)
        bandRange = bandRanges(bandIdx, :);
        
        freqIndices = f >= bandRange(1) & f <= bandRange(2);
        pxx_window1_all(:, winIdx, bandIdx) = pxx .* freqIndices;
    end
end

% 计算第二个窗口的功率谱
for winIdx = 1:numWindows2
    startIdx = (winIdx-1)*windowLength + 1;
    endIdx = winIdx*windowLength;
    precessData = preprocess(data_window2(startIdx:endIdx),250);
    [pxx, f] = pwelch(precessData, [], [], nfft, fs);
    
    for bandIdx = 1:length(bands)
        bandRange = bandRanges(bandIdx, :);
        freqIndices = f >= bandRange(1) & f <= bandRange(2);
        pxx_window2_all(:, winIdx, bandIdx) = pxx .* freqIndices;
    end
end

% 计算平均功率谱
mean_pxx_window1 = squeeze(mean(pxx_window1_all, 2));
mean_pxx_window2 = squeeze(mean(pxx_window2_all, 2));

% 绘制结果
figure('Position', [100, 100, 1200, 800], 'Name', fileName);
for bandIdx = 1:length(bands)
    subplot(2, 3, bandIdx);
    
    % 绘制平均功率谱
    plot(f, 10*log10(mean_pxx_window1(:, bandIdx)), 'b', 'LineWidth', 2);
    hold on;
    plot(f, 10*log10(mean_pxx_window2(:, bandIdx)), 'r', 'LineWidth', 2);
    
    % 设置图形属性
    xlim(bandRanges(bandIdx, :));
    xlabel('频率 (Hz)');
    ylabel('功率 (dB)');
    title([bands{bandIdx} '频段 (' num2str(bandRanges(bandIdx,1)) '-' ...
           num2str(bandRanges(bandIdx,2)) 'Hz)']);
    legend([num2str(window1_start) '-' num2str(window1_end) 's'], ...
           [num2str(window2_start) '-' num2str(window2_end) 's'], ...
           'Location', 'best');
    grid on;
    
    % 突出显示目标频段
    xRange = xlim;
    yRange = ylim;
    patch([bandRanges(bandIdx,1), bandRanges(bandIdx,2), ...
           bandRanges(bandIdx,2), bandRanges(bandIdx,1)], ...
          [yRange(1), yRange(1), yRange(2), yRange(2)], ...
          [0.9, 0.9, 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    uistack(findobj(gca,'Type','patch'), 'bottom');
end

% 添加整体标题
ha = axes('Position',[0 0 1 1],'Xlim',[0 1],'Ylim',[0 1],'Box','off',...
          'Visible','off','Units','normalized', 'clipping' , 'off');
text(0.5, 0.98, ['文件: ' fileName ' - 功率谱比较 (2秒窗口)'], ...
    'HorizontalAlignment','center','VerticalAlignment','top',...
    'FontSize',12,'FontWeight','bold');