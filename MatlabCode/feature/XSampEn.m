function [XSamp, A, B, Vcp_Ka_Kb] = XSampEn(Sig1, Sig2, varargin)
% XSampEn  estimates the cross-sample entropy between two univariate data sequences.
%
%   [XSamp, A, B] = XSampEn(Sig1, Sig2) 
% 
%   Returns the cross-sample entropy estimates (``XSamp``) and the number of 
%   matched vectors (``m: B``, ``m+1: A``) for m = [0,1,2] estimated for the two 
%   univariate data sequences contained in ``Sig1`` and ``Sig2`` using the default parameters:
%   embedding dimension = 2, time delay = 1, 
%   radius distance threshold = 0.2*SDpooled(``Sig1``,``Sig2``), logarithm = natural
% 
%   [XSamp, A, B, (Vcp, Ka, Kb)] = XSampEn(Sig1, Sig2, ..., Vcp = true) 
% 
%   If ``Vcp == True``, an additional vector ``(Vcp, Ka, Kb)`` is returned with    
%   the cross-sample entropy estimates (``XSamp``) and the number of matched state
%   vectors (``m: B``, ``m+1: A``). ``(Vcp, Ka, Kb)``  contains the variance of the conditional
%   probabilities (``Vcp``), i.e. CP = A/B,  and the number of **overlapping**
%   matching vector pairs of lengths m+1 (``Ka``) and m (``Kb``),
%   respectively.  Note ``Vcp`` is undefined for the zeroth embedding dimension (m = 0) 
%   and due to the computational demand, **will take substantially more time to return function outputs.**
%   See Appendix B in [2] for more info.
%
%   [XSamp, A, B] = XSampEn(Sig1, Sig2, name, value, ...)
% 
%   Returns the cross-sample entropy estimates (``XSamp``) for dimensions 
%   [0,1, ..., ``m``] estimated between the data sequences in ``Sig1`` and ``Sig2``
%   using the  specified name/value pair  arguments:
% 
%       * ``m``     - Embedding Dimension, a positive integer  [default: 2]
%       * ``tau``   - Time Delay, a positive integer         [default: 1]
%       * ``r``     - Radius Distance Threshold, a positive scalar [default: 0.2*SDpooled(``Sig1``,``Sig2``)]
%       * ``Logx``  - Logarithm base, a positive scalar      [default: natural]
%       * ``Vcp``   - Option to return variance of conditional probabilities and the number of overlapping matching vector pairs, a boolean [default: false]
%
%   See also:
%       XFuzzEn, XApEn, SampEn, SampEn2D, XMSEn, ApEn
%   
%   References:
%     [1] Joshua S Richman and J. Randall Moorman. 
%           "Physiological time-series analysis using approximate entropy
%           and sample entropy." 
%           American Journal of Physiology-Heart and Circulatory Physiology
%           (2000)
% 
%     [2]  Douglas E Lake, Joshua S Richman, M.P. Griffin, J. Randall Moorman
%           "Sample entropy analysis of neonatal heart rate variability."
%           American Journal of Physiology-Regulatory, Integrative and Comparative Physiology
%           283, no. 3 (2002): R789-R797.
%  

narginchk(2,12)
p = inputParser;
Chk = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (mod(x,1)==0);
Chk2 = @(x) isscalar(x) && (x > 0);
Chk1 = @(x) isnumeric(x) && isvector(x) && numel(x)>=10;
addRequired(p,'Sig1',Chk1);
addRequired(p,'Sig2',Chk1);
S1 = Sig1(:);  S2 = Sig2(:);
N1 = length(S1);  N2 = length(S2);

addParameter(p,'m',2,Chk);
addParameter(p,'tau',1,Chk);
addParameter(p,'r',0.2*sqrt((var(S1,1)*(N1-1) + var(S2,1)*(N2-1))/(N1+N2-1)),Chk2);
addParameter(p,'Logx',exp(1),Chk2);
addParameter(p,'Vcp',false,@(x) islogical(x));
parse(p,Sig1,Sig2,varargin{:})
m = p.Results.m; tau = p.Results.tau; 
r = p.Results.r; Logx = p.Results.Logx; 
Vcp = p.Results.Vcp;

Counter = cast(1*(abs(S1 - S2') <= r),"int8");
M = [m*ones(1,N1-(m*tau)) repelem((m-1):-1:1,tau)];
A(1) = sum(sum(Counter));  B(1) = N1*N2;
% N*(N-1)/2; Changed as no identical pairs compared
for n = 1:N1 - tau 
    ix = find(Counter(n,:)==1);
    for k = 1:M(n)
        ix(ix + (k*tau) > N2) = [];
        if isempty(ix)
            break
        end
        p1 = repmat(S1(n:tau:n+(k*tau))',length(ix),1);
        p2 = S2(ix+(0:tau:tau*k)')';        
        % ix = ix(max(abs(p1 - p2),[],2) <= r);
        ix = ix(any(max(abs(p1 - p2),[],2) <= r,2));
        Counter(n, ix) = Counter(n,ix) + 1;
    end
end

for k = 1:m
    A(k+1) = sum(sum(Counter>k)); 
    B(k+1) = sum(sum(Counter>=k));
end
XSamp = -log(A./B)/log(Logx);
Vcp_Ka_Kb = [];

if Vcp
    [T1,T2] = find(Counter>m);    
    T1 = cast(T1,'int32'); T2 = cast(T2,'int32');
    %Ka = logical(triu(abs(T1-T1')<=m*tau,1)) + logical(triu(abs(T2-T2')<=m*tau,1));
    Ka = logical(triu(abs(T1-T1')<=m*tau,1) + triu(abs(T2-T2')<=m*tau,1));

    [T1,T2] = find(Counter(:,1:end-m*tau)>=m);
    T1 = cast(T1,'int32'); T2 = cast(T2,'int32');
    Kb = logical(triu(abs(T1-T1')<=(m-1)*tau,1) + triu(abs(T2-T2')<=(m-1)*tau,1));
                           
    Ka = sum(Ka(:));
    Kb = sum(Kb(:));
    CP = A(end)/B(end);
    Vcp = (CP*(1-CP)/B(end)) + (Ka - Kb*(CP^2))/(B(end)^2); 
    
    Vcp_Ka_Kb = [Vcp, Ka, Kb];

end

end

%   Copyright 2024 Matthew W. Flood, EntropyHub
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub