function [A,B,C,c_out] = Model(std_const)
 %% Justing flowing the appendix, where the model is written up so look in that model!
 %% load standard constants:
arguments
    std_const = [];
end    
  
if isempty(std_const)    
c=standardConstants();
else
c = std_const;
end
%% 
%Defineation for U: 
% U(1) valve opening degree between 0 and 1   (1 all though the tank, 0 all
% though the heating coil
%
% U(2) valve opening degree between 0 and 1   (0 all though the tank discharge, 
% 1 all bypass the tank discharge)
%
% U(3) if mhp is on, 1 if the pump is off, 0 
% 
% U(4) if mp1 is on, 1 if the pump is off, 0 
% 
% U(5)  Fan speed between 0 and 10   
% 
% U(6) Outdoor temperature
%% Define mass flows

mtc=@(U)c.mhp*U(3)*U(1);
mtd=@(U)c.mp1*U(4)*(U(2)); 
mc=@(U) U(3)*c.mhp*(1-U(1))+c.mp1*U(4)+c.divisionByZeroFix;  %+c.divisionByZeroFix
ma=@(U) c.xa*(0.0896*U(5))+c.divisionByZeroFix; %+c.divisionByZeroFix
%% Define the condence for the HVAC 

Rma = @(U) 0.293e-3 * 1/((ma(U))^(0.8)); 
Rmw = @(U) 0.285e-3 * 1/((mc(U))^(0.8)); 
Gc = @(U) (c.xGc*(1/(c.Rc + Rma(U) + Rmw(U))));    
%% Define Tamb,adj
TambAdj=@(U) c.k*c.Tadj+(1-c.k)*U(6);

%%
%First the model for the AIr in the HVAC is written up: 
%Define values neccesary for Air HVAC (A(1:2,:)) one row at the time!
mcg=@(U)-(ma(U)*c.ca+Gc(U)/c.n_heatCoil)/(c.Mhca/c.n_heatCoil*c.ca); %A(1,1) and A(2,2)

GcA=@(U) (Gc(U)/c.n_heatCoil)/(c.Mhca/c.n_heatCoil*c.ca); %A(1,4) and (A(2,3) 
A16=@(U) ma(U)/(c.Mhca/c.n_heatCoil)*U(6); %A(1,6)

A21= @(U) (ma(U)*c.ca)/(c.ca*c.Mhca/c.n_heatCoil); %A(2,1) 


%Defining air HVAC: 
airHVAC=@(U) [mcg(U),0,0,GcA(U),0,A16(U),0,0;A21(U),mcg(U),GcA(U),0,0,0,0,0];
%%
%Defining what is neccesary for water HVAC row by row: 

 gw= @(U)(Gc(U)/c.n_heatCoil)/(c.cw*c.Mhcw/c.n_heatCoil); %A(3,2) and A(4,1) 

 mcgc= @(U)(-mc(U)*c.cw-Gc(U)/c.n_heatCoil)/(c.cw*c.Mhcw/c.n_heatCoil); % A(3,3) and A(4,4) 
% a_34=@(U) (mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mp1*U(4)*U(2))/(c.mp1*U(4)+c.mhp*U(3))+(mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mhp*U(3)*(1-U(1)))/(c.mhp*U(3)+c.mp1*U(4))*(1-U(1)); %A(3,4)
  a_34=@(U) (mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mp1*U(4)*(1-U(2)))/(c.mp1+c.mhp*U(3))+(mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mhp*U(3)*(1-U(1)))/(c.mhp+c.mp1*U(4))*(1-U(1)); %A(3,4)

 % A37= @(U) (mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mhp*U(3)*(1-U(1)))/(c.mhp*U(3)+c.mp1*U(4))*U(1); %A(3,7)
   A37= @(U) (mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mhp*U(3)*(1-U(1)))/(c.mhp+c.mp1*U(4))*U(1); %A(3,7)

 
 %A38= @(U) (mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mp1*U(4))/(c.mhp*U(3)+c.mp1*U(4))*(1-U(2));  %A(3,8)
 A38= @(U) (mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mp1*U(4))/(c.mhp*U(3)+c.mp1)*(U(2));  %A(3,8)



 A43= @(U) (mc(U)*c.cw)/(c.cw*c.Mhcw/c.n_heatCoil); %A(4,3) 
 %Collecting it into one matrix: 
waterHVAC= @(U) [0,gw(U),mcgc(U),a_34(U),0,0,A37(U),A38(U);gw(U),0,A43(U),mcgc(U),0,0,0,0];
%% Next the model for the target room is made: 
%First define the neccesary things one columen at the time: 
A52=@(U) (c.ca*ma(U))/(c.Mtr*c.ca); %A(5,2) 
A55=@(U) (-c.ca*ma(U)-c.Gwall)/(c.Mtr*c.ca); %A(5,5) 
A56=@(U) (c.Gwall)/(c.Mtr*c.ca)*TambAdj(U);  %A(5,6)

%Writing up the entire row: 
TargetRoom=@(U)[0,A52(U),0,0,A55(U),A56(U),0,0];
%% Next the disturbance row is written, this corresponds to a zero row: 
disturbance=@(U) zeros(1,8); 
%% Next the model for heating coil insided the tank is written up: 
%starting by writing up each columen: 
A74=@(U) (mtc(U))/(c.Mhxt/c.n_heatExTank)*(1-U(1));   %A(7,4) 
A77=@(U)  (-c.cw*mtc(U)-c.Gt/c.n_heatExTank)/(c.cw*c.Mhxt/c.n_heatExTank)+ (mtc(U))/(c.Mhxt/c.n_heatExTank)*U(1); %A(7,7) 
A78=@(U)  (c.Gt/c.n_heatExTank)/(c.cw*c.Mhxt/c.n_heatExTank); %A(7,8)
%Writing up the model: 
TankCoil=@(U) [0,0,0 A74(U),0,0 A77(U),A78(U)];

%% Next the model for the temperature of the tank is writen
%First define coloumen by coloumen: 
A84=@(U) (mtd(U))/(c.Mtank);   %A(8,4)
A87=@(U)  c.Gt/(c.cw*c.Mtank);    %A(8,7)
A88=@(U) (-c.Gt-mtd(U)*c.cw)/(c.cw*c.Mtank);  %A(8,8)
%Collecting it into one matrix: 
TankTemp= @(U) [0,0,0,A84(U),0,0,A87(U),A88(U)]; 

%% Collecting it alle to one matrix: 

%Collecting it all into one. 
 A=@(U)[airHVAC(U);waterHVAC(U);TargetRoom(U);disturbance(U);TankCoil(U);TankTemp(U)]; 
 %A done baby ;D 
%%  Next the B matrix is writting, this is done row by row: 

B3=@(U)  (mc(U))/(c.Mhcw/c.n_heatCoil)*(c.mhp*U(3)*(1-U(1)))/(c.mhp+c.mp1*U(4))*1/(c.mhp*c.cw);     %B(3,1) 

B7= @(U) (mtc(U))/(c.Mhxt/c.n_heatExTank)*(1/(c.mhp*c.cw));     %B(7,1) 
%Collecting in all into B: 
B=@(U) [0;0;B3(U);0;0;0;B7(U);0]; 
%% Next the output matrix is determinted based on what can be measured

%Hereafter the output matrix is determine this one is determinted based on
%what matrix is interresing here it is chosen to be the temperature of 
CAirHvac=[0,1,zeros(1,6)]; 
CWaterHvac=[zeros(1,3),1,zeros(1,4)]; 
CRoom=[zeros(1,4),1,zeros(1,3)]; 
Cdisturbance=[zeros(1,5),1,zeros(1,2)]; 
CTankHeat=[zeros(1,6),1,zeros(1,1)]; 
CTankTemp=[zeros(1,7),1]; 

%Collecting it into one matrix: 
C=[CAirHvac;CWaterHvac;CRoom;Cdisturbance;CTankHeat;CTankTemp];

%% Making naming for each state 
c_out.n_states=8;

   c_out.states(1).isMeasureable = false;
   c_out.states(1).name = "Air heating coil 1";
   c_out.states(1).sensor = "";
   c_out.states(1).getInitValueFrom = "TT04z";
   c_out.states(1).symbol = "T_ca1";

   c_out.states(2).isMeasureable = true;
   c_out.states(2).name = "Air heating coil 2";
   c_out.states(2).sensor = "TT16z";                %LL TT16z
   c_out.states(2).getInitValueFrom = "TT16z";      
   c_out.states(2).symbol = "T_ca2";

   c_out.states(3).isMeasureable = false;
   c_out.states(3).name = "Water heating coil 1";
   c_out.states(3).sensor = ""; 
   c_out.states(3).getInitValueFrom = "TT04z";     %LL:Why?
   c_out.states(3).symbol = "T_cw1";               

   c_out.states(4).isMeasureable = true;
   c_out.states(4).name = "Water heating coil 2";
   c_out.states(4).sensor = "TT11z";
   c_out.states(4).getInitValueFrom = "TT11z";
   c_out.states(4).symbol = "T_cw2"; 

   c_out.states(5).isMeasureable = true;
   c_out.states(5).name = "Target Room";
   c_out.states(5).sensor = "TT17z";
   c_out.states(5).getInitValueFrom = "TT17z";
   c_out.states(5).symbol = "T_tr";

   c_out.states(6).isMeasureable = true;
   c_out.states(6).name = "Disturbance";
   c_out.states(6).sensor = "";
   c_out.states(6).getInitValueFrom = "";
   c_out.states(6).symbol = "x_d";

   c_out.states(7).isMeasureable = true;
   c_out.states(7).name = "Heat exchanger tank";
   c_out.states(7).sensor = "TT12z";
   c_out.states(7).getInitValueFrom = "TT12z";
   c_out.states(7).symbol = "T_t1";
   
   c_out.states(8).isMeasureable = true;
   c_out.states(8).name = "Temperature of tank";
   c_out.states(8).sensor = "TT13z";
   c_out.states(8).getInitValueFrom = "TT13z";
   c_out.states(8).symbol = "T_tank";
end 