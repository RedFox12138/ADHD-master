function [ft,F] = FFT_YY(Ix,Fs)
%%%%%%FFT%%%%%%
%%% Y = fft(X,n) ���� n �� DFT�����δָ���κ�ֵ���� Y �Ĵ�С�� X ��ͬ��

LL = length(Ix);      % ���ݳ���
N = LL;
F = fft(Ix,N);
F = abs(F)/N*2;       % ����˫��Ƶ�ף��ο�mathwork���̣�
% F = 20*log(F);
F = F(1:N/2);         % ���㵥��Ƶ��   
ft = (0:(Fs/N):Fs/2);     
ft = ft(1:N/2);       % ����Ƶ��
% ft = Fs*(0:(LL/2))/LL;

end

