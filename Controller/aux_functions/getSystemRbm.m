function [systemParameterMatrix, systemStates] = getSystemRbm(mpc, x, prices, t_tank_charge)
%Genereates a matrix of system parameters for use in the A and B matrix of
%the system. The matrix is based on the prices of electricity and open
%loop characteristics of the tank

Np = mpc.Np;
ts = mpc.ts;
systemStates = ones(Np,1); % Mode 1 => Charge room

T_od = ones(1,Np)*15; %outdoor temperature


% Discretize system for discharge
U = [0, 1, 0, 1, 3.5, T_od(1)];
A_cont = mpc.system.A(U);
B_cont = mpc.system.B(U);    
sys = c2d(ss(A_cont, B_cont, eye(size(A_cont)), 0), ts);
A_dis = sys.A;

% Estimate open loop discharge time
x_dis = x;
samples_dis = 0;
while(x_dis(8)>=mpc.G_output_constraint(3 + samples_dis*4,end) && samples_dis < mpc.Np-1)
    x_dis = A_dis*x_dis;
    samples_dis = samples_dis + 1;
end    

% Get the samples_dis number of time periods of highest prices. 
[~, indeces_dis] = maxk(prices, samples_dis);
% Set priciest periods as discharge
systemStates(indeces_dis) = 3; % Mode 3 => Discharge tank

% Discretize system for charge
U = [1, 0, 1, 0, 0, T_od(1)];
A_chrg = mpc.system.A(U);
B_chrg = mpc.system.B(U);    
sys = c2d(ss(A_chrg, B_chrg, eye(size(A_chrg)), 0), ts);
A_chrg = sys.A;
B_chrg = sys.B;

% Get open loop charge time
x_chrg = x;
samples_chrg = 0;
while( x_chrg(8) <= t_tank_charge && samples_chrg < mpc.Np-samples_dis)
    x_chrg = A_chrg*x_chrg + B_chrg*3000;
    samples_chrg = samples_chrg + 1;
end

samples_chrg = ceil(samples_chrg*(5/3));

[~, indeces_chrg] = mink(prices, samples_chrg);

% Set 3/5 cheapest periods as discharge
systemStates(indeces_chrg(1:5:end)) = 2;
systemStates(indeces_chrg(2:5:end)) = 2;
systemStates(indeces_chrg(3:5:end)) = 2;
systemStates(indeces_chrg(4:5:end)) = 1;
systemStates(indeces_chrg(5:5:end)) = 1;

if(x(5)<mpc.G_output_constraint(1,end) +1)
    samples_roomchrg = 5*60/ts;
    buff = systemStates(1:samples_roomchrg);
    buff(buff == 2) = 1; % Switch tank to room charge
    systemStates(1:samples_roomchrg) = buff;
end    

systemParameterMatrix = zeros(Np, 6);
for i = 1:Np
    switch systemStates(i)
        case 1
            systemParameterMatrix(i,:) = [0, 1, 1, 0, 3.5, T_od(i)];
        case 2
            systemParameterMatrix(i,:) = [1, 1, 1, 0, 0, T_od(i)];
        case 3
            systemParameterMatrix(i,:) = [1, 1, 0, 1, 4, T_od(i)];
        otherwise
            error("Unknown system mode")
    end

end
    
end