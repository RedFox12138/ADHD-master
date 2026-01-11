function [Perm, Pnorm, cPE] = PermEn(Sig, varargin)
% PermEn  estimates the permutation entropy of a univariate data sequence.
%
%   [Perm, Pnorm, cPE] = PermEn(Sig) 
% 
%   Returns the permuation entropy estimates (``Perm``), the normalised
%   permutation entropy (``Pnorm``) and the conditional permutation entropy
%   (``cPE``) for ``m`` = [1,2] estimated from the data sequence (``Sig``)
%   using the default parameters: embedding dimension = 2, time delay = 1, 
%   logarithm = base 2, normalisation = w.r.t #symbols (``m-1``)
%   Note: using the standard PermEn estimation, ``Perm = 0`` when ``m =
%   1``. It is recommeneded that signal length, N > 5m! 
%   (see [8] and Amigo et al., Europhys. Lett. 83:60005, 2008)
% 
%   [Perm, Pnorm, cPE] = PermEn(Sig, m)
% 
%   Returns the permutation entropy estimates (``Perm``) estimated from the data
%   sequence (``Sig``) using the specified embedding dimensions = [1, ..., ``m``] 
%   with other default parameters as listed above.
%
%   [Perm, Pnorm, cPE] = PermEn(Sig, name, value, ...)
% 
%   Returns the permutation entropy estimates (``Perm``) for dimensions = [1, ..., ``m``]
%   estimated from the data sequence (``Sig``) using the specified name/value pair
%   arguments:
% 
%      * ``m``     - Embedding Dimension, an integer > 1
%      * ``tau``   - Time Delay, a positive integer
%      * ``Logx``  - Logarithm base, a positive scalar (enter 0 for natural log) 
%      * ``Norm``  - Normalisation of Pnorm value, a boolean operator:
%             * false -  normalises w.r.t log(# of permutation symbols [m-1]) - default
%             * true  -  normalises w.r.t log(# of all possible permutations [m!])
% 
%               **Note**: Normalised permutation entropy is undefined for ``m`` = 1.
%               **Note**: When ``Typex = 'uniquant'`` and ``Norm = true``, normalisation
%               is calculated w.r.t. ``log(tpx^m)``
%      * ``Typex`` - Permutation entropy variation, one of the following:
%                {``'uniquant'``, ``'finegrain'``, ``'modified'``, ``'ampaware'``, ``'weighted'``, ``'edge'``, ``'phase'``}
%                See the `EntropyHub guide <https://github.com/MattWillFlood/EntropyHub/blob/main/EntropyHub%20Guide.pdf>`_ for more info on PermEn variants.    
%      * ``tpx``   - Tuning parameter for associated permutation entropy variation.
%              *   [uniquant]  ``tpx`` is the L parameter, an integer > 1 (default =4).           
%              *   [finegrain] ``tpx`` is the alpha parameter, a positive scalar (default = 1)
%              *   [ampaware]  ``tpx`` is the A parameter, a value in range [0 1] (default = 0.5)
%              *   [edge]      ``tpx`` is the r sensitivity parameter, a scalar > 0 (default = 1)
%              *   [phase]     ``tpx`` is the option to unwrap the phase angle of Hilbert-transformed signal, either [] or 1 (default = 0)
%        
%    See the `EntropyHub guide <https://github.com/MattWillFlood/EntropyHub/blob/main/EntropyHub%20Guide.pdf>`_
%    for more info on these permutation entropy variants.
% 
%   See also:
%       XPermEn, MSEn, XMSEn, SampEn, ApEn, CondEn
%   
%   References:
%     [1] Christoph Bandt and Bernd Pompe, 
%           "Permutation entropy: A natural complexity measure for time series." 
%           Physical Review Letters,
%           88.17 (2002): 174102.
% 
%     [2] Xiao-Feng Liu, and Wang Yue,
%           "Fine-grained permutation entropy as a measure of natural 
%           complexity for time series." 
%           Chinese Physics B 
%           18.7 (2009): 2690.
% 
%     [3] Chunhua Bian, et al.,
%           "Modified permutation-entropy analysis of heartbeat dynamics."
%           Physical Review E
%           85.2 (2012) : 021906
% 
%     [4] Bilal Fadlallah, et al.,
%           "Weighted-permutation entropy: A complexity measure for time 
%           series incorporating amplitude information." 
%           Physical Review E 
%           87.2 (2013): 022911.
% 
%     [5] Hamed Azami and Javier Escudero,
%           "Amplitude-aware permutation entropy: Illustration in spike 
%           detection and signal segmentation." 
%           Computer methods and programs in biomedicine,
%           128 (2016): 40-51.
% 
%     [6] Zhiqiang Huo, et al.,
%           "Edge Permutation Entropy: An Improved Entropy Measure for 
%           Time-Series Analysis," 
%           45th Annual Conference of the IEEE Industrial Electronics Soc,
%           (2019), 5998-6003
% 
%     [7] Zhe Chen, et al. 
%           "Improved permutation entropy for measuring complexity of time
%           series under noisy condition." 
%           Complexity 
%           1403829 (2019).
% 
%     [8] Maik Riedl, Andreas Müller, and Niels Wessel,
%           "Practical considerations of permutation entropy." 
%           The European Physical Journal Special Topics 
%           222.2 (2013): 249-262.
%
%     [9] Kang Huan, Xiaofeng Zhang, and Guangbin Zhang,
%          "Phase permutation entropy: A complexity measure for nonlinear time
%          series incorporating phase information."
%          Physica A: Statistical Mechanics and its Applications
%          568 (2021): 125686.
% 

narginchk(1,13)
Sig = squeeze(Sig);

p = inputParser;
Chk = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (mod(x,1)==0);
Chkx = @(x) isnumeric(x) && isscalar(x) && (x > 1) && (mod(x,1)==0);
Chk2 = @(x) isscalar(x) && (x > 0);
Chk3 = {'uniquant','finegrain','modified','ampaware','weighted','edge','phase'};
addRequired(p,'Sig',@(x) isnumeric(x) && isvector(x) && (length(x) > 10));
addOptional(p,'m',2,Chkx);
addParameter(p,'tau',1,Chk);
addParameter(p,'Typex','none',@(x) (ischar(x) || isstring(x)) && any(validatestring(lower(x),Chk3)));
addParameter(p,'Logx',2,@(x) isscalar(x) && (x >= 0));
addParameter(p,'Norm',false,@(x) islogical(x));
addParameter(p,'tpx',[],Chk2);
parse(p,Sig,varargin{:})
m = p.Results.m; tau = p.Results.tau; Logx = p.Results.Logx; 
Typex = p.Results.Typex; tpx = p.Results.tpx; Norm = p.Results.Norm; 

if strcmp(lower(Typex), 'phase')
    Sig = angle(hilbert(Sig));
    if tpx == 1
        Sig = unwrap(Sig);
    end
end

if Logx == 0
    Logx = exp(1);
end
N = length(Sig);
Sx = zeros(N,m);
Perm = zeros(1,m);
Pnorm = zeros(1,m);
for k = 1:m
    Nx = N-(k-1)*tau;
    Sx(1:Nx,k) = Sig(1+(k-1)*tau:N);
    [TempUQ, Temp] = sort(Sx(1:Nx,1:k),2,'ascend');
    Px = perms(1:k);
    Counter = zeros(1,length(Px));
    
    switch lower(Typex)        
        case 'uniquant'
            %Temp = sort(Sx(1:Nx,1:k),2,'ascend');
            S = zeros(size(TempUQ));
            if isempty(tpx)
                tpx = 4;
            elseif tpx <= 1
                error('Xi parameter must be an integer > 1');
            elseif tpx - floor(tpx) ~=0
                error('Xi parameter must be an integer');
            end
            delta = range(Sig)/tpx;
            S(:,1) = discretize(TempUQ(:,1),[min(Sig):delta:max(Sig)]);
            if k > 1
                S(:,2:k) = S(:,1) + floor((TempUQ(:,2:k) - TempUQ(:,1))/delta);
            end
            Px = unique(S,'rows');
            Counter = zeros(1,size(Px,1));
            for n = 1:size(Px,1)
                Counter(n) = sum(~any(S - Px(n,:),2));
                %Counter(n) = sum(any(S - Px(n,:),2)==0);
            end
            Counter(Counter==0)=[];
            Ppi = Counter/sum(Counter);
            Norm = 3;          
            clear S L delta n
            
        case 'finegrain'
            if k > 1
                if isempty(tpx)
                    tpx = 1;
                elseif tpx <= 0
                    error('Alpha parameter must be greater than 0')
                end
                q =  floor(max(abs(diff(Sx(1:Nx,1:k),[],2)),[],2)/(tpx*std(abs(diff(Sig)),1)));
                Temp = [Temp q];
                Px = unique(Temp,'rows');
                Counter = zeros(1,size(Px,1));
                for n = 1:size(Px,1)
                    Counter(n) = sum(~any(Temp - Px(n,:),2));
                    %Counter(n) = sum(any(Temp - Px(n,:),2)==0);
                end
                Counter(Counter==0)=[];
                Ppi = Counter/sum(Counter);
                clear q n qt
            else
                Ppi = 1;
            end
            
        case 'modified'
            Tx = (diff(sort(Sx(1:Nx,1:k),2),[],2)==0);
            for km = 1:k-1
                Temp(Tx(:,km),km+1) = Temp(Tx(:,km),km);
            end            
            Px = unique(Temp,'rows');
            Counter = zeros(1,size(Px,1));
            for n = 1:size(Px,1)
                Counter(n) = sum(~any(Temp - Px(n,:),2));
              %  Counter(n) = sum(any(Temp - Px(n,:),2)==0);
            end
            Counter(Counter==0)=[];
            Ppi = Counter/sum(Counter);
            clear Tx km
            
        case 'weighted'
            if k > 1
                Wj = var(Sx(1:Nx,1:k),1,2);
                for n = 1:size(Px,1)
                    Counter(n) = sum(Wj(~any(Temp - Px(n,:),2)));
                    %Counter(n) = sum(Wj(any(Temp - Px(n,:),2)==0));
                end
                Counter(Counter==0)=[];
                Ppi = Counter/sum(Wj);
                clear Wj n
            else
                Ppi = 1;
            end
            
        case 'ampaware'
            if k > 1
                if isempty(tpx)
                    tpx = 0.5;
                elseif tpx<0 || tpx>1
                    error('The A parameter (tpx) must be in the range [0 1]')
                end
                AA = sum(abs(Sx(1:Nx,1:k)),2); 
                AB = sum(abs(diff(Sx(1:Nx,1:k),[],2)),2);
                Ax = (tpx*AA/k) + ((1-tpx)*AB/(k-1));                
                for n = 1:size(Px,1)
                    Counter(n) = sum(Ax(~any(Temp-Px(n,:),2)));
                   % Counter(n) = sum(Ax(any(Temp-Px(n,:),2)==0));
                end
                Counter(Counter==0)=[];
                Ppi = Counter/sum(Ax);
            else
                Ppi = 1;
            end
            clear AA AB Ax
                    
        case 'edge'
            if isempty(tpx)
                tpx = 1;
            elseif tpx <=0 
                error('r sensitivity parameter (tpx) must be > 0 for edge permutation entropy')
            end
            if k > 1
                for n = 1:size(Px,1)
                    Tx = diff(Sx(~any(Temp - Px(n,:),2),1:k),[],2);
                    Counter(n) = sum(mean(hypot(Tx,1),2).^tpx);
                end
                Counter(Counter==0)=[];
                Ppi = Counter/sum(Counter);
            else Ppi = 1;
            end
            
        otherwise
            for n = 1:size(Px,1)
                Counter(n) = sum(~any(Temp - Px(n,:),2));
            end
            Counter(Counter==0)=[];
            Ppi = Counter/sum(Counter);
    end
    
    if round(sum(Ppi),3)~=1
        warning('Potential error with probability calculation')
    end
    
    Perm(k) = -sum(Ppi.*(log(Ppi)/log(Logx)));
    if Norm
        if Norm == 3
            Pnorm(k) = Perm(k)/(log(tpx^k)/log(Logx));
        else          
            Pnorm(k) = Perm(k)/(log(factorial(k))/log(Logx));
        end
 
    else
        Pnorm(k) = Perm(k)/(k-1);
    end
    
    clear Temp Ppi Counter Nx Px
end

cPE = diff(Perm);
end

%   Copyright 2024 Matthew W. Flood, EntropyHub
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub