function [MSx, CI] = cMvMSEn(Data, Mobj, varargin)
% cMvMSEn  returns the composite and refined-composite multivariate multiscale entropy of a multivariate dataset.
%
%   [MSx, CI] = cMvMSEn(Data, Mobj)
%
%   Returns a vector of composite multivariate multiscale entropy values
%   (``MSx``) and the complexity index (``CI``) of the data sequences ``Data``
%   using the parameters specified by the multiscale object (``Mobj``)
%   over 3 temporal scales with coarse-graining (default).
% 
%   .. caution::
%          By default, the ``MvSampEn`` and ``MvFuzzEn`` multivariate entropy algorithms
%          estimate entropy values using the "full"  method by comparing delay vectors 
%          across all possible ``m+1`` expansions of the embedding space as applied in [1].
%          These methods are not lower-bounded to 0, like most entropy algorithms,
%          so ``cMvMSEn`` may return negative entropy values if the base multivariate 
%          entropy function is ``MvSampEn`` and ``MvFuzzEn``, even for stochastic processes...
%
%
%   [MSx, CI] = cMvMSEn(Data, Mobj, name, value, ...)
%
%   Returns a vector of composite multivariate multiscale entropy values
%   (``MSx``) and the complexity index (``CI``) of the data sequences
%   ``Data`` using the parameters specified by  the multiscale object
%   (``Mobj``) and the following name/value pair arguments:
%
%       :Scales:   - Number of temporal scales, an integer > 1   (default: 3)
%       :Refined:  - Refined-composite MSEn method. 
%           When ``Refined == true`` and the  entropy function specified by ``Mobj`` is ``MvSampEn`` or ``MvFuzzEn``, ``cMvMSEn``
%           returns the refined-composite multivariate nmultiscale entropy (rcMSEn).  (default: false)
%       :Plotx:    - When ``Plotx == true``, returns a plot of the entropy value at each time scale (i.e. the multiscale entropy curve) (default: false)
%
%   See also:
%       MSobject, MSEn, rMSEn, hMSEn, XMSEn, cXMSEn, SampEn, ApEn,
%
%   References:
%     [1] Shuen-De Wu, et al.,
%           "Time series analysis using composite multiscale entropy."
%           Entropy
%           15.3 (2013): 1069-1084.
%
%     [2] Shuen-De Wu, et al.,
%           "Analysis of complex time series using refined composite
%           multiscale entropy."
%           Physics Letters A
%           378.20 (2014): 1369-1374.
%
%     [3] Ahmed Mosabber Uddin, Danilo P. Mandic
%           "Multivariate multiscale entropy: A tool for complexity
%           analysis of multichannel data."
%           Physical Review E 84.6 (2011): 061918.
%
%     [4] Ahmed Mosabber Uddin, Danilo P. Mandic
%           "Multivariate multiscale entropy analysis."
%           IEEE signal processing letters 19.2 (2011): 91-94.
%
%     [5] Azami, Alberto Fernández, Javier Escudero.
%           "Refined multiscale fuzzy entropy based on standard deviation for
%           biomedical signal analysis."
%           Medical & biological engineering & computing 55 (2017): 2037-2052.
%

narginchk(2,8)
Data = squeeze(Data);
Dn = size(Data,2);
p = inputParser;
Chk2 = @(x) islogical(x) && (any(strcmp(func2str(Mobj.Func),["MvSampEn","MvFuzzEn"])) || (x==false));

addRequired(p,'Data',@(x) isnumeric(x) && ismatrix(x) && (size(x,1)>10) && Dn>1);
addRequired(p,'Mobj',@(x) isstruct(x));
addParameter(p,'Scales', 3, @(x) isscalar(x) && isnumeric(x) && (mod(x,1)==0) && (x>1));
addParameter(p,'Refined',false,Chk2);
addParameter(p,'Plotx',false,@(x) islogical(x));
parse(p, Data, Mobj, varargin{:})
MSx = zeros(1,p.Results.Scales);
Fields = fieldnames(Mobj);
Y = struct2cell(Mobj);
C = [Fields(2:end),Y(2:end)].';

assert(startsWith(func2str(Mobj.Func), "Mv"),...
    "Multivariate entropy estimator is a not a multivariate method!")

if p.Results.Refined
    if  strcmp(func2str(Mobj.Func), 'MvFuzzEn')
        Tx = 1;
    elseif strcmp(func2str(Mobj.Func), 'MvSampEn')
        Tx = 0;
    end
    if  any(find(strcmp(C(1,:),'Logx')))
        Logx = Mobj.Logx;
    else 
        Logx = exp(1);
    end
else   
    Tx = 0;
end

for T = 1:p.Results.Scales
    Temp = modified(Data, T, Tx, Dn);
    N = T*floor(size(Temp,1)/T);
    Ma = zeros(1,T);
    Mb = zeros(1,T);
    for k = 1:T
        fprintf(' .')
        if p.Results.Refined
            [~, Ma(k), Mb(k)] = Mobj.Func(Temp(k:T:N,:),C{:});
        else
            Ma(k) = Mobj.Func(Temp(k:T:N,:),C{:});
        end
    end

    if p.Results.Refined
        MSx(T) = -log(sum(Mb)/sum(Ma))/log(Logx);
    else
        MSx(T) = mean(Ma);
    end
    clear Ma Mb Temp
end

CI = sum(MSx);
fprintf(' .\n')
if any(isnan(MSx))
    fprintf('\nSome entropy values may be undefined.')
end

if p.Results.Plotx
    if p.Results.Refined
        strx = 'Refined-Composite Multivariate';
    else
        strx = 'Composite Multivariate';
    end
    stry = func2str(Y{1});

    figure, hold on
    plot(1:p.Results.Scales,MSx,'color',[8 63 77]/255,'LineWidth',3)
    scatter(1:p.Results.Scales,MSx,60,[1 0 1],'filled')
    xlabel('Scale Factor','FontSize',12,'FontWeight','bold','Color',[7 54 66]/255)
    ylabel('Entropy Value','FontSize',12,'FontWeight','bold','Color',[7 54 66]/255)
    title(sprintf('%s Multiscale %s ',strx,...
        stry(3:end)),'FontSize',16,'FontWeight','bold','Color',[7 54 66]/255)
end

end

function [Y] = modified(Z, sx, Tx, Dn)
    if Tx==1
        Y = movstd(Z,sx,1,'Endpoints','discard');
    else
        Y = zeros(size(Z,1)-sx+1, Dn);
        for k = 1:Dn
            Y(:,k) = conv(Z(:,k),ones(1,sx),'valid')/sx;
        end
    end
end

%   Copyright 2024 Matthew W. Flood, EntropyHub
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub