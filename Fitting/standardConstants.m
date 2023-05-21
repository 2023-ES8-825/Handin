function constants=standardConstants()
    % degr Openning degree as a percentage [0:1]

%Standard constants mostly defined by last group
    constants.ca=1012;          %Specific heat capacity air
    constants.Mhca=5;           %Mass of air in heat exchanger              !!!!!!!!!!!!!!!!!!!!!!
    constants.Mhcw=5;           %Mass of water in heat exchanger
    constants.cw=4181;          %Specific heat capacity of water
    constants.mhp=0.145;         %Massflow of water FT01z 
    constants.Mtank=461;        %Mass of water in tank                      !!!!!!!!!!!!!!!!!!!!!!!
    constants.Mtr=300;          %Mass of air and everything in target room  !!!!!!!!!!!!!!!!!!!!!!!
    constants.Gwall=400;        %Conductance between the air in the target room and the wall
    constants.Mwall=3000;       %Mass of walls in tagret room               !!!!!!!!!!!!!!!!!!!!!!          Wall is typically around 120 kg per square meter per layer of brick
    constants.cwall=1000;       %Specific heat capacity of wall in taget room
    constants.Gwallout=200;     %Conductance between the wall and outside
    constants.Gt= 350; % 595 to fit the other model           %Conductance in heat exchanger for the water tank
    constants.Mhxt= 4.61; %79 to fit the other model           %Mass of heat exchanger

                          %Opending degree of valve VC03z water to heating coil or tank [0;10]

    constants.mp1=0.28;        %Mass flow for SC01z (the pump that pumps water though the water tank)

    constants.n_heatCoil = 10;        %Number of states for heating coil in HVAC
    constants.n_heatExTank = 1;      %Number of states for heating coil in tank


    constants.doFlip=0;             %Wether heating coil has to be flipped in HVAC system

    constants.x2=0.5833; %0.5833
    constants.x1=0.3008; %0.3008
    constants.FPcomp=79.2; %Thing for the heat pump.  
    constants.eff=0.73; %Effect of the heat pump 
    constants.T_c=273+8; %Temperature of the evaporator

    constants.Tadj=22;
    
    constants.Rc = 0.57e-3;   %Needed for the conductance for the heating coil in the HVAC

    %New and update values 
    constants.doFlip=1; 


    constants.Gwall=560; 
    constants.Gwallout=900; 
    constants.Mwall=2000; 
    constants.Mtr=1200; 

    constants.eff=0.58; 

    constants.Mtank=461; 
    constants.Mhxt=35; 
    
    constants.n_heatCoil = 2;        %Number of states for heating coil in HVAC
    constants.n_heatExTank = 1; %Number of states for heating coil in Tank
    
    constants.k=0.88;
    constants.xa=0.469;
    constants.xGc=5/2;

    constants.divisionByZeroFix=0.015; %Fixing the division by zero for conductance in the heating coil in HVAC, alpha in the appendix
%0.015 is a good value
end