clc
clear
close all

% Load model and udp class
addpath ../Modelling/'Full model'/
addpath udp_functions aux_functions

c = fitted_constants();

[A, B, C, c_out] = Model(c);

% Time and sample time
T_sim = 48*60*60; % 24-hour
Ts_sim = 1*60; % 1-minute sim
Ts_mpc = 5*60; % 5-minute control
T = Ts_sim : Ts_sim : T_sim*2;

%Simulation steps
N = T_sim/Ts_sim;

% Define initial conditions
x0 = [20; 20; 20; 20; 18; 1; 33; 33];
% Data storage
log = struct('u',zeros(6,1),'x',[x0,x0],'y',[C*x0,C*x0]);

% Setup UDP communication
udp_comm = UdpClass("UdpSettings.json", "SensorIDToNames.json", 'use_twin',true,'is_twin',true);

TT07z = 20;
P_cp = 0;

T_lastTransmission = -20;
T_lastRecieved = 0;

%% Run test model
for i = 2:N

    % Get inputs ( U )
    if T(i) - T_lastRecieved > Ts_mpc
        T_lastRecieved = T(i);
        
        
        received = udp_comm.receive();
        disp("Received the UDP packet:")
        disp(received)
        log.u(1,i) = received.SC01x; % Compressor
        log.u(2,i) = received.VC03z/10; % Theta_hp
        log.u(3,i) = received.VC02z/10; % Theta_p1
        log.u(4,i) = received.SC02z/10; % Pump_hp
        log.u(5,i) = received.SC01z/10; % Pump_p1
        log.u(6,i) = received.FC01z; % Fan speed

        % Unlinearize control signal to compressor
        TT07z = log.x(7,i)*log.u(2,i) + log.x(4,i)*(1 - log.u(2,i));
        
        % Handle compressor on/off
        if received.HPOnx == 1
            if received.SC01x > 35; SC01x = received.SC01x; else; SC01x = 35; end
            P_cp = 79.2*SC01x - 1987;
        else
            P_cp = 0;
        end

        T_c = 273 + 8;
        T_h = 273 + TT07z;
        log.u(1,i) = (c.x1 + c.x2.*T_c./(T_h-T_c + 0.015))*P_cp*received.HPOnx;
        
        U_received = log.u(1,i);
        
    % Zoh on input
    else
        log.u(:,i) = log.u(:,i-1);
    end
    TT07z = log.x(7,i)*log.u(2,i) + log.x(4,i)*(1 - log.u(2,i));
    
    sys_opts = [
        log.u(2,i) % Theta_hp
        log.u(3,i) % Theta_p1
        log.u(4,i) % Pump_hp
        log.u(5,i) % Pump_p1
        log.u(6,i) % Fan speed
        15 % OUTDOOR_TEMP 
    ];

    % Re-discretize system with new options
    sys_cont = ss(A(sys_opts),B(sys_opts),C,0);
    sys = c2d(sys_cont,Ts_sim);
    Ad = sys.A;
    Bd = sys.B;
    Cd = sys.C;
    
    % Do simulation time step ( X )
    log.x(:,i+1) = Ad*log.x(:,i) + Bd*log.u(1,i);

    % Calculate output
    log.y(:,i) = Cd*log.x(:,i);

    % Send ouputs ( Y )
    if T(i) - T_lastTransmission > Ts_mpc
        T_lastTransmission = T(i);

        messageToSend.TT16z = log.y(1,i);
        messageToSend.TT11z = log.y(2,i);
        messageToSend.TT17z = log.y(3,i);
        messageToSend.TT12z = log.y(5,i);
        messageToSend.TT13z = log.y(6,i);
        messageToSend.JT01x = P_cp;

        messageToSend.TT07z = TT07z;

        messageToSend.EmergencyShotdown = 0;
        messageToSend.onx = 1;

        disp("Sending measurements")
        udp_comm.transmit(messageToSend);
        
    end
end

messageToSend.EmergencyShotdown = 0;
messageToSend.onx = 0;
udp_comm.transmit(messageToSend)
