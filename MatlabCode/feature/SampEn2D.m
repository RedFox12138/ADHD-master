function [SE2D, Phi1, Phi2] = SampEn2D(Mat, varargin) 
% SampEn2D  estimates the bidimensional sample entropy of a data matrix.
%
%   [SE2D, Phi1, Phi2] = SampEn2D(Mat) 
% 
%   Returns the bidimensional sample entropy estimate (``SE2D``) and the number
%   of matched sub-matricess (``m: Phi1``, ``m+1: Phi2``) estimated for the data 
%   matrix (``Mat``) using the default parameters: time delay = 1,
%   radius distance threshold = 0.2*SD(``Mat``), logarithm = natural
%   matrix template size = [floor(H/10) floor(W/10)]  
%   (where H and W represent the height (rows) and width (columns) of 
%   the data matrix ``Mat``) 
%   ** The minimum number of rows and columns of ``Mat`` must be > 10.
%
%   [SE2D, Phi1, Phi2] = SampEn2D(Mat, name, value, ...)
% 
%   Returns the bidimensional sample entropy (``SE2D``) estimates for the data
%   matrix (``Mat``) using the specified name/value pair arguments:
% 
%      * ``m``     - Template submatrix dimensions, an integer scalar (for sub-
%        matrix with same height and width) or a two-element vector of
%        integers [height, width] with a minimum value > 1.
%        (default: [floor(H/10) floor(W/10)])
%      * ``tau``   - Time Delay, a positive integer   (default: 1)
%      * ``r``     - Distance Threshold, a positive scalar (default: 0.2*SD(``Mat``))
%      * ``Logx``  - Logarithm base, a positive scalar    (default: natural)
%      * ``Lock``  - By default, ``SampEn2D`` only permits matrices with a maximum
%        size of 128 x 128 to prevent RAM overload. 
%        e.g. For ``Mat`` = [200 x 200], ``m = 3``, and ``tau = 1``, ``SampEn2D`` 
%        creates a vector of 753049836 elements. To enable matrices
%        greater than [128 x 128] elements, set ``'Lock' = false``. (default: true)
% 
%        **WARNING: unlocking the permitted matrix size may cause memory
%        errors that could lead Matlab to crash.**
%
%   See also:
%       SampEn, FuzzEn2D, DistEn2D, XSampEn, MSEn.
% 
%   References:
%      [1] Luiz Eduardo Virgili Silva, et al.,
%           "Two-dimensional sample entropy: Assessing image texture 
%           through irregularity." 
%           Biomedical Physics & Engineering Express
%           2.4 (2016): 045002.
% 


narginchk(1,11)
Mat = squeeze(Mat);
[NL, NW] = size(Mat);
q = inputParser;
Chk = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (mod(x,1)==0);
Chk2 = @(x) isvector(x) && (min(x) > 1) && (max(mod(x,1))==0);
Chk3 = @(x) isnumeric(x) && isscalar(x) && (x > 0);
Chkx = @(x) isnumeric(x) && ismatrix(x) && (min(size(x)) > 10);
addRequired(q,'Mat', Chkx);
addParameter(q,'m',[floor(NL/10) floor(NW/10)],Chk2);
addParameter(q,'tau',1, Chk);
addParameter(q,'r',.2*std(Mat(:),1), Chk3);
addParameter(q,'Logx',exp(1),Chk3);
addParameter(q,'Lock',true,@(x) islogical(x));
parse(q,Mat,varargin{:})
tau = q.Results.tau; r = q.Results.r; %Logx = p.Results.Logx;

if (NL > 128 || NW > 128) && q.Results.Lock
    error(['To prevent memory overload, matrix width & length' ...
        ' must have <= 128 elements. \nTo estimate SampEn2D ', ...
        'for the current matrix (%dx%d) change Lock to false.', ...
        '\CAUTION: unlocking the safe matrix size may cause ', ...
        'MatLab to crash.'],NL,NW)
end
if length(q.Results.m)==1
    mL = q.Results.m; 
    mW = q.Results.m;
else
    mL = q.Results.m(1); 
    mW = q.Results.m(2);
end

NL = NL - mL*tau;
NW = NW - mW*tau;
X = zeros(NL*NW,mL+1,mW+1);
p = 0;
for k = 1:NL
    for n = 1:NW
        p = p+1;
        X(p,:,:) = Mat(k:tau:(mL)*tau+k,n:tau:(mW)*tau+n);
    end
end

if p ~= NL*NW
    warning('Potential error with submatrix division.')
end
Ny = p*(p-1)/2;
if Ny > 300000000
    warning('Number of pairwise distance calculations is %d', Ny)
end

Y1 = zeros(1,p-1);
Y2 = zeros(1,p-1);
for k = 1:p-1
    Temp = max(abs(X(k+1:p,1:mL,1:mW) - X(k,1:mL,1:mW)),[],[2,3]) < r;
    Y1(k) = sum(Temp);    Temp = find(Temp>0) + k;
    Y2(k) = sum(max(abs(X(Temp,:,:) - X(k,:,:)),[],[2,3]) < r);
end

Phi1 = sum(Y1)/Ny;
Phi2 = sum(Y2)/Ny;
SE2D = -log(Phi2/Phi1)/log(q.Results.Logx);
end

%   Copyright 2024 Matthew W. Flood, EntropyHub
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub