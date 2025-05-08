function [output] = waveletpackdec(signal)

t = wpdec(signal,5,'db4');
% plot(t); % 绘制小包树
% wpviewcf(t,1);
wpt = wpjoin(t,[3 1]);
wpt = wpjoin(wpt,[3 2]);
wpt = wpjoin(wpt,[3 3]);
wpt = wpjoin(wpt,[1 1]);
% plot(wpt)
% wpviewcf(wpt,1);

% % 实现对节点顺序按照频率递增进行重排序
nodes = get(wpt,'tn'); % 获取terminal nodes节点
ord = wpfrqord(nodes);
nodes_ord = nodes(ord); % 重排后的小波系数

% 实现对节点小波节点进行重构
for i = 1:length(nodes_ord)
    rex5(:,i) = wprcoef(wpt,nodes_ord(i));
end

output = rex5;
end