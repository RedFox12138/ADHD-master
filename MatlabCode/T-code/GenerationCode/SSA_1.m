function imf_1 = SSA_1(data,windowLen)
    series = data;
    series = series - mean(series);   % 中心化(非必须)
    
    % step1 嵌入
    seriesLen = length(series);     % 序列长度
    K = seriesLen - windowLen + 1;
    X = zeros(windowLen, K);
    for i = 1:K
        X(:, i) = series(i:i + windowLen - 1);
    end
    
    % step2: svd分解， U和sigma已经按升序排序
    [U, S, VT] = svd(X, 'econ');
    VT=VT';
    sigma = diag(S);
    for i = 1:size(VT, 1)
        VT(i, :) = VT(i, :) * sigma(i);
    end  
    A = VT;
    % 重组
    rec = zeros(windowLen, seriesLen);
    for i = 1:windowLen
        for j = 1:windowLen - 1
            for m = 1:j
                rec(i, j) = rec(i, j) + A(i, j - m + 1) * U(m, i);
            end
            rec(i, j) = rec(i, j) / (j);
        end
        for j = windowLen:seriesLen - windowLen
            for m = 1:windowLen
                rec(i, j) = rec(i, j) + A(i, j - m + 1) * U(m, i);
            end
            rec(i, j) = rec(i, j) / windowLen;
        end
        for j = seriesLen - windowLen + 1:seriesLen
            for m = j - seriesLen + windowLen:windowLen
                rec(i, j) = rec(i, j) + A(i, j - m + 1) * U(m, i);
            end
            rec(i, j) = rec(i, j) / (seriesLen - j + 1);
        end
    end
    imf_1=rec;
end

