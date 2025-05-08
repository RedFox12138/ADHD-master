function [out] = EEG_vmd_cca(d1)

% vmd

%% cca
win_N = 100;
output_1= [];
d2 = [];
for j = 1:length(d1)/win_N
    index = 1+(j-1)*win_N:j*win_N; 
    win_d1 = d1(index);
    % vmd
    [IMFs,residual] = vmd(win_d1);

    % cca
    X = [IMFs residual];
    X = [X;zeros(1,size(X,2))];
    [A,B,r,U,V] = canoncorr(X(1:end-1,:),X(2:end,:));
    %r
    %U 置零
    zeroEigIndex = find(r<0.92);
    U(:,zeroEigIndex) = zeros(size(U,1),length(zeroEigIndex));
    X_de = U * inv(A);
%     output_1 = [output_1;X_de];
    % denoise
    out_d1 = sum(X_de,2);
    d2(index) = out_d1';


   
end
out = d2;
end