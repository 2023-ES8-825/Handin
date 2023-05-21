function [P_hp,P_cp] = heatpumpPowerEstimat(data, c)

P_cp = 79.2.*data.SC01x - 1987;

T_c=273+10;
T_h=data.TT07z+273;

P_hp=(c.x1 + c.x2.*T_c./(T_h-T_c)) .*P_cp;

end