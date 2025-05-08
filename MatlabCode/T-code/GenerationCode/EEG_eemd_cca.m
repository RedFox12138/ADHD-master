

function [out] = EEG_eemd_cca(d1)

goal=7; % 模态数 输出是5+1
ens=10; %%  次数
win_N = 100;
d2 = zeros(1,length(d1));
for j = 1:length(d1)/win_N
    index = [1+(j-1)*win_N:j*win_N];  
    win_d1 = d1(index);
    % eemd
    nos=std(win_d1)*0.2; % 噪声
    [imfs_1] = eemd(win_d1, goal, ens, nos);
    % cca
    X = [imfs_1';zeros(1,size(imfs_1,1))];
    [A,B,r,U,V] = canoncorr(X(1:end-1,:),X(2:end,:));
    %U 置零 U = XA
    zeroEigIndex = find(r<0.92);
    U(:,zeroEigIndex) = zeros(size(U,1),length(zeroEigIndex));
    X_de = U * inv(A);

    % denoise
    out_d1 = sum(X_de,2);
    d2(index) = out_d1';
end
out = d2;

end