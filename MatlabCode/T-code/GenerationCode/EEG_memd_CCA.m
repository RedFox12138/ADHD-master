%% EEG_memd_CCA

clc
close all;
clear all;
addpath(strcat(pwd,'\functions\')) % add path where you saved to memd function 
save_path = strcat(pwd,'\figs\'); % path where you want to save your figures
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
% % 二阶100 Hz的陷波
[ d1 ] = IIR( d1,Fs,100 );
[ d2 ] = IIR( d2,Fs,100 );

d1 = HPF( d1,Fs,0.5 );
d2 = HPF( d2,Fs,0.5 );
d1 = LPF(d1,Fs,100);
d2 = LPF(d2,Fs,100);

%% memd
% define time vector
dt = 1/Fs;               % seconds per sample 
stopTime = length(d1)/Fs;            % length of signal in seconds 
t = (0:dt:stopTime-dt)'; % time vector in seconds 
stopTime_plot = 120;       % limit time axis for improved visualization 
% data_combined = [d1',d2'];

% -------------------------------------------------------------------------------------------
% parameters for memd algorithm
% -------------------------------------------------------------------------------------------

% advice: change these values to see how they influence your results 
k = 64;                        % projection directions
stopCrit = [0.075 0.75]; % stopping criteria

% -------------------------------------------------------------------------------------------

% pretty colors for plotting
blue = [0 0.4470 0.7410];
orange = [0.8500 0.3250 0.0980];
red = [0.6350 0.0780 0.1840];
violet = [0.4940 0.1840 0.5560];
green = [0.4660 0.6740 0.1880];
cyan = [0.3010 0.7450 0.9330];

% -------------------------------------------------------------------------------------------
% plot data 
% -------------------------------------------------------------------------------------------

figure
set(gcf,'color','w','Units','normalized','Position', [0.1, 0.2, 0.8, 0.5]);
tiledlayout(2,1)

% signal 1
nexttile
plot(t,d1,'color',blue,'LineWidth',2);
xlabel('$t/s$','interpreter','latex');
ylabel('$ch1$','interpreter','latex');
xlim([0 stopTime_plot])
ax = gca;
ax.FontSize = 16; 

% signal 3
nexttile
% fake plot of signal 1 and 2 outside the domain for legend
plot(t,400.*ones(length(t),1),'color',blue,'LineWidth',2);
hold on
plot(t,400.*ones(length(t),1),'color',orange,'LineWidth',2);
% third signal
plot(t,d2,'color',green,'LineWidth',2);
xlabel('$t/s$','interpreter','latex');
ylabel('$ch2$','interpreter','latex');
xlim([0 stopTime_plot])
ylim([-7 12])
ax = gca;
ax.FontSize = 16; 
legend('$ch1$','$ch2$','interpreter','latex',...
    'location','southoutside','orientation','horizontal')
legend boxoff

saveas(gcf,strcat(save_path,'inputData.png'));

% -------------------------------------------------------------------------------------------
% apply EEMD
% -------------------------------------------------------------------------------------------

goal=5;
ens=10;
nos=3;
%% 分析两分钟的数据
win_N = 200;
output_1= [];
output_2 = [];
d1 = d1(1:Fs*120);
d2 = d2(1:Fs*120);

for j = 1:length(d1)/win_N
    win_d1 = d1(1+(j-1)*win_N:j*win_N);
    win_d2 = d2(1+(j-1)*win_N:j*win_N);
    [imfs_1]=eemd(win_d1, goal, ens, nos);
    [imfs_2]=eemd(win_d2, goal, ens, nos);
    output_1 = [output_1,imfs_1];
    output_2 = [output_2,imfs_2];

    
end
% -------------------------------------------------------------------------------------------
% plot resulting IMFs
% -------------------------------------------------------------------------------------------

figure
set(gcf,'color','w','Units','normalized','Position', [0.1, 0.08, 0.8, 0.5]);
tiledlayout(2,size(output_2,1));
stopTime = length(d1)/Fs;            % length of signal in seconds 
t = (0:dt:stopTime-dt)'; % time vector in seconds 
% signal 1
i = 1;
imfs_1 = output_1';
imfs_2 = output_2';
for j = 1:size(output_1,1) % loop through IMFs
    nexttile
    plot(t,squeeze(imfs_1(:,j)),'color',blue,'LineWidth',1.5)
    title(strcat(num2str(j),'. IMF'),'interpreter','latex')
    if j == 1
        ylabel('$g_1(t)$','interpreter','latex');
    end        
    xlabel('$t$','interpreter','latex')
    xlim([0 stopTime_plot])
%     ylim([-bounds(i,j) bounds(i,j)])
    ax = gca;
    ax.FontSize = 12; 
end

% signal 2
i = 2;
for j = 1:size(output_1,1)
    nexttile
    plot(t,squeeze(imfs_2(:,j)),'color',orange,'LineWidth',1.5)
    if j == 1
        ylabel('$g_2(t)$','interpreter','latex');
    end  
    xlabel('$t$','interpreter','latex')
    xlim([0 stopTime_plot])
%     ylim([-bounds(i,j) bounds(i,j)])
    ax = gca;
    ax.FontSize = 12; 
end

nexttile
dd = squeeze(sum(imfs_2(:,j+1:end),2));
plot(t,dd,'color',orange,'LineWidth',1.5)
xlabel('$t$','interpreter','latex')   
xlim([0 stopTime_plot])
ylim([mean(dd)-2.01 mean(dd)+2.01])
ax = gca;
ax.FontSize = 12; 

