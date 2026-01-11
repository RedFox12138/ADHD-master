function [Perm2D] = PermEn2D(Mat, varargin) % m, tau, Logx
% PermEn2D  estimates the bidimensional permutation entropy of a data matrix.
%
%   [Perm2D] = PermEn2D(Mat) 
% 
%   Returns the bidimensional permutation entropy estimate (``Perm2D``) estimated for 
%   the data matrix (``Mat``) using the default parameters: time delay = 1,
%   logarithm = natural, template matrix size = [floor(H/10) floor(W/10)]  
%   (where H and W represent the height (rows) and width (columns) of the data matrix ``Mat``) 
%   ** The minimum number of rows and columns of ``Mat`` must be > 10.
%
%   [Perm2D] = PermEn2D(Mat, name, value, ...)
% 
%   Returns the bidimensional permutation entropy (``Perm2D``) estimates for the data
%   matrix (``Mat``) using the specified name/value pair arguments:
% 
%      * ``m``     - Template submatrix dimensions, an integer scalar (for sub-
%        matrix with same height and width) or a two-element vector of
%        integers [height, width] with a minimum value > 1.
%        (default: [floor(H/10) floor(W/10)])
%      * ``tau``   - Time Delay, a positive integer        [default: 1]  
%      * ``Norm``  - Normalization of the PermEn2D value by maximum Shannon
%        entropy (Smax = log((mx*my)!)         [default: true]                    
%      * ``Logx``  - Logarithm base, a positive scalar  [default: natural]
%      * ``Lock``  - By default, ``PermEn2D`` only permits matrices with a maximum
%        size of 128 x 128 to prevent RAM overload. 
%        e.g. For ``Mat`` = [200 x 200], ``m = 3``, and ``tau = 1``, ``PermEn2D`` 
%        creates a vector of 753049836 elements. To enable matrices
%        greater than [128 x 128] elements, set ``'Lock' = false``. (default: true)
% 
%        **WARNING: unlocking the permitted matrix size may cause memory
%        errors that could lead Matlab to crash.**
% 
%    .. note:: 
%
%       The original bidimensional permutation entropy algorithms [1][2] do not account for equal-valued elements of the embedding matrices.
%       To overcome this, PermEn2D uses the lowest common rank for such instances. For example, given an embedding matrix A where,
%         :A: 
%         |     [3.4  5.5  7.3]         
%         |     [2.1  6    9.9]       
%         |     [7.3  1.1  2.1]      
%  
%       would normally be mapped to an ordinal pattern like so,      
%
%               |       [3.4  5.5  7.3  2.1  6  9.9  7.3  1.1  2.1] =>
%               |       [ 8    4    9    1   2   5    3    7    6 ]
%
%       However, indices 4 & 9, and 3 & 7 have the same values, 2.1
%       and 7.3 respectively. Instead, PermEn2D uses the ordinal pattern
%       [ 8    4    4    1   2   5    3    3    6 ]
%       where the lowest rank (4 & 3) are used instead (of 9 & 7). 
%       Therefore, the number of possible permutations is no longer 
%       (mx*my)!, but (mx*my)^(mx*my). Here, the PermEn2D value is 
%       normalized by the maximum Shannon entropy (Smax = log((mx*my)!) 
%       ``assuming that no equal values are found in the permutation
%       motif matrices``, as presented in [1].
% 
% 
%   See also:
%       SampEn2D, DistEn2D, FuzzEn2D, DispEn2D, PermEn
% 
%   References:
%     [1] Haroldo Ribeiro et al.,
%           "Complexity-Entropy Causality Plane as a Complexity Measure 
%           for Two-Dimensional Patterns"
%           PLoS ONE (2012), 7(8):e40689, 
% 
%     [2] Luciano Zunino and Haroldo Ribeiro,
%           "Discriminating image textures with the multiscale
%           two-dimensional complexity-entropy causality plane"
%           Chaos, Solitons and Fractals,  91:679-688 (2016)
% 
%     [3] Matthew Flood and Bernd Grimm,
%           "EntropyHub: An Open-source Toolkit for Entropic Time Series Analysis"
%           PLoS ONE (2021) 16(11): e0259448.

narginchk(1,9)
Mat = squeeze(Mat);
[NL, NW] = size(Mat);
q = inputParser;
Chk = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (mod(x,1)==0);
Chk2 = @(x) isvector(x) && (min(x) > 1) && (max(mod(x,1))==0);
Chk3 = @(x) isnumeric(x) && isvector(x) && (x(1) >= 0);
Chkx = @(x) isnumeric(x) && ismatrix(x) && (min(size(x)) > 10);

addRequired(q,'Mat', Chkx);
addParameter(q,'m',[floor(NL/10) floor(NW/10)],Chk2);
addParameter(q,'tau', 1, Chk);
addParameter(q,'Logx',exp(1),Chk3);
addParameter(q,'Norm',true,@(x) islogical(x));
addParameter(q,'Lock',true,@(x) islogical(x));
parse(q,Mat,varargin{:})
tau = q.Results.tau; 
Logx = q.Results.Logx;

if (NL > 128 || NW > 128) && q.Results.Lock
        error(['To prevent memory errors, matrix width & length' ...
            ' must have <= 128 elements. \nTo estimate PermEn2D ', ...
            'for the currect matrix (%dx%d) change Lock to ''unlocked''.', ...
            '\nCaution: unlocking the safe matrix size may cause ', ...
            'MatLab to crash.'],NL,NW)
end
if length(q.Results.m)==1
    mL = q.Results.m; 
    mW = q.Results.m;
else
    mL = q.Results.m(1); 
    mW = q.Results.m(2);
end

NL = NL - (mL-1)*tau;
NW = NW - (mW-1)*tau;
Temp = Mat(1:tau:(mL-1)*tau+1,1:tau:(mW-1)*tau+1);
[Sord, Dict] = sort(Temp(:), 'ascend');
if any(diff(Sord')==0)
    for x = find(diff(Sord')==0)+1
        Dict(x) = Dict(x-1);        
    end
end
Counter = 0;

for k = 1:NL
    for n = 1:NW        
        Temp = Mat(k:tau:(mL-1)*tau+k,n:tau:(mW-1)*tau+n);
        [Sord, Dx] = sort(Temp(:),'ascend');
        if any(diff(Sord')==0)
            for x = find(diff(Sord')==0)+1
                Dx(x) = Dx(x-1);     
            end
        end     
                
        if any(~any(Dict - Dx))
            Counter = Counter + ~any(Dict - Dx);   
        else
            Dict = [Dict Dx];
            Counter = [Counter 1];            
        end
    end
end

if sum(Counter) ~= NW*NL
   warning('Potential error with permutation comparisons.') 
end

Pi = Counter/sum(Counter);
Perm2D = -sum(Pi.*log(Pi)/log(Logx));
if q.Results.Norm
    Perm2D = Perm2D/(log(factorial(mL*mW))/log(Logx));
end
end

%   Copyright 2024 Matthew W. Flood, EntropyHub
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub