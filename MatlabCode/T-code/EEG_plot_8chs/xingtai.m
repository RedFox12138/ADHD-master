
% ch10 = load('C:\Users\Pikachu\Desktop\data\01-17-20-31-51_ch1.txt');
% ch10=ch10./12;
[IMF,res] = emd(A9, 'MaxNumIMF',9);
figure(1);
subplot(5,2,1);
plot(IMF(:,1));
title("IMF1");
subplot(5,2,2);
plot(IMF(:,2));
title("IMF2");
subplot(5,2,3);
plot(IMF(:,3));
title("IMF3");
subplot(5,2,4);
plot(IMF(:,4));
title("IMF4");
subplot(5,2,5);
plot(IMF(:,5));
title("IMF5");
subplot(5,2,6);
plot(IMF(:,6));
title("IMF6");
subplot(5,2,7);
plot(IMF(:,7));
title("IMF7");
subplot(5,2,8);
plot(IMF(:,8));
title("IMF8");
subplot(5,2,9);
plot(IMF(:,9));
title("IMF9");
subplot(5,2,10);
plot(res);
title("RES");

si = sum(IMF(:,[2,3,4,5,6,7,8,9]),2)+IMF(:,1)*0.4+res;
figure(2);
subplot(2,1,1);plot(si);subplot(2,1,2);plot(A9);

imf_idx = find(abs(IMF(:,1))<0.005);
IMF1 = IMF(:,1);
IMF1(imf_idx) = 0;
figure(3);
subplot(2,1,1);
plot(IMF(:,1));
subplot(2,1,2);
plot(IMF1);

si = sum(IMF(:,[2,3,4,5,6,7,8,9]),2)+IMF1*2+res;
figure(4);
subplot(2,1,1);
plot(t9,si,'k','LineWidth',0.7);
subplot(2,1,2);
plot(t9,A9,'k','LineWidth',0.7);

% plot(ch10);
% OPTIONS.MAXMODES = 11; %设置IMF层数5层，得到的imf中有6行，最后一行为res.
% emd(A9, 'MaxNumIMF',5);
% [c,l] = wavedec(A9,5,'db3');
% approx = appcoef(c,l,'db3');
% [cd1,cd2,cd3,cd4,cd5] = detcoef(c,l,[1 2 3 4 5]);
%  c2=[cd2,cd3,cd4,cd5]; 
% s0=waverec(c2,l,'db3'); %小波重构 
% figure; 
% subplot(221);plot(x),title('原始数据小波去噪前'),xlabel('x','FontSize',15),ylabel('幅值','FontSize',15)
% subplot(223);plot(s0),title('原始数据小波去噪后'),xlabel('x','FontSize',15),ylabel('幅值','FontSize',15)
% subplot(222)
% plot_fft(A9,fs,1);%原图像对应频谱
% subplot(224)
% plot_fft(s0,fs,1);%原图像对应频谱





% subplot(5,1,1)
% plot(approx)
% title('Approximation Coefficients')
% subplot(5,1,2)
% plot(cd5)
% title('Level 5 Detail Coefficients')
% subplot(5,1,3)
% plot(cd4)
% title('Level 4 Detail Coefficients')
% subplot(5,1,4)
% plot(cd1)
% title('Level 1 Detail Coefficients')
% subplot(5,1,5)
% plot(A9)
% title('Original')

% subplot(6,2,1);plot(imf(1,:));title('IMF1');
% subplot(6,2,2);plot(imf(2,:));title('IMF2');
% subplot(6,2,3);plot(imf(3,:));title('IMF3');
% subplot(6,2,4);plot(imf(4,:));title('IMF4');
% subplot(6,2,5);plot(imf(5,:));title('IMF5');
% subplot(6,2,6);plot(imf(6,:));title('IMF6');
% subplot(6,2,7);plot(imf(7,:));title('IMF7');
% subplot(6,2,8);plot(imf(8,:));title('IMF8');
% subplot(6,2,9);plot(imf(9,:));title('IMF9');
% subplot(6,2,10);plot(imf(10,:));title('IMF10');
% subplot(6,2,11);plot(imf(11,:));title('IMF11');
% subplot(6,2,12);plot(imf(6,:));title('res');


%% 用全局默认阈值进行去噪处理 
% xden = wdenoise(imf(1,:),5);




% chonggou=imf(1,:)+imf(2,:)+imf(3,:)+imf(4,:)+imf(5,:)+imf(6,:);
% figure
% plot(chonggou);