% 假设已经执行了 VMD 分解
[imf, residual, info] = vmd(data,'NumIMF', 8);

% 创建时间轴（假设采样频率为 fs）
fs = 250; % 示例采样频率，请根据实际情况修改
t = (0:length(data)-1)/fs; 

% 绘制所有模态和残差
figure('Color', 'white', 'Position', [100, 100, 900, 600]);

% 1. 绘制原始信号
subplot(size(imf,2)+2, 1, 1);
plot(t, data, 'b', 'LineWidth', 1.2);
title('原始信号', 'FontSize', 10);
ylabel('幅值');
xlim([t(1) t(end)]);
grid on;

% 2. 绘制各个IMF分量
for k = 1:size(imf,2)
    subplot(size(imf,2)+2, 1, k+1);
    plot(t, imf(:,k), 'Color', [0.2 0.6 0.4], 'LineWidth', 1.1);
    title(['IMF ', num2str(k), ' (中心频率: ', num2str(info.CentralFrequencies(k), '%.2f'), ' Hz)'], 'FontSize', 10);
    ylabel('幅值');
    xlim([t(1) t(end)]);
    grid on;
end

% 3. 绘制残差
subplot(size(imf,2)+2, 1, size(imf,2)+2);
plot(t, residual, 'r', 'LineWidth', 1.2);
title('残差', 'FontSize', 10);
ylabel('幅值');
xlabel('时间 (s)');
xlim([t(1) t(end)]);
grid on;

% 调整子图间距
set(gcf, 'Position', [100, 100, 900, 600]);
h = findobj(gcf, 'type', 'axes');
set(h, 'FontSize', 9);