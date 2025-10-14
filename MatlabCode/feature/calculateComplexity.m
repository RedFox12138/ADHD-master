function [activity, mobility, complexity] = calculateComplexity(eeg_signal, Fs)
    % 计算EEG信号的Hjorth参数
    %
    % 输入:
    %   eeg_signal : EEG信号向量（单通道）
    %   Fs         : 采样频率(Hz)
    %
    % 输出:
    %   activity   : 活动性(信号方差)
    %   mobility   : 移动性(一阶导数标准差与原始信号标准差之比)
    %   complexity : 复杂度(二阶导数移动性与一阶导数移动性之比)
    
    % 确保输入为行向量
    eeg_signal = eeg_signal(:)';
    
    % 移除NaN值
    eeg_signal(isnan(eeg_signal)) = [];
    
    % 检查信号长度
    if length(eeg_signal) < 3
        error('信号长度必须至少为3个点');
    end
    
    % 计算活动性(方差)
    activity = var(eeg_signal);
    
    % 计算一阶导数(差分)
    first_deriv = diff(eeg_signal) * Fs; % 乘以Fs得到实际单位(μV/s)
    
    % 计算二阶导数
    second_deriv = diff(first_deriv) * Fs; % (μV/s²)
    
    % 计算移动性
    mobility = std(first_deriv) / std(eeg_signal);
    
    % 计算复杂度
    if length(second_deriv) >= 1
        complexity = std(second_deriv) / std(first_deriv);
    else
        complexity = NaN;
    end
    
    % 可选: 对极短信号进行平滑处理
    % if length(eeg_signal) < Fs
    %     window_size = max(3, floor(length(eeg_signal)/4));
    %     eeg_signal = movmean(eeg_signal, window_size);
    % end
end