function hfd = calculateFD(eeg_signal, k_max)
    % 该函数计算给定EEG信号的Higuchi分形维度（HFD）。
    %
    % 输入:
    %   eeg_signal : EEG信号向量
    %   k_max      : 最大子序列长度，推荐3-5之间
    %
    % 输出:
    %   hfd        : Higuchi分形维度值

    n = length(eeg_signal);
    if n <= k_max
        hfd = NaN;
        return;
    end
    
    L_k = zeros(1, k_max);
    
    for k = 1:k_max
        L_km = zeros(1, k);
        for m = 1:k
            L_m = 0;
            for i = 1:floor((n - m) / k)
                L_m = L_m + abs(eeg_signal(m + i*k) - eeg_signal(m + (i-1)*k));
            end
            L_m = (L_m * (n - 1) / (floor((n - m) / k) * k));
            L_km(m) = L_m;
        end
        L_k(k) = mean(L_km);
    end
    
    log_L_k = log(L_k);
    log_k = log(1./(1:k_max));
    
    % 使用最小二乘法拟合，斜率即为HFD
    p = polyfit(log_k, log_L_k, 1);
    hfd = p(1);
end