% 设置参数
inputFolder = "D:\pycharm Project\ADHD-master\data\原信号\";  % 输入文件夹路径
outputFolder = "D:\pycharm Project\ADHD-master\data\Matlab预处理\";  % 输出文件夹路径
windowLength = 2;   % 窗长 (秒)
fs = 250;           % 采样率 (Hz) [假设为250Hz，请根据实际情况修改]
lpfCutoff = 40;     % 低通滤波器截止频率 (Hz)
notchFreq = 50;     % 陷波频率 (Hz)
notchQ = 30;        % 陷波器品质因数
hpfCutoff = 0.5;    % 高通滤波器截止频率 (Hz)

% 计算窗口样本数
windowSamples = fs * windowLength;

% 设计滤波器
hpf = designfilt('highpassiir', 'FilterOrder', 1, 'PassbandFrequency', ...
                 hpfCutoff, 'PassbandRipple', 1, 'SampleRate', fs);

% 设计35Hz低通FIR滤波器
lpfOrder = 50;  % 滤波器阶数
lpf = designfilt('lowpassfir', ...
                 'FilterOrder', lpfOrder, ...
                 'CutoffFrequency', lpfCutoff, ...
                 'SampleRate', fs);

% 设计50Hz陷波IIR滤波器
notchWidth = notchFreq / notchQ;  % 陷波带宽
notch = designfilt('bandstopiir', ...
                   'FilterOrder', 2, ...
                   'HalfPowerFrequency1', notchFreq - notchWidth/2, ...
                   'HalfPowerFrequency2', notchFreq + notchWidth/2, ...
                   'SampleRate', fs);

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
        filtered = filtfilt(notch, filtfilt(hpf, filtfilt(lpf, raw)));
        filteredData(i,:) = filtered;
    end
    
    % 保存结果到MAT文件
    save(outputFile, 'filteredData');
    
    disp(['处理完成: ' currentFile ' -> ' outputFile]);
end

disp('所有文件处理完成！');
%%
input_mat = "D:\pycharm Project\ADHD-master\MatlabCode\eog_removed.mat";

 % 参数设置
fs = 250;           % 采样率 (Hz)
windowLength = 2;   % 窗长 (秒)

% 1. 读取Python处理后的MAT文件
data = load(input_mat);
eog_removed_data = data.eog_removed_data;

% 获取窗口数量
numWindows = size(eog_removed_data, 1);

% 3. 计算每个窗口的θ/β功率比
theta_beta_ratio = zeros(numWindows, 1);

for i = 1:numWindows
    % 获取当前窗口信号
    windowSignal = eog_removed_data(i,:);

    % 计算θ/β功率比
    theta_beta_ratio(i) =compute_power_ratio(windowSignal,250,[4,8],[12,30]);
end

  % 4. 将窗口分为前一半和后一半
    halfPoint = floor(numWindows/3);
    firstHalf = theta_beta_ratio(1:halfPoint);
    secondHalf = theta_beta_ratio(halfPoint+1:end);
    
    % 5. 绘制散点图
    figure;
    hold on;
    
    % 绘制前一半窗口的散点（蓝色）
    scatter(1:length(firstHalf), firstHalf, 100, 'b', 'filled', 'DisplayName', '前一半窗口');
    
    % 绘制后一半窗口的散点（红色）
    scatter((1:length(secondHalf)) + length(firstHalf), secondHalf, 100, 'r', 'filled', 'DisplayName', '后一半窗口');
    
    % 绘制均值线
    plot([1 length(firstHalf)], [mean(firstHalf) mean(firstHalf)], 'b--', 'LineWidth', 2, 'DisplayName', '前一半均值');
    plot([length(firstHalf)+1 length(firstHalf)+length(secondHalf)], [mean(secondHalf) mean(secondHalf)], 'r--', 'LineWidth', 2, 'DisplayName', '后一半均值');
    
    % 添加图例和标签
    legend('Location', 'best');
    title('θ/β功率比随时间变化（2s窗口）');
    xlabel('窗口序号');
    ylabel('θ/β功率比');
    grid on;
    
    % 6. 计算并显示统计信息
    meanFirst = mean(firstHalf);
    meanSecond = mean(secondHalf);
    
    fprintf('前一半窗口数量: %d, 平均θ/β比: %.4f\n', length(firstHalf), meanFirst);
    fprintf('后一半窗口数量: %d, 平均θ/β比: %.4f\n', length(secondHalf), meanSecond);
    
    % 根据图片中的判断标准
    if meanFirst > meanSecond
        fprintf('注意力水平提高 (θ/β比降低)\n');
    else
        fprintf('注意力水平降低 (θ/β比升高)\n');
    end
%%
% 参数设置
% 参数设置
fs = 250;               % 采样率
windowLength = 500;     % 每个窗口的长度
bands = {'delta', 'theta', 'alpha', 'beta'}; % 频段名称
bandRanges = [0.5, 4;    % delta: 0.5-4 Hz
              4, 8;      % theta: 4-8 Hz
              8, 13;     % alpha: 8-13 Hz
              13, 30];   % beta: 13-30 Hz

% 选择文件夹
folderPath = uigetdir('选择包含MAT文件的文件夹');
matFiles = dir(fullfile(folderPath, '*.mat'));

% 处理每个文件
for fileIdx = 1:length(matFiles)
    % 加载数据
    data = load(fullfile(folderPath, matFiles(fileIdx).name));
    fieldName = fieldnames(data);
    signal = data.(fieldName{1}); % 假设数据是文件中唯一的变量
    
    % 计算窗口数量并确定分割点
    numWindows = size(signal, 1);
    halfPoint = floor(numWindows/2);
    
    % 初始化存储功率谱的数组
    [pxx_pre, f] = pwelch(signal(1,:), [], [], [], fs); % 获取频率点
    pxx_pre_all = zeros(length(f), halfPoint, length(bands));
    pxx_post_all = zeros(length(f), numWindows-halfPoint, length(bands));
    
    % 计算前一半窗口的功率谱
    for winIdx = 1:halfPoint
        [pxx, f] = pwelch(signal(winIdx,:), [], [], [], fs);
        for bandIdx = 1:length(bands)
            bandRange = bandRanges(bandIdx, :);
            freqIndices = f >= bandRange(1) & f <= bandRange(2);
            pxx_pre_all(:, winIdx, bandIdx) = pxx .* freqIndices; % 保留该频段，其他置零
        end
    end
    
    % 计算后一半窗口的功率谱
    for winIdx = (halfPoint+1):numWindows
        [pxx, f] = pwelch(signal(winIdx,:), [], [], [], fs);
        for bandIdx = 1:length(bands)
            bandRange = bandRanges(bandIdx, :);
            freqIndices = f >= bandRange(1) & f <= bandRange(2);
            pxx_post_all(:, winIdx-halfPoint, bandIdx) = pxx .* freqIndices;
        end
    end
    
    % 计算平均功率谱
    mean_pxx_pre = squeeze(mean(pxx_pre_all, 2));
    mean_pxx_post = squeeze(mean(pxx_post_all, 2));
    
    % 绘制结果
    figure('Position', [100, 100, 1200, 800], 'Name', matFiles(fileIdx).name);
    for bandIdx = 1:length(bands)
        subplot(2, 2, bandIdx);
        
        % 绘制平均功率谱
        plot(f, 10*log10(mean_pxx_pre(:, bandIdx)), 'b', 'LineWidth', 2);
        hold on;
        plot(f, 10*log10(mean_pxx_post(:, bandIdx)), 'r', 'LineWidth', 2);
        
        % 设置图形属性
        xlim(bandRanges(bandIdx, :));
        xlabel('频率 (Hz)');
        ylabel('功率 (dB)');
        title([bands{bandIdx} '频段 (' num2str(bandRanges(bandIdx,1)) '-' ...
               num2str(bandRanges(bandIdx,2)) 'Hz)']);
        legend('无刺激', '有刺激', 'Location', 'best');
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
    text(0.5, 0.98, ['文件: ' matFiles(fileIdx).name ' - 功率谱比较'], ...
        'HorizontalAlignment','center','VerticalAlignment','top',...
        'FontSize',12,'FontWeight','bold');
end
