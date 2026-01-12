function [MSx, CI] = cMSEn(Sig, Mobj, varargin)
% cMSEn  returns the composite multiscale entropy of a univariate data sequence.
%
%   [MSx, CI] = cMSEn(Sig, Mobj) 
% 
%   Returns a vector of composite multiscale entropy values (``MSx``) for the data 
%   sequence (``Sig``) using the parameters specified by the multiscale object 
%   (``Mobj``) using the composite multiscale entropy method (cMSE) over 3 temporal
%   scales.
%    
%   [MSx, CI] = cMSEn(Sig, Mobj, name, value, ...)
% 
%   Returns a vector of composite multiscale entropy values (``MSx``) for the 
%   data sequence (``Sig``) using the parameters specified by the multiscale 
%   object (``Mobj``) and the following name/value pair arguments:
% 
%       * ``Scales``   - Number of temporal scales, an integer > 1   (default: 3)
%       * ``RadNew``   - Radius rescaling method, an integer in the range [1 4].
%         When the entropy specified by ``Mobj`` is ``SampEn`` or ``ApEn``, 
%         RadNew rescales the radius threshold in each sub-sequence
%         at each time scale (Xt). If a radius value (``r``) is specified 
%         by ``Mobj``, this becomes the rescaling coefficient, otherwise
%         it is set to 0.2 (default). The value of ``RadNew`` specifies
%         one of the following methods:
%                   * [1]    Standard Deviation          - r*std(Xt)
%                   * [2]    Variance                    - r*var(Xt)
%                   * [3]    Mean Absolute Deviation     - r*mad(Xt)
%                   * [4]    Median Absolute Deviation   - r*mad(Xt,1)
%       * ``Refined``  - Refined-composite MSEn method. When ``Refined == true`` and the 
%         entropy function specified by ``Mobj`` is ``SampEn`` or ``FuzzEn``, ``cMSEn``
%         returns the refined-composite multiscale entropy (rcMSEn).  (default: false)
%       * ``Plotx``    - When ``Plotx == true``, returns a plot of the entropy value at 
%         each time scale (i.e. the multiscale entropy curve) (default: false)
% 
%   See also:
%       MSobject, MSEn, rMSEn, hMSEn, XMSEn, cXMSEn, SampEn, ApEn, 
%  
%   References:
%     [1] Madalena Costa, Ary Goldberger, and C-K. Peng,
%           "Multiscale entropy analysis of complex physiologic time series."
%           Physical review letters
%           89.6 (2002): 068102.
% 
%     [2] Vadim V. Nikulin, and Tom Brismar,
%           "Comment on “Multiscale entropy analysis of complex physiologic
%           time series”." 
%           Physical review letters 
%           92.8 (2004): 089803.
% 
%     [3] Madalena Costa, Ary L. Goldberger, and C-K. Peng. 
%           "Costa, Goldberger, and Peng reply." 
%           Physical Review Letters
%           92.8 (2004): 089804.
% 
%     [4] Shuen-De Wu, et al.,
%           "Time series analysis using composite multiscale entropy." 
%           Entropy 
%           15.3 (2013): 1069-1084.
% 
%     [5] Shuen-De Wu, et al.,
%           "Analysis of complex time series using refined composite 
%           multiscale entropy." 
%           Physics Letters A 
%           378.20 (2014): 1369-1374.
% 
%     [6] Azami, Alberto Fernández, and Javier Escudero. 
%           "Refined multiscale fuzzy entropy based on standard deviation 
%           for biomedical signal analysis." 
%           Medical & biological engineering & computing 55 (2017): 2037-2052.
% 

narginchk(2,10)
Sig = squeeze(Sig);
p = inputParser;
Chk2 = @(x) islogical(x) && ((x==true) && any(validatestring(func2str(Mobj.Func),{'SampEn','FuzzEn'}))) || (x==false);
addRequired(p,'Sig',@(x) isnumeric(x) && isvector(x) && (length(x)>10));
addRequired(p,'Mobj',@(x) isstruct(x));
addParameter(p,'Scales',3,@(x) isnumeric(x) && (length(x)==1) && (x>1));
addParameter(p,'RadNew',0,@(x) x==0 || (ismember(x,1:4) && ...
    any(validatestring(func2str(Mobj.Func),{'SampEn';'ApEn'}))));
addParameter(p,'Refined',false,Chk2);
addParameter(p,'Plotx',false,@(x) islogical(x));
parse(p,Sig, Mobj, varargin{:})
MSx = zeros(1,p.Results.Scales);
RadNew = p.Results.RadNew;

if strcmp(func2str(Mobj.Func),'SampEn'),  Mobj.Vcp = false; end

Fields = fieldnames(Mobj);
Y = struct2cell(Mobj);
C = [Fields(2:end),Y(2:end)].';

assert(~startsWith(lower(func2str(Mobj.Func)), 'x'),...
    "Base entropy estimator is a cross-entropy method. To perform (refined-)composite multiscale CROSS-entropy estimation, use cXMSEn.")

if p.Results.Refined && strcmp(func2str(Mobj.Func), 'FuzzEn')
    Tx = 1;
    if  any(find(strcmp(C(1,:),'Logx')))
        Logx = Mobj.Logx;
    else Logx = exp(1);
    end

elseif p.Results.Refined && strcmp(func2str(Mobj.Func), 'SampEn')
    Tx = 0;
    if  any(find(strcmp(C(1,:),'Logx')))
        Logx = Mobj.Logx;
    else Logx = exp(1);
    end
else
    Tx = 0;
end

if RadNew
    switch RadNew
        case 1
            Rnew = @(x) std(x,1);
        case 2
            Rnew = @(x) var(x,1);
        case 3            
            Rnew = @(x) mad(x);
        case 4
            Rnew = @(x) mad(x,1);
    end
    
    try
        C_Loc = find(strcmp(C(1,:),'r'));
        Cx = C{2,C_Loc};
    catch
        Cy = {'Standard Deviation';'Variance';...
            'Mean Abs Deviation';'Median Abs Deviation'};
        warning(['No radius value provided.\n' ...
            'Default set to 0.2*(%s) of each new time-series.'],Cy{RadNew})
        C_Loc = size(C,1) + 1;
        %C_Loc = length(C(1,:)) + 1;
        C{1,C_Loc} = 'r';
        Cx = .2;
    end
end
for T = 1:p.Results.Scales 
    Temp = modified(Sig,T, Tx); 
    N = T*floor(length(Temp)/T);
    Temp3 = zeros(1,T);
    for k = 1:T
        fprintf(' .')
        if RadNew
            C{2,C_Loc} = Cx*Rnew(Temp(k:T:N));
        end
        
        if p.Results.Refined         
            [~, Ma, Mb] = Mobj.Func(Temp(k:T:N),C{:});
            Temp2(k) = Ma(end);
            Temp3(k) = Mb(end);
        else
            Temp2 = Mobj.Func(Temp(k:T:N),C{:});
            Temp3(k) = Temp2(end);
        end
    end    

    if p.Results.Refined && Tx==0
        MSx(T) = -log(sum(Temp2)/sum(Temp3))/log(Logx);
    elseif p.Results.Refined && Tx==1
        MSx(T) = -log(sum(Temp3)/sum(Temp2))/log(Logx);
    else
        MSx(T) = mean(Temp3);
    end
    clear Temp Temp2 Temp3 Ma Mb
end
CI = sum(MSx);
fprintf(' .\n')
if any(isnan(MSx))
    fprintf('\nSome entropy values may be undefined.')
end

if p.Results.Plotx    
    if p.Results.Refined
        strx = 'Refined-Composite';
    else
        strx = 'Composite';
    end
    
   figure, hold on
   plot(1:p.Results.Scales,MSx,'color',[8 63 77]/255,'LineWidth',3)   
   scatter(1:p.Results.Scales,MSx,60,[1 0 1],'filled')   
   xlabel('Scale Factor','FontSize',12,'FontWeight','bold','Color',[7 54 66]/255)
   ylabel('Entropy Value','FontSize',12,'FontWeight','bold','Color',[7 54 66]/255)
   title(sprintf('%s Multiscale %s ',strx,...
       func2str(Y{1})),'FontSize',16,'FontWeight','bold','Color',[7 54 66]/255)   
end
end

function [Y] = modified(Z,sx,Tx)
if Tx==1
    Y = movstd(Z,sx,1,'Endpoints','discard');
else
    Y = conv(Z,ones(1,sx),'valid')/sx;
end
end

%   Copyright 2024 Matthew W. Flood, EntropyHub
%   For Terms of Use see https://github.com/MattWillFlood/EntropyHub