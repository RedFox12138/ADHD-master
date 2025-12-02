%% 仅展示新旧板子数据对比图脚本

% 1. 导入或创建数据
% **请将下面的示例数据替换成你的实际数据！**
test1 = load("D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\旧板子\1013 SF额头躲避游戏2.txt"); % 旧板子数据 (test1)
test2 = load("D:\Pycharm_Projects\ADHD-master\data\躲避游戏脑电数据\新板子\1128 新板XY 额头躲避游戏2.txt"); % 新板子数据 (test2)

% 检查数据长度是否一致你
if length(test1) ~= length(test2)
    warning('test1 和 test2 的长度不一致，绘图时可能会出现意外结果，但仍会继续。');
end

N = max(length(test1), length(test2));
x_axis = 1:N; % 用于绘图的索引/采样点

%% 2. 绘制数据对比图

% 创建一个新的 Figure 窗口
figure('Name', '新旧板子数据对比', 'Position', [100, 100, 800, 500]);

% 绘制旧板子数据 (test1)
plot(x_axis(1:length(test1)), test1, 'LineWidth', 1.5);
hold on; % 保持图形，以便在同一坐标轴上绘制 test2

% 绘制新板子数据 (test2)
plot(x_axis(1:length(test2)), test2, 'LineWidth', 1.5);
hold off; % 释放图形锁定

%% 3. 图表美化与标签

title('新旧板子数据 (test2 vs test1) 对比图', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('数据点索引 / 采样点', 'FontSize', 12);
ylabel('测量值', 'FontSize', 12);

% 添加图例来区分两条曲线
legend('旧板子数据 (test1)', '新板子数据 (test2)', 'Location', 'best');

% 显示网格线，便于数据点读取
grid on;