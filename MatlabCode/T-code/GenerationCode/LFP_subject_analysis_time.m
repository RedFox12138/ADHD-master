%% 单通道 LFP analysis 时域信号分析
clc
close all;
clear all;

%% load data

% data = importdata('E:\brainData\小鼠脑电信号处理\LFP\20240528\20240528_3\channel_2.txt');
EEG = load('D:\pycharm Project\ADHD-master\data\oksQL7aHWZ0qkXkFP-oC05eZugE8\0418\0418 SF额头风景画移动+心算2.txt');
data = EEG; % 通道
Fs = 250;
% 选择时间点 每组信号是在第2min给氨气刺激 选择刺激前后30s
index = [70*Fs:1:90*Fs]; % 空气选择刺激前1min

d1 = data(index);

% % 降采样到250Hz
% d1_250hz = downsample(d1,4);
% Fs = 250;

% f1 f2 index
% theta1 3.9 – 7.8 Hz  2
% theta2 7.8 – 11.7 Hz  3
% alpha  11.7 - 15.625 4
% beta 15.625-31.25 5
% f1 = 15.625;
% f2 = 31.25 ;
% index = 2;
% signal_air = [];
% signal_nh3 = [];



[ex01_d1_output] = EEGPreprocess(d1, 250, "none");

% 小波包分解
[rex_ch1] = waveletpackdec(ex01_d1_output);

theta1 = rex_ch1(:,2);
theta2 = rex_ch1(:,3);
alpha = rex_ch1(:,4);
beta = rex_ch1(:,5);
%% ----  analysis figure ----
%% 子波段时域信号
% figure;

x =[0:1/250:(length(theta1)-1)/250] + 115;
subplot(5,1,1);
plot(x,ex01_d1_output,'Color',"k",'LineWidth',0.5);
ylabel('denoised','FontName','Times New Roman','FontSize',12)

subplot(5,1,2);
plot(x,theta1,'Color',"k",'LineWidth',0.5);
ylabel('{\theta}1','FontName','Times New Roman','FontSize',12)
% xlabel('time/s','FontName','Times New Roman','FontSize',12)
% xlim([25 40])

subplot(5,1,3);
plot(x,theta2,'Color',"k",'LineWidth',0.5);
ylabel('{\theta}2','FontName','Times New Roman','FontSize',12)
% xlabel('time/s','FontName','Times New Roman','FontSize',12)
% xlim([25 40])
subplot(5,1,4);
plot(x,alpha,'Color',"k",'LineWidth',0.5);
ylabel('{\alpha}','FontName','Times New Roman','FontSize',12)
% xlabel('time/s','FontName','Times New Roman','FontSize',12)

subplot(5,1,5);
plot(x,beta,'Color',"k",'LineWidth',0.5);
ylabel('{\beta}','FontName','Times New Roman','FontSize',12)
xlabel('time/s','FontName','Times New Roman','FontSize',12)
% xlim([25 40])


