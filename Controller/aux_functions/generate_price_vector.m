function price = generate_price_vector(Ts,TimeIndex,Np)

arguments
    Ts = 5*60
    TimeIndex = 1
    Np = 24*60*60/Ts
end

price = readtable('NetSpotPriceDKK.csv').Var3;

kron_price = kron(flip(price(1:end-47)),ones(60*60/Ts,1));

price = kron_price(TimeIndex:TimeIndex+Np-1);


% 
% hold off
% 
% plot((1:Np)/Np*24,price -  mean(price))
% 
% hold on
% 
% plot([0,24],[0,0])
% xlim([0,24])
% xticks([0,3,6,9,12,15,18,21,24])
% fontname(gca,"Times")
% grid on
% xlabel("Time [hr]")
% ylabel("Zero-mean electricity price [DKK/kWhr]")

% legend("Zero-mean electricity price [DKK/kWhr]","Zero")
% exportgraphics(gca,"zero_mean_price.pdf")
