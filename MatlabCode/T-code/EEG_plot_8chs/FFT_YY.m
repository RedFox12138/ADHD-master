function [ft,F] = FFT_YY(Ix,Fs)
%%%%%%FFT%%%%%%
%%% Y = fft(X,n) 返回 n 点 DFT。如果未指定任何值，则 Y 的大小与 X 相同。

LL = length(Ix);      % 数据长度
N = LL;
F = fft(Ix,N);
F = abs(F)/N*2;       % 计算双侧频谱（参考mathwork例程）
% F = 20*log(F);
F = F(1:N/2);         % 计算单侧频谱   
ft = (0:(Fs/N):Fs/2);     
ft = ft(1:N/2);       % 定义频域
% ft = Fs*(0:(LL/2))/LL;

end

