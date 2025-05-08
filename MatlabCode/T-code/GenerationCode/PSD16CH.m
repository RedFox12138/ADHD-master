clc
close all;
clear all;
%% 16CH预处理

data = load('E:\brainData\小鼠脑电信号处理\LFP\2024-06-13\2024-06-13-10-28.txt');
ch1 = data(:,1);
ch1=ch1./12;
ch2 = data(:,2);
ch2=ch2./12;
ch3 = data(:,3);
ch3=ch3./12;
ch4 = data(:,4);
ch4=ch4./12;
ch5 = data(:,5);
ch5=ch5./12;
ch6 = data(:,6);
ch6=ch6./12;
ch7 = data(:,7);
ch7=ch7./12;
ch8 = data(:,8);
ch8=ch8./12;
ch9 = data(:,9);
ch9=ch9./12;
ch10 = data(:,10);
ch10=ch10./12;
ch11 = data(:,11);
ch11=ch11./12;
ch12 = data(:,12);
ch12=ch12./12;
ch13 = data(:,13);
ch13=ch13./12;
ch14 = data(:,14);
ch14=ch14./12;
ch15 = data(:,15);
ch15=ch15./12;
ch16 = data(:,16);
ch16=ch16./12;
% ch2 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_2.txt');
% ch2=ch2./12;
% ch3 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_3.txt');
% ch3=ch3./12;
% ch4 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_4.txt');
% ch4=ch4./12;
% ch5 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_5.txt');
% ch5=ch5./12;
% ch6 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_6.txt');
% ch6=ch6./12;
% ch7 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_7.txt');
% ch7=ch7./12;
% ch8 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_8.txt');
% ch8=ch8./12;
% ch9 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_9.txt');
% ch9=ch9./12;
% ch10 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_10.txt');
% ch10=ch10./12;
% ch11 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_11.txt');
% ch11=ch11./12;
% ch12 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_12.txt');
% ch12=ch12./12;
% ch13 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_13.txt');
% ch13=ch13./12;
% ch14 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_14.txt');
% ch14=ch14./12;
% ch15 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_15.txt');
% ch15=ch15./12;
% ch16 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_16.txt');
% ch16=ch16./12;
% 预处理
L(1)=length(ch1);
L(2)=length(ch2);
L(3)=length(ch3);
L(4)=length(ch4);
L(5)=length(ch5);
L(6)=length(ch6);
L(7)=length(ch7);
L(8)=length(ch8);
L(9)=length(ch9);
L(10)=length(ch10);
L(11)=length(ch11);
L(12)=length(ch12);
L(13)=length(ch13);
L(14)=length(ch14);
L(15)=length(ch15);
L(16)=length(ch16);
%% 对照组预处理
adata = load('E:\brainData\小鼠脑电信号处理\LFP\2024-06-13\2024-06-13-10-28.txt');
ach1 = adata(:,1);
ach1=ach1./12;
ach2 = adata(:,2);
ach2=ach2./12;
ach3 = adata(:,3);
ach3=ach3./12;
ach4 = adata(:,4);
ach4=ach4./12;
ach5 = adata(:,5);
ach5=ach5./12;
ach6 = adata(:,6);
ach6=ach6./12;
ach7 = adata(:,7);
ach7=ach7./12;
ach8 = adata(:,8);
ach8=ach8./12;
ach9 = adata(:,9);
ach9=ach9./12;
ach10 = adata(:,10);
ach10=ach10./12;
ach11 = adata(:,11);
ach11=ach11./12;
ach12 = adata(:,12);
ach12=ach12./12;
ach13 = adata(:,13);
ach13=ach13./12;
ach14 = adata(:,14);
ach14=ach14./12;
ach15 = adata(:,15);
ach15=ach15./12;
ach16 = adata(:,16);
ach16=ach16./12;
% ach1=ach1./12;
% ach2 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_2.txt');
% ach2=ach2./12;
% ach3 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_3.txt');
% ach3=ach3./12;
% ach4 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_4.txt');
% ach4=ach4./12;
% ach5 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_5.txt');
% ach5=ach5./12;
% ach6 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_6.txt');
% ach6=ach6./12;
% ach7 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_7.txt');
% ach7=ach7./12;
% ach8 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_8.txt');
% ach8=ach8./12;
% ach9 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_9.txt');
% ach9=ach9./12;
% ach10 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_10.txt');
% ach10=ach10./12;
% ach11 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_11.txt');
% ach11=ach11./12;
% ach12 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_12.txt');
% ach12=ach12./12;
% ach13 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_13.txt');
% ach13=ach13./12;
% ach14 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_14.txt');
% ach14=ach14./12;
% ach15 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_15.txt');
% ach15=ach15./12;
% ach16 = load('E:\MASTER\小鼠脑电\脑电数据\20240528\20240528_6\channel_16.txt');
% ach16=ach16./12;
% 预处理
L(1)=length(ach1);
L(2)=length(ach2);
L(3)=length(ach3);
L(4)=length(ach4);
L(5)=length(ach5);
L(6)=length(ach6);
L(7)=length(ach7);
L(8)=length(ach8);
L(9)=length(ach9);
L(10)=length(ach10);
L(11)=length(ach11);
L(12)=length(ach12);
L(13)=length(ach13);
L(14)=length(ach14);
L(15)=length(ach15);
L(16)=length(ach16);
%%
Min=min(L);
ch1=ch1(2*60*1000:2.5*60*1000);
ch2=ch2(2*60*1000:2.5*60*1000);
ch3=ch3(2*60*1000:2.5*60*1000);
ch4=ch4(2*60*1000:2.5*60*1000);
ch5=ch5(2*60*1000:2.5*60*1000);
ch6=ch6(2*60*1000:2.5*60*1000);
ch7=ch7(2*60*1000:2.5*60*1000);
ch8=ch8(2*60*1000:2.5*60*1000);
ch9=ch9(2*60*1000:2.5*60*1000);
ch10=ch10(2*60*1000:2.5*60*1000);
ch11=ch11(2*60*1000:2.5*60*1000);
ch12=ch12(2*60*1000:2.5*60*1000);
ch13=ch13(2*60*1000:2.5*60*1000);
ch14=ch14(2*60*1000:2.5*60*1000);
ch15=ch15(2*60*1000:2.5*60*1000);
ch16=ch16(2*60*1000:2.5*60*1000);

ach1=ach1(1.5*60*1000:2*60*1000);
ach2=ach2(1.5*60*1000:2*60*1000);
ach3=ach3(1.5*60*1000:2*60*1000);
ach4=ach4(1.5*60*1000:2*60*1000);
ach5=ach5(1.5*60*1000:2*60*1000);
ach6=ach6(1.5*60*1000:2*60*1000);
ach7=ach7(1.5*60*1000:2*60*1000);
ach8=ach8(1.5*60*1000:2*60*1000);
ach9=ach9(1.5*60*1000:2*60*1000);
ach10=ach10(1.5*60*1000:2*60*1000);
ach11=ach11(1.5*60*1000:2*60*1000);
ach12=ach12(1.5*60*1000:2*60*1000);
ach13=ach13(1.5*60*1000:2*60*1000);
ach14=ach14(1.5*60*1000:2*60*1000);
ach15=ach15(1.5*60*1000:2*60*1000);
ach16=ach16(1.5*60*1000:2*60*1000);

d1=ch1;
d2=ch2;
d3=ch3;
d4=ch4;
d5=ch5;
d6=ch6;
d7=ch7;
d8=ch8;
d9=ch9;
d10=ch10;
d11=ch11;
d12=ch12;
d13=ch13;
d14=ch14;
d15=ch15;
d16=ch16;

ad1=ach1;
ad2=ach2;
ad3=ach3;
ad4=ach4;
ad5=ach5;
ad6=ach6;
ad7=ach7;
ad8=ach8;
ad9=ach9;
ad10=ach10;
ad11=ach11;
ad12=ach12;
ad13=ach13;
ad14=ach14;
ad15=ach15;
ad16=ach16;
Fs = 1000;%采样率


%% 陷波
% 二阶50 Hz的陷波
[ d1 ] = IIR( d1,Fs,50 );
[ d2 ] = IIR( d2,Fs,50 );
[ d3 ] = IIR( d3,Fs,50 );
[ d4 ] = IIR( d4,Fs,50 );
[ d5 ] = IIR( d5,Fs,50 );
[ d6 ] = IIR( d6,Fs,50 );
[ d7 ] = IIR( d7,Fs,50 );
[ d8 ] = IIR( d8,Fs,50 );
[ d9 ] = IIR( d9,Fs,50 );
[ d10 ] = IIR( d10,Fs,50 );
[ d11 ] = IIR( d11,Fs,50 );
[ d12 ] = IIR( d12,Fs,50 );
[ d13 ] = IIR( d13,Fs,50 );
[ d14 ] = IIR( d14,Fs,50 );
[ d15 ] = IIR( d15,Fs,50 );
[ d16 ] = IIR( d16,Fs,50 );

% 二阶100 Hz的陷波
[ d1 ] = IIR( d1,Fs,100 );
[ d2 ] = IIR( d2,Fs,100 );
[ d3 ] = IIR( d3,Fs,100 );
[ d4 ] = IIR( d4,Fs,100 );
[ d5 ] = IIR( d5,Fs,100 );
[ d6 ] = IIR( d6,Fs,100 );
[ d7 ] = IIR( d7,Fs,100 );
[ d8 ] = IIR( d8,Fs,100 );
[ d9 ] = IIR( d9,Fs,100 );
[ d10 ] = IIR( d10,Fs,100 );
[ d11 ] = IIR( d11,Fs,100 );
[ d12 ] = IIR( d12,Fs,100 );
[ d13 ] = IIR( d13,Fs,100 );
[ d14 ] = IIR( d14,Fs,100 );
[ d15 ] = IIR( d15,Fs,100 );
[ d16 ] = IIR( d16,Fs,100 );

% 二阶50 Hz的陷波
[ ad1 ] = IIR( ad1,Fs,50 );
[ ad2 ] = IIR( ad2,Fs,50 );
[ ad3 ] = IIR( ad3,Fs,50 );
[ ad4 ] = IIR( ad4,Fs,50 );
[ ad5 ] = IIR( ad5,Fs,50 );
[ ad6 ] = IIR( ad6,Fs,50 );
[ ad7 ] = IIR( ad7,Fs,50 );
[ ad8 ] = IIR( ad8,Fs,50 );
[ ad9 ] = IIR( ad9,Fs,50 );
[ ad10 ] = IIR( ad10,Fs,50 );
[ ad11 ] = IIR( ad11,Fs,50 );
[ ad12 ] = IIR( ad12,Fs,50 );
[ ad13 ] = IIR( ad13,Fs,50 );
[ ad14 ] = IIR( ad14,Fs,50 );
[ ad15 ] = IIR( ad15,Fs,50 );
[ ad16 ] = IIR( ad16,Fs,50 );


% 二阶100 Hz的陷波
[ ad1 ] = IIR( ad1,Fs,100 );
[ ad2 ] = IIR( ad2,Fs,100 );
[ ad3 ] = IIR( ad3,Fs,100 );
[ ad4 ] = IIR( ad4,Fs,100 );
[ ad5 ] = IIR( ad5,Fs,100 );
[ ad6 ] = IIR( ad6,Fs,100 );
[ ad7 ] = IIR( ad7,Fs,100 );
[ ad8 ] = IIR( ad8,Fs,100 );
[ ad9 ] = IIR( ad9,Fs,100 );
[ ad10 ] = IIR( ad10,Fs,100 );
[ ad11 ] = IIR( ad11,Fs,100 );
[ ad12 ] = IIR( ad12,Fs,100 );
[ ad13 ] = IIR( ad13,Fs,100 );
[ ad14 ] = IIR( ad14,Fs,100 );
[ ad15 ] = IIR( ad15,Fs,100 );
[ ad16 ] = IIR( ad16,Fs,100 );

% 二阶150 Hz的陷波
[ d1 ] = IIR( d1,Fs,150 );
[ d2 ] = IIR( d2,Fs,150 );
[ d3 ] = IIR( d3,Fs,150 );
[ d4 ] = IIR( d4,Fs,150 );
[ d5 ] = IIR( d5,Fs,150 );
[ d6 ] = IIR( d6,Fs,150 );
[ d7 ] = IIR( d7,Fs,150 );
[ d8 ] = IIR( d8,Fs,150 );
[ d9 ] = IIR( d9,Fs,150 );
[ d10 ] = IIR( d10,Fs,150 );
[ d11 ] = IIR( d11,Fs,150 );
[ d12 ] = IIR( d12,Fs,150 );
[ d13 ] = IIR( d13,Fs,150 );
[ d14 ] = IIR( d14,Fs,150 );
[ d15 ] = IIR( d15,Fs,150 );
[ d16 ] = IIR( d16,Fs,150 );

% 二阶150 Hz的陷波
[ ad1 ] = IIR( ad1,Fs,150 );
[ ad2 ] = IIR( ad2,Fs,150 );
[ ad3 ] = IIR( ad3,Fs,150 );
[ ad4 ] = IIR( ad4,Fs,150 );
[ ad5 ] = IIR( ad5,Fs,150 );
[ ad6 ] = IIR( ad6,Fs,150 );
[ ad7 ] = IIR( ad7,Fs,150 );
[ ad8 ] = IIR( ad8,Fs,150 );
[ ad9 ] = IIR( ad9,Fs,150 );
[ ad10 ] = IIR( ad10,Fs,150 );
[ ad11 ] = IIR( ad11,Fs,150 );
[ ad12 ] = IIR( ad12,Fs,150 );
[ ad13 ] = IIR( ad13,Fs,150 );
[ ad14 ] = IIR( ad14,Fs,150 );
[ ad15 ] = IIR( ad15,Fs,150 );
[ ad16 ] = IIR( ad16,Fs,150 );

% 二阶200 Hz的陷波
[ d1 ] = IIR( d1,Fs,200 );
[ d2 ] = IIR( d2,Fs,200 );
[ d3 ] = IIR( d3,Fs,200 );
[ d4 ] = IIR( d4,Fs,200 );
[ d5 ] = IIR( d5,Fs,200 );
[ d6 ] = IIR( d6,Fs,200 );
[ d7 ] = IIR( d7,Fs,200 );
[ d8 ] = IIR( d8,Fs,200 );
[ d9 ] = IIR( d9,Fs,200 );
[ d10 ] = IIR( d10,Fs,200 );
[ d11 ] = IIR( d11,Fs,200 );
[ d12 ] = IIR( d12,Fs,200 );
[ d13 ] = IIR( d13,Fs,200 );
[ d14 ] = IIR( d14,Fs,200 );
[ d15 ] = IIR( d15,Fs,200 );
[ d16 ] = IIR( d16,Fs,200 );

% 二阶200 Hz的陷波
[ ad1 ] = IIR( ad1,Fs,200 );
[ ad2 ] = IIR( ad2,Fs,200 );
[ ad3 ] = IIR( ad3,Fs,200 );
[ ad4 ] = IIR( ad4,Fs,200 );
[ ad5 ] = IIR( ad5,Fs,200 );
[ ad6 ] = IIR( ad6,Fs,200 );
[ ad7 ] = IIR( ad7,Fs,200 );
[ ad8 ] = IIR( ad8,Fs,200 );
[ ad9 ] = IIR( ad9,Fs,200 );
[ ad10 ] = IIR( ad10,Fs,200 );
[ ad11 ] = IIR( ad11,Fs,200 );
[ ad12 ] = IIR( ad12,Fs,200 );
[ ad13 ] = IIR( ad13,Fs,200 );
[ ad14 ] = IIR( ad14,Fs,200 );
[ ad15 ] = IIR( ad15,Fs,200 );
[ ad16 ] = IIR( ad16,Fs,200 );

% 二阶250 Hz的陷波
[ d1 ] = IIR( d1,Fs,250 );
[ d2 ] = IIR( d2,Fs,250 );
[ d3 ] = IIR( d3,Fs,250 );
[ d4 ] = IIR( d4,Fs,250 );
[ d5 ] = IIR( d5,Fs,250 );
[ d6 ] = IIR( d6,Fs,250 );
[ d7 ] = IIR( d7,Fs,250 );
[ d8 ] = IIR( d8,Fs,250 );
[ d9 ] = IIR( d9,Fs,250 );
[ d10 ] = IIR( d10,Fs,250 );
[ d11 ] = IIR( d11,Fs,250 );
[ d12 ] = IIR( d12,Fs,250 );
[ d13 ] = IIR( d13,Fs,250 );
[ d14 ] = IIR( d14,Fs,250 );
[ d15 ] = IIR( d15,Fs,250 );
[ d16 ] = IIR( d16,Fs,250 );

% 二阶250 Hz的陷波
[ ad1 ] = IIR( ad1,Fs,250 );
[ ad2 ] = IIR( ad2,Fs,250 );
[ ad3 ] = IIR( ad3,Fs,250 );
[ ad4 ] = IIR( ad4,Fs,250 );
[ ad5 ] = IIR( ad5,Fs,250 );
[ ad6 ] = IIR( ad6,Fs,250 );
[ ad7 ] = IIR( ad7,Fs,250 );
[ ad8 ] = IIR( ad8,Fs,250 );
[ ad9 ] = IIR( ad9,Fs,250 );
[ ad10 ] = IIR( ad10,Fs,250 );
[ ad11 ] = IIR( ad11,Fs,250 );
[ ad12 ] = IIR( ad12,Fs,250 );
[ ad13 ] = IIR( ad13,Fs,250 );
[ ad14 ] = IIR( ad14,Fs,250 );
[ ad15 ] = IIR( ad15,Fs,250 );
[ ad16 ] = IIR( ad16,Fs,250 );


%% 使用小波包分解来进行频段分离
A1_theta=LPF(d1,Fs,31.255);
A1_theta=HPF( A1_theta,Fs,16.625 );
A2_theta=LPF(d2,Fs,31.255);
A2_theta=HPF( A2_theta,Fs,16.625 );
A3_theta=LPF(d3,Fs,31.255);
A3_theta=HPF( A3_theta,Fs,16.625 );
A4_theta=LPF(d4,Fs,31.255);
A4_theta=HPF( A4_theta,Fs,16.625 );
A5_theta=LPF(d5,Fs,31.255);
A5_theta=HPF( A5_theta,Fs,16.625 );
A6_theta=LPF(d6,Fs,31.255);
A6_theta=HPF( A6_theta,Fs,16.625 );
A7_theta=LPF(d7,Fs,31.255);
A7_theta=HPF( A7_theta,Fs,16.625 );
A8_theta=LPF(d8,Fs,31.255);
A8_theta=HPF( A8_theta,Fs,16.625 );
A9_theta=LPF(d9,Fs,31.255);
A9_theta=HPF( A9_theta,Fs,16.625 );
A10_theta=LPF(d10,Fs,31.255);
A10_theta=HPF( A10_theta,Fs,16.625 );
A11_theta=LPF(d11,Fs,31.255);
A11_theta=HPF( A11_theta,Fs,16.625 );
A12_theta=LPF(d12,Fs,31.255);
A12_theta=HPF( A12_theta,Fs,16.625 );
A13_theta=LPF(d13,Fs,31.255);
A13_theta=HPF( A13_theta,Fs,16.625 );
A14_theta=LPF(d14,Fs,31.255);
A14_theta=HPF( A14_theta,Fs,16.625 );
A15_theta=LPF(d15,Fs,31.255);
A15_theta=HPF( A15_theta,Fs,16.625 );
A16_theta=LPF(d16,Fs,31.255);
A16_theta=HPF( A16_theta,Fs,16.625 );

aA1_theta=LPF(ad1,Fs,31.255);
aA1_theta=HPF( aA1_theta,Fs,16.625 );
aA2_theta=LPF(ad2,Fs,31.255);
aA2_theta=HPF( aA2_theta,Fs,16.625 );
aA3_theta=LPF(ad3,Fs,31.255);
aA3_theta=HPF(aA3_theta,Fs,16.625 );
aA4_theta=LPF(ad4,Fs,31.255);
aA4_theta=HPF( aA4_theta,Fs,16.625 );
aA5_theta=LPF(ad5,Fs,31.255);
aA5_theta=HPF(aA5_theta,Fs,16.625 );
aA6_theta=LPF(ad6,Fs,31.255);
aA6_theta=HPF( aA6_theta,Fs,16.625 );
aA7_theta=LPF(ad7,Fs,31.255);
aA7_theta=HPF( aA7_theta,Fs,16.625 );
aA8_theta=LPF(ad8,Fs,31.255);
aA8_theta=HPF( aA8_theta,Fs,16.625 );
aA9_theta=LPF(ad9,Fs,31.255);
aA9_theta=HPF( aA9_theta,Fs,16.625 );
aA10_theta=LPF(ad10,Fs,31.255);
aA10_theta=HPF( aA10_theta,Fs,16.625 );
aA11_theta=LPF(ad11,Fs,31.255);
aA11_theta=HPF( aA11_theta,Fs,16.625 );
aA12_theta=LPF(ad12,Fs,31.255);
aA12_theta=HPF( aA12_theta,Fs,16.625 );
aA13_theta=LPF(ad13,Fs,31.255);
aA13_theta=HPF( aA13_theta,Fs,16.625 );
aA14_theta=LPF(ad14,Fs,31.255);
aA14_theta=HPF( aA14_theta,Fs,16.625 );
aA15_theta=LPF(ad15,Fs,31.255);
aA15_theta=HPF( aA15_theta,Fs,16.625 );
aA16_theta=LPF(ad16,Fs,31.255);
aA16_theta=HPF( aA16_theta,Fs,16.625 );
%% 求谱密度
% nfft=1000;%-------fft点数
% nfft = 4000;
% figure(1);
% subplot(4,4,1)
% [px1t,fx1t]=pwelch(A1_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx1t,afx1t]=pwelch(aA1_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx1t,10*log10(px1t),'k-','LineWidth',1);hold on;
% plot(afx1t,10*log10(apx1t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH1 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,2)
% [px2t,fx2t]=pwelch(A2_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx2t,afx2t]=pwelch(aA2_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx2t,10*log10(px2t),'k-','LineWidth',1);hold on;
% plot(afx2t,10*log10(apx2t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH2 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,3)
% [px3t,fx3t]=pwelch(A3_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx3t,afx3t]=pwelch(aA3_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx3t,10*log10(px3t),'k-','LineWidth',1);hold on;
% plot(afx3t,10*log10(apx3t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH3 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% 
% subplot(4,4,4)
% [px4t,fx4t]=pwelch(A4_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx4t,afx4t]=pwelch(aA4_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx4t,10*log10(px4t),'k-','LineWidth',1);hold on;
% plot(afx4t,10*log10(apx4t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH4 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% subplot(4,4,5)
% [px5t,fx5t]=pwelch(A5_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx5t,afx5t]=pwelch(aA5_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx5t,10*log10(px5t),'k-','LineWidth',1);hold on;
% plot(afx5t,10*log10(apx5t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH5 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,6)
% [px6t,fx6t]=pwelch(A6_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx6t,afx6t]=pwelch(aA6_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx6t,10*log10(px6t),'k-','LineWidth',1);hold on;
% plot(afx6t,10*log10(apx6t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH6 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,7)
% [px7t,fx7t]=pwelch(A7_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx7t,afx7t]=pwelch(aA7_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx7t,10*log10(px7t),'k-','LineWidth',1);hold on;
% plot(afx7t,10*log10(apx7t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH7 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% subplot(4,4,8)
% [px8t,fx8t]=pwelch(A8_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx8t,afx8t]=pwelch(aA8_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx8t,10*log10(px8t),'k-','LineWidth',1);hold on;
% plot(afx8t,10*log10(apx8t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH8 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,9)
% [px9t,fx9t]=pwelch(A9_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx9t,afx9t]=pwelch(aA9_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx9t,10*log10(px9t),'k-','LineWidth',1);hold on;
% plot(afx9t,10*log10(apx9t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH9 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% subplot(4,4,10)
% [px10t,fx10t]=pwelch(A10_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx10t,afx10t]=pwelch(aA10_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx10t,10*log10(px10t),'k-','LineWidth',1);hold on;
% plot(afx10t,10*log10(apx10t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH10 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,11)
% [px11t,fx11t]=pwelch(A11_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx11t,afx11t]=pwelch(aA11_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx11t,10*log10(px11t),'k-','LineWidth',1);hold on;
% plot(afx11t,10*log10(apx11t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH11 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,12)
% [px12t,fx12t]=pwelch(A12_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx12t,afx12t]=pwelch(aA12_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx12t,10*log10(px12t),'k-','LineWidth',1);hold on;
% plot(afx12t,10*log10(apx12t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH12 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,13)
% [px13t,fx13t]=pwelch(A13_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx13t,afx13t]=pwelch(aA13_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx13t,10*log10(px13t),'k-','LineWidth',1);hold on;
% plot(afx13t,10*log10(apx13t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH13 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,14)
% [px14t,fx14t]=pwelch(A14_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx14t,afx14t]=pwelch(aA14_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx14t,10*log10(px14t),'k-','LineWidth',1);hold on;
% plot(afx14t,10*log10(apx14t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH14 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,15)
% [px15t,fx15t]=pwelch(A15_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx15t,afx15t]=pwelch(aA15_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx15t,10*log10(px15t),'k-','LineWidth',1);hold on;
% plot(afx15t,10*log10(apx15t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH15 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
%  xlim([15 40]);
% 
% 
% 
% subplot(4,4,16)
% [px16t,fx16t]=pwelch(A16_theta,hanning(nfft),nfft/2,nfft,Fs);
% [apx16t,afx16t]=pwelch(aA16_theta,hanning(nfft),nfft/2,nfft,Fs);
% plot(fx16t,10*log10(px16t),'k-','LineWidth',1);hold on;
% plot(afx16t,10*log10(apx16t),'r','LineWidth',1);
% legend('NH3','Air');
% title('CH16 Beta功率谱密度');
% xlabel('Frequency/Hz');
% ylabel('Power/frequency (dB/Hz)');
% xlim([15 40]);

nh3 = [d1;d2;d3;d4;d5;d6;d7;d8;d9;d10;d11;d12;d13;d14;d15;d16];
air = [ad1;ad2;ad3;ad4;ad5;ad6;ad7;ad8;ad9;ad10;ad11;ad12;ad13;ad14;ad15;ad16];
figure;
Fs = 1000;
for i = 1:16
    subplot(4,4,i)
    pspectrum(nh3(i,:),1000,'power','FrequencyResolution',Fs/250);
%     pwelch(nh3(i,:),4000,2000,1000,1000)
    hold on;
    pspectrum(air(i,:),1000,'power','FrequencyResolution',Fs/250);
%     pwelch(air(i,:),4000,2000,1000,1000)
    legend('nh3','air')
    title( "ch" + num2str(1));
    ylim([0 60])
%     xlim([0 100])
end




