function u=heatpumpPowerCalculation(data,c) 
    %c is standard constants
    %Calculating actual power output from heatpump
    u=(data.TT09z-data.TT07z)*c.cw*c.mhp;
end