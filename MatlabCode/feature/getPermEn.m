function permEn = getPermEn(x,varargin)
% getPermEn  estimates the permutation entropy of a univariate data sequence.
%
%   permEn = getPermEn(x) 
% 
%   Returns the normalised permuation entropy estimates `PermEn`
%   for `m` = 2 estimated from the data sequence `x`
%   using the default parameters: 
%       embedding dimension = 2, time delay = 1, logarithm = base exp(1)
% 
%   permEn = getPermEn(x,m) 
% 
%   Returns the permutation entropy estimates `PermEn` estimated from the data
%   sequence `x` using the specified embedding dimensions = `m`  with 
%   other default parameters as listed above.
%
%   PermEn= PermEn(x,name,value,...)
% 
%   Returns the permutation entropy estimates `PermEn` for dimensions = `m`
%   estimated from the data sequence `x` using the specified name/value pair
%   arguments:
% 
%      `m`    - Embedding Dimension, an integer > 1
%      `tau`   - Time Delay, a positive integer
%      `logx`  - Logarithm base, a positive scalar (enter 0 for natural log) 
%      `variant` - Permutation entropy variation, one of the following:
%           {'default', 'finegrain', 'FGPE','modified','MPE','ampaware','AAPE',...
%           'weighted','WPE','edge','EPE','uniquant','IPE'}
%      `alpha`   - Tuning parameter for associated permutation entropy variation.
%           [finegrain]: `alpha` is the alpha parameter, a positive scalar (default = 1)
%           [ampaware]: `alpha` is the A parameter, a value in range [0 1] (default = 0.5)
%           [edge]: `alpha` is the r sensitivity parameter, a scalar > 0 (default = 1)
%           [uniquant]: `alpha` is the L parameter, an integer > 1 (default = 4).     

%    See the [信息熵系列#5——PermEn排列熵及Matlab实现](`https://zhuanlan.zhihu.com/p/573059600`)
%    for more info on these permutation entropy variants.
% 
%   See also:
%       getApEn, getSampEn, getFuzzyEn
%
%   References:
% 	[1] Christoph Bandt, Bernd Pompe. 
%       Permutation entropy: a natural complexity measure for time series[J]. 
%       Phys Rev Lett., 2002, 88(17):174102. 
%       DOI: 10.1103/PhysRevLett.88.174102.
%   [2] Liu Xiaofeng, Wang Yue. 
%       Fine-grained permutation entropy as a measure of 
%       natural complexity for time series[J]. 
%       Chinese Physics B. 2009, 18(7): 2690-2695.
%       DOI: 10.1088/1674-1056/18/7/011. 
%   [3] Chunhua Bian, Chang Qin, Qianli D. Y. Ma, et al. 
%       Modified permutation-entropy analysis of heartbeat dynamics[J]. 
%       Physical review. E, Statistical, nonlinear, and soft matter physics, 
%       2012, 85(2 Pt 1):021906.  
%       DOI: 10.1103/PhysRevE.85.021906.
%  [4] Bilal Fadlallah, Badong Chen, Andreas Keil, et al. 
%       Weighted-permutation entropy: A complexity measure for 
%       time series incorporating amplitude information[J]. 
%       Physical review. E, Statistical, nonlinear, and soft matter physics, 
%       2013, 87(2): 022911. 
%       DOI: 10.1103/PhysRevE.87.022911. 
%   [5] Hamed Azami, Javier Escudero. 
%       Amplitude-aware permutation entropy: 
%       Illustration in spike detection and signal segmentation[J]. 
%       Computer Methods and Programs in Biomedicine, 2016, 128: 40-51. 
%       DOI: 10.1016/j.cmpb.2016.02.008.
%   [6] Zhiqiang Huo, Yu Zhang, Lei Shu, et al. 
%       Edge Permutation Entropy: An Improved Entropy Measure for 
%       Time-Series Analysis[J]. 
%       IECON 2019 - 45th Annual Conference of the IEEE Industrial 
%       Electronics Society, 2019, 1:5998-6003. 
%       DOI: 10.1109/IECON.2019.8927449.
%   [7] Zhe Chen, Yaan Li, Hongtao Liang, et al. 
%       Improved Permutation Entropy for Measuring Complexity of 
%       Time Series under Noisy Condition[J]. Complex, 2019(2019). 
%       DOI:10.1155/2019/1403829.
%   [8] M. Riedl, A. M$\ddot u$ller, and N. Wessel. 
%       Practical considerations of permutation entropy[J]. 
%       European Physical Journal Special Topics, 2013, 222(2): 249–262. 
%       DOI: 10.1140/epjst/e2013-01862-7.
%
%   If you have any questions, please contact
%       C.G. Huang via hcg.001@163.com or comment on 
%       [信息熵系列#5——PermEn排列熵及Matlab实现](`https://zhuanlan.zhihu.com/p/573059600`)


narginchk(1,11)
x = squeeze(x);
x = x(:);

% Parse inputs
p = inputParser;
chk = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (mod(x,1)==0);
chkx = @(x) isnumeric(x) && isscalar(x) && (x > 1) && (mod(x,1)==0);
chk2 = {'default',...
    'finegrain','fgpe',...
    'modified','mpe',...
    'weighted','wpe',...
    'ampaware','aape',...
    'edge','epe',...
    'uniquant','ipe'};
addRequired(p,'x',@(x) isnumeric(x) && isvector(x) && (length(x) > 10));
addOptional(p,'m',3,chkx);
addParameter(p,'tau',1,chk);
addParameter(p,'variant','default',...
    @(x) ischar(x) && any(validatestring(lower(x),chk2)));
addParameter(p,'logx',exp(1),@(x) isscalar(x) && (x > 0));
addParameter(p,'alpha',1,@(x) isscalar(x) && (x > 0));
parse(p,x,varargin{:})
m = p.Results.m; tau = p.Results.tau;
alpha = p.Results.alpha;
variant = lower(p.Results.variant); 
if strcmp(variant,'fgpe')
    variant = 'finegrain';
end
if strcmp(variant,'mpe')
    variant = 'modified';
end
if strcmp(variant,'wpe')
    variant = 'weighted';
end
if strcmp(variant,'aape')
    variant = 'ampaware';
end
if strcmp(variant,'epe')
    variant = 'edge';
end
if strcmp(variant,'ipe')
    variant = 'uniquant';
end

% Improved efficiency 
%   by changing the double-precision float  array to single-precision
method = 'single'; % 'single' or 'double'
switch method
    case 'single'
        x = single(x);

end

% Generate short series blocks
lenx = length(x);
cols = lenx-(m-1)*tau;
dataMat = zeros(m,cols,method);
if m < cols
    for ii = 1:m
        dataMat(ii,:) = x((ii-1)*tau+1:(ii-1)*tau+cols);
    end
else
    for ii = 1:cols
        dataMat(:,ii) = x(ii:tau:ii+m*tau-1);
    end
end


switch variant
    case 'default'
        % Sort series and get sorting index `ia`
        [~,ia] = sort(dataMat);
        % Unique sorting index `ia` and get its sorting index `ib` and 
        %   index `ic` of unique value
        [~,ib,ic]=unique(ia','rows');
        % Compute the probability of each sort
        p = histcounts(ic,length(ib))/cols;
        % Compute permutation entropy and nomalization
        permEn = -sum(p.*log(p))/log(factorial(m));
        
    case 'finegrain'
        [~,ia] = sort(dataMat);
        
        % Factor q is introduced to quantify the difference between
        %   the neighbouring elements in the matrix `dataMat`
        q = floor(max(abs(diff(dataMat)),1)/std(abs(diff(x)))/alpha);
        
        [~,ib,ic]=unique([ia',q'],'rows');
        p = histcounts(ic,length(ib))/cols;
        permEn = -sum(p.*log(p))/log(factorial(m));
        
    case 'modified'
        [id,ia] = sort(dataMat);
        
        % Locate the indices of equal values
        izero = diff(id)==0;
        
        % Reset the indices of equal values via the smallest one
        iaPre = ia(1:end-1,:);
        iaPost = ia(2:end,:);
        iaPost(izero) = iaPre(izero);
        ia(2:end,:) = iaPost;
        
        [~,ib,ic]=unique(ia','rows');
        p = histcounts(ic,length(ib))/cols;
        permEn = -sum(p.*log(p))/log(factorial(m));
        
    case 'weighted'
        % Compute weight
        w = var(dataMat,1); w = w/sum(w);
        
        [~,ia] = sort(dataMat); ia = ia';
        iA=unique(ia,'rows'); nUnique = size(iA,1);
        p = zeros(nUnique,1);
        for ii=1:nUnique
            ind = sum(abs(ia-iA(ii,:)),2)==0;
            p(ii) = sum(w(ind));
        end
        permEn = -sum(p.*log(p))/log(factorial(m));
        
    case 'ampaware'
        % Compute weight
        w = alpha*mean(abs(dataMat))+(1-alpha)*mean(abs(diff(dataMat))); 
        w = w/sum(w);
        
        [~,ia] = sort(dataMat); ia = ia';
        iA=unique(ia,'rows'); nUnique = size(iA,1);
        p = zeros(nUnique,1);
        for ii=1:nUnique
            ind = sum(abs(ia-iA(ii,:)),2)==0;
            p(ii) = sum(w(ind));
        end
        permEn = -sum(p.*log(p))/log(factorial(m));
        
    case 'edge'
        % Compute weight
        w = (mean(hypot(diff(dataMat),1))).^alpha; 
        w = w/sum(w);
        
        [~,ia] = sort(dataMat); ia = ia';
        iA=unique(ia,'rows'); nUnique = size(iA,1);
        p = zeros(nUnique,1);
        for ii=1:nUnique
            ind = sum(abs(ia-iA(ii,:)),2)==0;
            p(ii) = sum(w(ind));
        end
        permEn = -sum(p.*log(p))/log(factorial(m));
        
    case 'uniquant'
        % Uniform quantization for `dataMat`
        delta = range(x)/alpha;
        s = dataMat;
        s(1,:) = discretize(dataMat(1,:),min(x):delta:max(x));
        s(2:end,:) = s(1,:) + floor((dataMat(2:end,:) - dataMat(1,:))/delta);
        
        [~,ib,ic]=unique(s','rows');
        p = histcounts(ic,length(ib))/cols;
        permEn = -sum(p.*log(p))/log(alpha^m);
end
end