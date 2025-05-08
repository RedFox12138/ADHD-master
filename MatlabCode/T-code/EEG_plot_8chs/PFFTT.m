function [f,mag_x] = PFFTT(mv,Fs)
%�����ױ任
LL=length(mv);                              % ���ݳ���
Np=Fs/2;
Nfft=Np*2;
window=hann(Np*2);
noverlap=Np;
dflag='mean';
f=(0:Nfft/2)*Fs/Nfft;           
xx=mv(LL/2:LL);                 %xx=mv(LL/2:LL);

[x_fft,f]=pwelch(xx,window,noverlap,f,Fs);

% [pxx,f] = periodogram(x,window,f,fs);
% [x_fft,f]=psd(xx,Nfft,Fs,window,noverlap,dflag); 
% [pxx,f] = pwelch(x,window,noverlap,f,fs);
%

mag_x=10*log10(x_fft);          %���ʴ�С���� ��λ���dB

end

