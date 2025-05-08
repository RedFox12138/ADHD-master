function [out] = EEG_wpt_cca(d1)

%% wpt小波包分解
t = wpdec(d1,5,'db4');
% plot(t); % 绘制小包树
% wpviewcf(t,1);
wpt = wpjoin(t,[3 1]);
wpt = wpjoin(wpt,[3 2]);
wpt = wpjoin(wpt,[3 3]);
wpt = wpjoin(wpt,[1 1]);
% plot(wpt)

% % 实现对节点顺序按照频率递增进行重排序
nodes = get(wpt,'tn'); % 获取terminal nodes节点
ord = wpfrqord(nodes);
nodes_ord = nodes(ord); % 重排后的小波系数

% 实现对节点小波节点进行重构
for i = 1:length(nodes_ord)
    rex5(:,i) = wprcoef(wpt,nodes_ord(i));
end

%% cca
win_N = 100;
output_1= [];
d2 = [];
input1  = rex5;
for j = 1:length(d1)/win_N
    index = 1+(j-1)*win_N:j*win_N;
    win_d1 = input1(index, :);
    % cca
    X = [win_d1;zeros(1,size(win_d1,2))];
    [A,B,r,U,V] = canoncorr(X(1:end-1,:),X(2:end,:));
   % r
    %U 置零
    zeroEigIndex = find(r<0.92);
    U(:,zeroEigIndex) = zeros(size(U,1),length(zeroEigIndex));
    X_de = U * inv(A);

    %     output_1 = [output_1;X_de];
    % denoise
    out_d1 = sum(X_de,2);
    d2(index) = out_d1';
%     output_1 = [output_1;X_de];
end
out = d2;
end