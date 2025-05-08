function [Xkf] = kalman(Z)
%UNTITLED3 此处提供此函数的摘要
%   此处提供详细说明
% Z=load('C:\Users\Pikachu\Desktop\data\07-28-14-40-27_ch1.txt');
 
N=length(Z);  
X=zeros(1,N);    
Xkf=zeros(1,N);  
P=zeros(1,N);   
%X(1)=25.1;  
P(1)=0.01;  
Xkf(1)=Z(1);  
Q=0.05;%W(k)的方差  
R=0.25;%V(k)的方差  
W=sqrt(Q)*randn(1,N);  
% figure  
% hist(W,N);  
V=sqrt(R)*randn(1,N);  
% figure  
% hist(V,N);  
F=1;  
G=1;  
H=1;  
I=eye(1);   
	%%%%%%%%%%%%%%%%%%%%%%%  
for k=2:N  
    X(k)=F*X(k-1)+G*W(k-1);    
    if Z(k)-Z(k-1)>1.7  
        X_pre = 2.4;  
	    elseif Z(k)-Z(k-1)<-1.7  
	        X_pre = -3.3;  
	    else  
            X_pre=F*Xkf(k-1);   
	    end   
%     X_pre=F*Xkf(k-1);            
	    P_pre=F*P(k-1)*F'+Q;          
	    K=P_pre*inv(H*P_pre*H'+R);   
	    e=Z(k)-H*X_pre;              
	    Xkf(k)=X_pre+K*e;           
	    P(k)=(I-K*H)*P_pre;  
	end  
for i=1:N-100  
    if Xkf(i)>1.5  
	        count=0;  
	        for j=i+1:i+80  
            if Xkf(j)>1.5  
	                count=count+1;  
	            end  
	        end  
	        if count<20  
	            Xkf(i)=0;  
        end  
	    end   
	    if Xkf(i)<-1.5  
        count=0;  
        for j=i+1:i+80  
            if Xkf(j)<-1.5  
	                count=count+1;  
           end  
        end  
        if count<20  
            Xkf(i)=0;  
	        end  
    end   
end  
  
t=1:N;  
figure('Name','Kalman Filter Simulation','NumberTitle','off');  
plot(t,Z,'-r',t,Xkf,'-b');  
figure();  
plot(Z);  
title('原始信号');  
  
figure(2);  
plot(Xkf);  


end