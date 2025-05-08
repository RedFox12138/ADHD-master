function [d1,output] = EEG_preprocess(signal,Fs)
d1 = signal;
% 二阶50 Hz的陷波
[ d1 ] = IIR( d1,Fs,50 );

% % 二阶100 Hz的陷波
[ d1 ] = IIR( d1,Fs,100 );

d1 = HPF( d1,Fs,0.5 );
d1 = LPF(d1,Fs,100);


%% memd

goal=7; % 模态数 输出是5+1
ens=10; %%  次数

%% 分析两分钟的数据
win_N = 100;
output_1= [];

out_IMF1 = [];

for j = 1:length(d1)/win_N
    win_d1 = d1(1+(j-1)*win_N:j*win_N);

    nos=std(win_d1)*0.2; % 噪声
    [imfs_1]=eemd(win_d1, goal, ens, nos);
    % cca
    X = [imfs_1';zeros(1,size(imfs_1,1))];
    [A,B,r,U,V] = canoncorr(X(1:end-1,:),X(2:end,:));
    r
    %U 置零
    zeroEigIndex = find(r<0.92);
    U(:,zeroEigIndex) = zeros(size(U,1),length(zeroEigIndex));
    X_de = U * inv(A);
    % denoise
    out_d1 = sum(X_de,2);

    %%
    out_IMF1 = [out_IMF1,imfs_1];

    output_1 = [output_1,out_d1'];

end
output = output_1;

end