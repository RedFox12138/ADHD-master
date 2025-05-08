function [out_d1] = SSA_CCA(win_d1,windowLen)
    imfs_1=SSA_1(win_d1,windowLen);
    X = [imfs_1';zeros(1,size(imfs_1,1))];
    [A,B,r,U,V] = canoncorr(X(1:end-1,:),X(2:end,:));
    %U 置零
    zeroEigIndex = find(r<0.92);
    U(:,zeroEigIndex) = zeros(size(U,1),length(zeroEigIndex));
    X_de = U * inv(A);
    % denoise
    out_d1 = sum(X_de,2);
end

