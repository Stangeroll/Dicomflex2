tic
fitOptions = fitoptions('Method','NonlinearLeastSquares',...
    'Lower',         [  5,   100,      0 ],...
    'Upper',         [200,   Inf,    Inf ],...
    'Startpoint',    [  5,     0,      0 ]);

fitFcn = ['exp(-TE/T2star) * sqrt(S1^2 + S2^2 + 2*S1*S2*cos(2*pi/2.3*TE))'];

modelFunction = fittype(fitFcn, 'coefficients', { 'T2star', 'S1', 'S2' },...
    'independent', 'TE', 'options', fitOptions );


a = FitTool('x', [1 2 3], 'y', [0.5 1.1 1.45], 'fittype', modelFunction)


%% plot data
figure();
ax = axes;
hp_raw = plot(x, y.value);  % hp - handlePlot
hold on;
hp_raw.LineStyle = 'none';
hp_raw.Marker = 'o';
% plot fit with current values
% generate workspace variables
for i=1:numel(d.fitInfo.coeffs)
    eval([d.fitInfo.coeffs{i} '=' num2str(d.fitInfo.current(i))]);
end

%             Fcn1 = @(TE)exp(-TE/T2star)*sqrt(S1^2+S2^2+2*S1*S2*cos(2*pi/2.3*TE));
%             Fcn2 = str2func('(TE)exp(-TE/T2star)*sqrt(S1^2+S2^2+2*S1*S2*cos(2*pi/2.3*TE))');
%             %Fcn2 = str2func(['@(' d.fitInfo.indepPar{1} ')' d.fitInfo.fcnString])
Fcn = @(TE) exp(-TE/T2star) * sqrt(S1^2 + S2^2 + 2*S1*S2*cos(2*pi/4.6*TE));
fplot(Fcn, xlim);
hold off