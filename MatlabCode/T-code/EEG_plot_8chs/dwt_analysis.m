

%% dwt
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%对数据进行小波七层分解重构
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%
%调入含突变点的信号
%%%%%%%%%%%%%%%%%%%%%%%%%

fs =250;
d = 'coif5';
x =A9;
N=length(x);
[c,l]=wavedec(x,7,d); %小波基为d:coif5,分解层数为7层 小波变换函数
ca11=appcoef(c,l,d,7); %小波变换低频部分系数提取
cd1=detcoef(c,l,1); %小波变换高频部分系数提取
cd2=detcoef(c,l,2); 
cd3=detcoef(c,l,3); 
cd4=detcoef(c,l,4); 
cd5=detcoef(c,l,5); 
cd6=detcoef(c,l,6); 
cd7=detcoef(c,l,7); 
sd1=zeros(1,length(cd1)); %设置成0阵
sd2=zeros(1,length(cd2)); %1-3层置0,4-5层用软阈值函数处理 5-7层用硬阈值函数处理
sd3=zeros(1,length(cd3)); 
sd4=wthresh(cd4,'s',0.014); %返回输入向量或矩阵X经过软阈值（如果SORH='s'）
sd5=wthresh(cd5,'s',0.014); %或硬阈值（如果SORH='h'）处理后的信号。T是阈值。
sd6=wthresh(cd6,'h',0.014); 
sd7=wthresh(cd7,'h',0.014); 
% c2=[ca11,sd7,sd6,sd5,sd4,sd3,sd2,sd1];
c2=[ca11,cd7,cd6,cd5,cd4,cd3,cd2];
s0=waverec(c2,l,'coif5'); %小波重构 
figure; 
subplot(221);plot(x),title('原始数据小波去噪前'),xlabel('x','FontSize',15),ylabel('幅值','FontSize',15)
subplot(223);plot(s0),title('原始数据小波去噪后'),xlabel('x','FontSize',15),ylabel('幅值','FontSize',15)
subplot(222)
plot_fft(x,fs,1);%原图像对应频谱
subplot(224)
plot_fft(s0,fs,1);%原图像对应频谱
