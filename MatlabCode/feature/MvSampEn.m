function [MSamp, B0, Bt, B1] = MvSampEn(Data, varargin)
% MvSampEn  estimates the multivariate sample entropy of a multivariate dataset.
% 
%   [MSamp, B0, Bt, B1] = MvSampEn(Data) 
% 
%   Returns the multivariate sample entropy estimate (``MSamp``) and the
%   average number of matched delay vectors (``m``: ``B0``; joint total 
%   ``m+1`` subspace: ``Bt``; all possible ``m+1`` subspaces: ``B1``),
%   from the M multivariate sequences in ``Data`` using the default parameters: 
%   embedding dimension = 2*ones(M,1), time delay = ones(M,1), radius threshold = 0.2,
%   logarithm = natural, data normalization = false, 
% 
%   .. attention::
%          The entropy value returned as ``MSamp`` is estimated using the "full" 
%          method [i.e.  -log(Bt/B0)] which compares delay vectors across all possible ``m+1`` 
%          expansions of the embedding space as applied in [1][2]. Contrary to
%          conventional definitions of sample entropy, this method does not provide a
%          lower bound of 0!!
%          Thus, it is possible to obtain negative entropy values for multivariate 
%          sample entropy, even for stochastic processes...
%        
%          Alternatively, one can calculate ``MSamp`` via the "naive" method, 
%          which ensures a lower bound of 0, by using the average number of matched
%          vectors for an individual ``m+1`` subspace (B1) [e.g. -log(B1(1)/B0)],
%          or the average for all ``m+1`` subspaces [i.e. -log(mean(B1)/B0)].
%        
%   .. note::
%          To maximize the number of points in the embedding process, this algorithm 
%          uses N-max(m*tau) delay vectors and **not** N-max(m)*max(tau) as employed 
%          in [1], [2].
% 
% 
%   [MSamp, B0, Bt, B1] = MvSampEn(Data, name, value, ...)
% 
%   Returns the multivariate sample entropy estimates (``MSamp``) estimated
%   from the M multivariate data sequences in ``Data`` using the specified 
%   name/value pair arguments:
% 
%       :Data:  - Multivariate dataset, NxM matrix of N (>10) observations (rows) and M (cols) univariate data sequences 
%       :m:     - Embedding Dimension, a vector of M positive integers
%       :tau:   - Time Delay, a vector of M positive integers
%       :r:     - Radius Distance threshold, a positive scalar
%       :Norm:  - Normalisation of all M sequences to unit variance, a boolean
%       :Logx:  - Logarithm base, a positive scalar  
% 
%   See also:
%       SampEn, XSampEn, SampEn2D, MvMSEn, MvFuzzEn, MvPermEn, MvDispEn, MvCoSiEn.
% 
%   References:
%      [1] Ahmed Mosabber Uddin, Danilo P. Mandic
%           "Multivariate multiscale entropy: A tool for complexity
%           analysis of multichannel data."
%           Physical Review E 84.6 (2011): 061918.
% 
%      [2] Ahmed Mosabber Uddin, Danilo P. Mandic
%           "Multivariate multiscale entropy analysis."
%           IEEE signal processing letters 19.2 (2011): 91-94.
% 

narginchk(1,11)
p = inputParser;
Data = squeeze(Data);
Dn = size(Data,2);
N = size(Data,1);
Chk = @(x) isnumeric(x) && isvector(x) && (length(x)==Dn) && (min(x)>0) && all(mod(x,1)==0);
Chk2 = @(x) isnumeric(x) && isscalar(x) && (x > 0);

addRequired(p,'Data',@(x) isnumeric(x) && ismatrix(x) && (Dn>1) && N>10);
addParameter(p,'m',2*ones(Dn,1),Chk);
addParameter(p,'tau',ones(Dn,1),Chk);
addParameter(p,'r',.2,Chk2);
addParameter(p,'Logx',exp(1),Chk2);
addParameter(p,'Norm', false, @(x) islogical(x))
parse(p,Data,varargin{:})
m = p.Results.m(:); tau = p.Results.tau(:); 
r = p.Results.r(:); Logx = p.Results.Logx; 
Norm = p.Results.Norm;

if Norm, Data = Data./std(Data,1); end

Nx = N - max((m-1).*tau);
Ny = N - max(m.*tau);
Vex = zeros(Nx,sum(m));
q = 1;
for k = 1:Dn
    for p=1:m(k)
        Vex(:,q) = Data(1+(p-1)*tau(k):Nx+(p-1)*tau(k),  k);
        q = q+ 1;
    end    
end
Count0 = Distx(Vex,r); 
B0 = sum(Count0(:))/(Nx*(Nx-1)/2);  

B1 = zeros(1,Dn);
Temp = cumsum(m);
Vez = [];
for k = 1:Dn
    Sig = Data(1+m(k)*tau(k):Ny+m(k)*tau(k), k);
    Vey = [Vex(1:Ny, 1:Temp(k)) Sig  Vex(1:Ny, Temp(k)+1:end)];
    Vez = [Vez; Vey];
    Count1 = Distx(Vey, r);
    B1(k) = sum(Count1(:))/(Ny*(Ny-1)/2);
end
Count1 = Distx(Vez, r);
Bt = sum(Count1(:))/(Dn*Ny*((Dn*Ny)-1)/2);
 
MSamp = -log(Bt/B0)/log(Logx);
end

function [Counter] = Distx(Vex, r)
    Nt = size(Vex,1);
    Counter = zeros(Nt-1);
    for x=1:Nt-1
        Counter(x,x:end) = all(abs(Vex(x+1:end,:) - Vex(x,:)) <= r, 2);
    end
end

%   Copyright 2024 Matthew W. Flood, EntropyHub
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub