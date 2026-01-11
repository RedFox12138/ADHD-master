function result = HigFracDim(data, kmax)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the Higuchi Fractal Dimension of a time series %
% The Higuchi Fractal Dimension describes the degree of self-similarity %
% along a 1D time series, according to a sequencing integer, k. The     %
% function returns the dimensionality value, D, where 1 <= D <= 2. A    %
% higher D corresponds to higher complexity. It is a time measure of    %
% complexity.                                                           %    
%                                                                       %
% Higuchi, T. (1988). Approach to an Irregular Time Series on the Basis %
%         of the Fractal Theory. Physica D, 31, 277-283.                %
% Accardo, A., Affinito, M., Carrozzi, M., & Bouquet, F. (1997). Use of %
%         the fractal dimension for the analysis of                     %
%         electroencephalographic time series. Biol Cybern, 77, 339-350.% 
%         doi:10.1007/s004220050394                                     %
%                                                                       %
% INPUTS                                                                %
%  Parameters:                                                          %
%   data = time series                                                  %                                               %
%   kmax = maximum size of iteration                                    %
%                                                                       %
%   Standard value is kmax = 8                                          %
%                                                                       %
% OUTPUTS                                                               %
%   result = Higuchi fractal dimension value                            %
%                                                                       %
%                       Created by Brian Lord                           %
%                       University of Arizona                           %
%                                                                       %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Higuchi Fractal Dimension calculation

% Initialize components
N = length(data);
L = zeros(1,kmax);
x = zeros(1,kmax);
y = zeros(1,kmax);

for k = 1:kmax
    for m = 1:k
        norm_factor = (N-1)/(round((N-m)/k)*k); % normalization factor
        X = sum(abs(diff(data(m:k:N)))); % generate iterative sum difference
        L(m)=X*norm_factor/k; % mean of normalized differences
    end

    y(k)=log(sum(L)/k); % ln(L(k))
    x(k)=log(1/k); % ln(1/k)
end

D = polyfit(x,y,1); % linear regression fit
HFD = D(1); % return slope
result = HFD;