clc
close all;
clear all;
%% 预处理

ch1 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-04-26\20230426\rat02\5\04-27-10-10-53_ch1.txt');
ch1=ch1./12;
ch2 = load('E:\brainData\小鼠脑电信号处理\2023-04-09 EEG采集\2023-04-26\20230426\rat02\5\04-27-10-10-53_ch2.txt');
ch2=ch2./12;

% 预处理
L(1)=length(ch1);
L(2)=length(ch2);
%%
Min=min(L);
ch1=ch1(1:Min);
ch2=ch2(1:Min);
% ch1 = ch1(5*250:25*250);
% ch2 = ch2(5*250:25*250);
d1=ch1;
d2=ch2;


Fs = 250;%采样率

%% 陷波
% 二阶50 Hz的陷波
[ d1 ] = IIR( d1,Fs,50 );
[ d2 ] = IIR( d2,Fs,50 );


% 二阶100 Hz的陷波
[ d1 ] = IIR( d1,Fs,100 );
[ d2 ] = IIR( d2,Fs,100 );

%% 1通道二阶低通高通滤δ(delta)、θ(theta)、α(alpha)波、β(beta)波、γ(gamma)波
A1_delta=LPF(d1,Fs,4);
A1_delta=HPF( A1_delta,Fs,0.5 );
A1_theta=LPF(d1,Fs,8);
A1_theta=HPF( A1_theta,Fs,4 );
A1_alpha=LPF(d1,Fs,14);
A1_alpha=HPF( A1_alpha,Fs,8 );
A1_beta=LPF(d1,Fs,25);
A1_beta=HPF( A1_beta,Fs,14 );
A1_gamma=LPF(d1,Fs,35);
A1_gamma=HPF( A1_gamma,Fs,25 ); 

% A1_delta=pop_eegfiltnew(d1, 0.5, 4);
% A1_theta=pop_eegfiltnew(d1, 4, 8);
% A1_alpha=pop_eegfiltnew(d1, 8, 14);
% A1_beta=pop_eegfiltnew(d1, 14, 25);
% A1_gamma=pop_eegfiltnew(d1, 25, 40);

%% 2通道二阶低通高通滤δ(delta)、θ(theta)、α(alpha)波、β(beta)波、γ(gamma)波
A2_delta=LPF(d1,Fs,4);
A2_delta=HPF( A2_delta,Fs,0.5 );
A2_theta=LPF(d1,Fs,8);
A2_theta=HPF( A2_theta,Fs,4 );
A2_alpha=LPF(d1,Fs,14);
A2_alpha=HPF( A2_alpha,Fs,8 );
A2_beta=LPF(d1,Fs,25);
A2_beta=HPF( A2_beta,Fs,14 );
A2_gamma=LPF(d1,Fs,40);
A2_gamma=HPF( A2_gamma,Fs,25 );

% A2_delta=pop_eegfiltnew(d2, 0.5, 4);
% A2_theta=pop_eegfiltnew(d2, 4, 8);
% A2_alpha=pop_eegfiltnew(d2, 8, 14);
% A2_beta=pop_eegfiltnew(d2, 14, 25);
% A2_gamma=pop_eegfiltnew(d2, 25, 40);

%% 绘图预处理_列举前2个通道
t01 = (1:length(d1))./Fs;
t02 = (1:length(d2))./Fs;


t1_delta= (1:length(A1_delta))./Fs;
t1_theta= (1:length(A1_theta))./Fs;
t1_alpha= (1:length(A1_alpha))./Fs;
t1_beta= (1:length(A1_beta))./Fs;
t1_gamma= (1:length(A1_gamma))./Fs;


t2_delta= (1:length(A2_delta))./Fs;
t2_theta= (1:length(A2_theta))./Fs;
t2_alpha= (1:length(A2_alpha))./Fs;
t2_beta= (1:length(A2_beta))./Fs;
t2_gamma= (1:length(A2_gamma))./Fs;

%% 绘制原始信号
figure(1);
subplot(411)
plot(t01,ch1,'r-','LineWidth',0.5);
legend('CH1');
xlabel('time(s)');
ylabel('amplitude(mV)');
% title('去除杜邦线连接测试（原始信号）');

subplot(412)
plot(t02,ch2,'b-','LineWidth',0.5);
legend('CH2');
xlabel('time(s)');
ylabel('amplitude(mV)');

% 绘制滤波后信号
figure(2);
subplot(511)
plot(t1_delta,A1_delta,'k-','LineWidth',0.5);
legend('CH1 Delta');
xlabel('time(s)');
ylabel('amplitude(mV)');
% title('6a-gn系列电极');

subplot(512)
plot(t1_theta,A1_theta,'k-','LineWidth',0.5);
legend('CH1 Theta');
xlabel('time(s)');
ylabel('amplitude(mV)');

subplot(513)
plot(t1_alpha,A1_alpha,'k-','LineWidth',0.5);
legend('CH1 Alpha');
xlabel('time(s)');
ylabel('amplitude(mV)');

% subplot(514)
% plot(t1_beta,A1_beta,'k-','LineWidth',0.5);
% legend('CH1 Beta');
% xlabel('time(s)');
% ylabel('amplitude(mV)');
% 
% subplot(515)
% plot(t1_gamma,A1_gamma,'k-','LineWidth',0.5);
% legend('CH1 Gamma');
% xlabel('time(s)');
% ylabel('amplitude(mV)');

figure(3);
subplot(511)
plot(t2_delta,A2_delta,'k-','LineWidth',0.5);
legend('CH2 Delta');
xlabel('time(s)');
ylabel('amplitude(mV)');

subplot(512)
plot(t2_theta,A2_theta,'k-','LineWidth',0.5);
legend('CH2 Theta');
xlabel('time(s)');
ylabel('amplitude(mV)');

subplot(513)
plot(t2_alpha,A2_alpha,'k-','LineWidth',0.5);
legend('CH2 Alpha');
xlabel('time(s)');
ylabel('amplitude(mV)');

% subplot(514)
% plot(t2_beta,A2_beta,'k-','LineWidth',0.5);
% legend('CH2 Beta');
% xlabel('time(s)');
% ylabel('amplitude(mV)');
% 
% subplot(515)
% plot(t2_gamma,A2_gamma,'k-','LineWidth',0.5);
% legend('CH2 Gamma');
% xlabel('time(s)');
% ylabel('amplitude(mV)');

%% 原始信号FFT
[f11,mag_x11]=FFT_YY(A1_delta,Fs);% (1)
[f12,mag_x12]=FFT_YY(A1_theta,Fs);% (1)
[f13,mag_x13]=FFT_YY(A1_alpha,Fs);% (1)
[f14,mag_x14]=FFT_YY(A1_beta,Fs);% (1)
[f15,mag_x15]=FFT_YY(A1_gamma,Fs);% (1)
[f21,mag_x21]=FFT_YY(A2_delta,Fs);% (2)
[f22,mag_x22]=FFT_YY(A2_theta,Fs);% (2)
[f23,mag_x23]=FFT_YY(A2_alpha,Fs);% (2)
[f24,mag_x24]=FFT_YY(A2_beta,Fs);% (2)
[f25,mag_x25]=FFT_YY(A2_gamma,Fs);% (2)

LF11 = length(f11)                      %经过fft的信号长度
LF12 = length(f12)
LF13 = length(f13)                      %经过fft的信号长度
LF14 = length(f14)
LF15 = length(f15)                      %经过fft的信号长度
LF21 = length(f21)
LF22 = length(f22)                      %经过fft的信号长度
LF23 = length(f23)
LF24 = length(f24)                      %经过fft的信号长度
LF25 = length(f25)

figure(4);
subplot(511)
semilogy(f11(1:LF11),mag_x11(1:LF11),'r-','LineWidth',1);
legend('CH1 Delta');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(512)
semilogy(f12(1:LF12),mag_x12(1:LF12),'r-','LineWidth',1); 
legend('CH1 Theta');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(513)
semilogy(f13(1:LF13),mag_x13(1:LF13),'r-','LineWidth',1);
legend('CH1 Alpha');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(514)
semilogy(f14(1:LF14),mag_x14(1:LF14),'r-','LineWidth',1);
legend('CH1 Beta');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(515)
semilogy(f15(1:LF15),mag_x15(1:LF15),'r-','LineWidth',1);
legend('CH1 Gamma');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

figure(5);
subplot(511)
semilogy(f21(1:LF21),mag_x21(1:LF21),'r-','LineWidth',1);
legend('CH2 Delta');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(512)
semilogy(f22(1:LF22),mag_x22(1:LF22),'r-','LineWidth',1);
legend('CH2 Theta');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(513)
semilogy(f23(1:LF23),mag_x23(1:LF23),'r-','LineWidth',1);
legend('CH2 Alpha');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(514)
semilogy(f24(1:LF24),mag_x24(1:LF24),'r-','LineWidth',1);
legend('CH2 Beta');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

subplot(515)
semilogy(f25(1:LF25),mag_x25(1:LF25),'r-','LineWidth',1);
legend('CH2 Gamma');
hold on;
xlabel('Frequency (Hz)');
ylabel('amplitude(mV)');
set(gca,'XLim',[0 100]);

%% 生科数据处理
% % test_array = load('H:\test.txt');  % 这里的load()参数是txt文件的地址，test_array就是所读取的数据
% % % 下面五句话是将数组每一行赋给一个变量（最后一句是将一个数组赋值给变量），便于下面的画图
% % x = [1:length(test_array(:,2))];
% % y1 = sleep(:,1);
% % y2 = test_array(:,2);
% [num,txt]=xlsread('test2.xlsx');%读取excel表格中的数据，数值存入num，文本存入txt
% x1 = [1:length(num(:,10))];
% x2 = [1:length(num(:,12))];
% x3 = [1:length(num(:,14))];
% % h=figure            %生成空的图形窗口句柄
% % set(h,'color','w');  %将图的背景颜色设为白色
% % plot(x,num(:,8));    %以日期为横坐标，开盘价为纵坐标，绘制图形
% % xlabel('time');
% % ylabel('amplitude');
% figure(1);
% subplot(311)
% plot(x1,num(:,10),'r-','LineWidth',0.5);
% legend('delta');
% xlabel('time');
% ylabel('amplitude');
% % title('去除杜邦线连接测试（原始信号）');
% 
% subplot(312)
% plot(x2,num(:,12),'b-','LineWidth',0.5);
% legend('theta');
% xlabel('time');
% ylabel('amplitude');
% 
% subplot(313)
% plot(x3,num(:,14),'k-','LineWidth',0.5);
% legend('alpha');
% xlabel('time');
% ylabel('amplitude');
% % title('6a-gn系列电极');
