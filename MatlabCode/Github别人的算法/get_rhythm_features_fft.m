function out = get_rhythm_features_fft(data, fs)
    % 定义频段参数
    iter_freqs = struct(...
        'delta', struct('fmin', 0, 'fmax', 4), ...
        'theta', struct('fmin', 4, 'fmax', 8), ...
        'low_alpha', struct('fmin', 8, 'fmax', 10), ...
        'high_alpha', struct('fmin', 10, 'fmax', 13), ...
        'low_beta', struct('fmin', 13, 'fmax', 20), ...
        'high_beta', struct('fmin', 20, 'fmax', 35), ...
        'low_gamma', struct('fmin', 35, 'fmax', 50), ...
        'high_gamma', struct('fmin', 50, 'fmax', 100));
    
    % 初始化频谱特征结构体
    spectral_feature = struct();
    bands = fieldnames(iter_freqs);
    for i = 1:length(bands)
        spectral_feature.(bands{i}) = [];
    end
    
    % 计算FFT
    data_fft = abs(fft(data, 128));  % 更改fft点数
    N = length(data_fft);
    data_fft = data_fft(1:floor(N/2));
    fr = linspace(0, 128, floor(N/2));  % 更改f映射
    t = 0:1/fs:(length(data)/fs - 1/fs);
    
    % 按频段分类
    for i = 1:length(fr)
        item = fr(i);
        if iter_freqs.delta.fmin < item && item < iter_freqs.delta.fmax
            spectral_feature.delta(end+1) = data_fft(i)^2;
        elseif iter_freqs.theta.fmin < item && item < iter_freqs.theta.fmax
            spectral_feature.theta(end+1) = data_fft(i)^2;
        elseif iter_freqs.low_alpha.fmin < item && item < iter_freqs.low_alpha.fmax
            spectral_feature.low_alpha(end+1) = data_fft(i)^2;
        elseif iter_freqs.high_alpha.fmin < item && item < iter_freqs.high_alpha.fmax
            spectral_feature.high_alpha(end+1) = data_fft(i)^2;
        elseif iter_freqs.low_beta.fmin < item && item < iter_freqs.low_beta.fmax
            spectral_feature.low_beta(end+1) = data_fft(i)^2;
        elseif iter_freqs.high_beta.fmin < item && item < iter_freqs.high_beta.fmax
            spectral_feature.high_beta(end+1) = data_fft(i)^2;
        elseif iter_freqs.low_gamma.fmin < item && item < iter_freqs.low_gamma.fmax
            spectral_feature.low_gamma(end+1) = data_fft(i)^2;
        elseif iter_freqs.high_gamma.fmin < item && item < iter_freqs.high_gamma.fmax
            spectral_feature.high_gamma(end+1) = data_fft(i)^2;
        end
    end
    
    % 计算各频段平均值
    out = struct();
    for i = 1:length(bands)
        band = bands{i};
        out.(band) = mean(spectral_feature.(band));
    end
end