function plot_signal_comparison(original_mat_file, processed_mat_file, save_name)
% 绘制EEG信号处理前后对比图 - 高质量学术出版标准
% 
% 输入:
%   original_mat_file - 原始信号mat文件路径
%   processed_mat_file - 处理后信号mat文件路径
%   save_name - 保存图片的文件名（不含扩展名）
%
% 示例:
%   plot_signal_comparison('subject_001_静息_original.mat', ...
%                         'subject_001_静息_processed.mat', ...
%                         'subject_001_静息_对比图')

    fprintf('正在读取原始信号: %s\n', original_mat_file);
    original_data = load(original_mat_file);
    original_signal = original_data.signal(:);  % 确保是列向量
    fs = double(original_data.fs);  % 确保转换为double类型
    
    fprintf('正在读取处理后信号: %s\n', processed_mat_file);
    processed_data = load(processed_mat_file);
    processed_signal = processed_data.signal(:);  % 确保是列向量
    
    % 生成时间轴（确保使用double类型）
    time_axis = double(0:length(original_signal)-1) / fs;
    
    % 创建图形（确保可见）
    fig = figure('Position', [100, 100, 1400, 800], 'Visible', 'on');
    set(fig, 'Color', 'white');
    set(fig, 'PaperPositionMode', 'auto');
    
    % 设置全局字体
    set(0, 'DefaultAxesFontName', '宋体');
    set(0, 'DefaultAxesFontSize', 16);
    set(0, 'DefaultTextFontName', '宋体');
    set(0, 'DefaultTextFontSize', 16);
    
    % ===== 子图1: 原始信号 =====
    subplot(2, 1, 1);
    plot(time_axis, original_signal, 'k-', 'LineWidth', 1.5);
    xlabel('时间 (s)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', '宋体');
    ylabel('幅值 (μV)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', '宋体');
    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.3);
    set(gca, 'LineWidth', 1.5);
    set(gca, 'Box', 'on');
    set(gca, 'FontSize', 20);
    xlim([time_axis(1), time_axis(end)]);
    % 添加图例
    legend('原始信号', 'Location', 'best', 'FontSize', 16, 'FontName', '宋体');
    
    % 添加子图标识
    text(0.5, -0.22, '(a) 原始信号', ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 18, ...
        'FontWeight', 'bold', ...
        'FontName', '宋体');
    
    % ===== 子图2: 预处理后信号 =====
    subplot(2, 1, 2);
    plot(time_axis, processed_signal, 'k-', 'LineWidth', 1.5);
    xlabel('时间 (s)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', '宋体');
    ylabel('幅值 (μV)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', '宋体');
    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.3);
    set(gca, 'LineWidth', 1.5);
    set(gca, 'Box', 'on');
    set(gca, 'FontSize', 20);
    xlim([time_axis(1), time_axis(end)]);
    % 添加图例
    legend('预处理后信号', 'Location', 'best', 'FontSize', 16, 'FontName', '宋体');
    
    % 添加子图标识
    text(0.5, -0.22, '(b) 预处理后信号', ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 18, ...
        'FontWeight', 'bold', ...
        'FontName', '宋体');
    
    % 添加总标题
    sgtitle(save_name, ...
        'FontSize', 24, ...
        'FontWeight', 'bold', ...
        'FontName', '宋体');
    
    % 调整子图间距
    set(gcf, 'Units', 'normalized');
    
    % 保存图片
    [mat_dir, ~, ~] = fileparts(original_mat_file);
    
    % 保存为高分辨率PNG
    png_path = fullfile(mat_dir, [save_name '.png']);
    print(fig, png_path, '-dpng', '-r300');
    fprintf('PNG图片已保存: %s\n', png_path);
    
    % 保存为EPS矢量图（推荐用于论文）
    eps_path = fullfile(mat_dir, [save_name '.eps']);
    print(fig, eps_path, '-depsc', '-tiff');
    fprintf('EPS矢量图已保存: %s\n', eps_path);
    
    % 保存为PDF矢量图
    pdf_path = fullfile(mat_dir, [save_name '.pdf']);
    print(fig, pdf_path, '-dpdf', '-fillpage');
    fprintf('PDF矢量图已保存: %s\n', pdf_path);
    
    fprintf('\n所有图片已生成完成！\n');
    
    % 强制刷新显示
    drawnow;
    
    % 不关闭图形，保持显示
    % close(fig); % 已注释，图形将保持打开
end
