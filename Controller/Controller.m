clc
clear
clear neo_mpc_run

% Configuration for controller run
config.enable_log = false;
config.save_gif = false;
config.use_price = true;
config.use_tank = true;
config.simulate = true;

date_fmt = 'yyyy-MM-dd - HH-mm';
start_time = datetime('now','Format',date_fmt);

addpath mpc_functions udp_functions aux_functions

% Load model
addpath ../Modelling/'Full model'
c = fitted_constants;
[A, B, Cy, c_out] = Model(c);

Param = [
    0; % Theta_hp
    1; % Theta_p1
    1; % Pump_hp
    0; % Pump_p1
    5; % Fan speed
    18 % OUTDOOR_TEMP
];

if config.use_tank
    Cz = [
        0 0 0 0 1 0 0 0;
        0 0 0 0 0 0 0 1
    ]; % room temp, tank temp
else
    A = A(Param);
    B = B(Param);
    Cz = [0 0 0 0 1 0 0 0]; % room temp
end

%%%%%%%%%%%%%%%%%%%%%
% TUNING PARAMETERS %

Ts_mpc = 5*60; % 5-minute sample time

Nc_hours = 8; % 8 hour horizon
Np_hours = 10; % 10 hour horizon

slack_param = 5000; % rho
mpc_Q = diag([80,0]); % Diagonal in Q
mpc_R = 10e-6; % Diagonal in R
gamma = 0.5; % Price scalar

kalman_process_noise = diag([0.01,0.01,0.01,0.01,0.5,0,0.5,0.5]);
var_temp = 0.015;
kalman_measurement_noise = diag([var_temp,var_temp,var_temp,0.00000001,var_temp,var_temp]);

% Actuator value constraint
F = [-1 0 ; 1 -2800];

% TUNING PARAMETERS %
%%%%%%%%%%%%%%%%%%%%%

Nc = Nc_hours*3600/Ts_mpc; % 8 hour horizon
Np = Np_hours*3600/Ts_mpc; % 10 hour horizon (DO NOT CHANGE)

% ,night_temp,day_temp, day_start,night_start
room_temp_ref = generate_room_temp_ref(Ts_mpc,27.5,27.5);
tank_temp_ref = generate_room_temp_ref(Ts_mpc,40,40);

raw_price = generate_price_vector(Ts_mpc,1,24*60*60/Ts_mpc);

% Use min-based price floor
price_min = (raw_price - min(raw_price))*gamma ;
price_mean = (raw_price - mean(raw_price))*gamma ;
price_sqr = (raw_price.^2)*gamma/5 ;
price_sqrmin = ((raw_price - min(raw_price)).^2)*gamma;

price = price_min;

% Shift initial time
init_hour = 1;
if init_hour > 0
    room_temp_ref = [room_temp_ref(init_hour*3600/Ts_mpc:end);room_temp_ref(1:((init_hour*3600/Ts_mpc)-1))];
    tank_temp_ref = [tank_temp_ref(init_hour*3600/Ts_mpc:end);tank_temp_ref(1:((init_hour*3600/Ts_mpc)-1))];
    price = [price(init_hour*3600/Ts_mpc:end);price(1:((init_hour*3600/Ts_mpc)-1))];
    raw_price = [raw_price(init_hour*3600/Ts_mpc:end);raw_price(1:((init_hour*3600/Ts_mpc)-1))];
end

Q = kron(eye(Np),mpc_Q);
R = kron(eye(Nc),mpc_R);

% Setup mpc
mpc = neo_mpc_init(A,B,Cy,Cz,Ts_mpc,Nc,Np,Q,R);

if config.use_price
    mpc = set_linear_input_cost(mpc,1);
end

% Setup constraint
mpc = set_const_input_constraint(mpc,F);

if config.use_tank
    output_constr_low = [room_temp_ref-2.5 tank_temp_ref-10];
    output_constr_upp = [room_temp_ref+2.5 tank_temp_ref+5];
else
    output_constr_low = room_temp_ref-2.5;
    output_constr_upp = room_temp_ref+2.5;
end

mpc = set_output_constraint(mpc, output_constr_low, output_constr_upp);

% Remove reference penalty from tank

mpc.rho = slack_param;

disp("Configured MPC model:")
disp(mpc);

% Kalman filter variables
R = kalman_measurement_noise;
Q = kalman_process_noise;
save_data = struct;
save_data.x = [];
save_data.z = [];
save_data.u = [];
save_data.time = [];
save_data.time_unix = [];
save_data.constraints.output.lower = [];
save_data.constraints.output.upper = [];
save_data.price = [];
save_data.reference = [];
save_data.predictedY = [];
save_data.messagesRecieved = {};
save_data.messagesSent = {};
save_data.systemParameters = {Param'};
save_data.systemModes = {};
save_data.prevSystemModes = [];
save_data.fcomp = [];
save_data.TT07z = [];
save_data.JT01x = [];
save_data.mpc = mpc;

Pp = eye(mpc.n_states)*0.1;

%Setting up udp
udp_comms = UdpClass('UdpSettings.json', 'SensorIDToNames.json','use_twin',config.simulate);

initiateSystem(udp_comms);

disp("System ready to receive first UDP packet")
udp_recv = udp_comms.receive();
disp("First UDP packet received, starting controller")

% Initialize state vector and control signal
x = double([
    udp_recv.TT16z;
    udp_recv.TT16z;
    udp_recv.TT11z;
    udp_recv.TT11z;
    udp_recv.TT17z;
    1.0; % Must be constant 1
    udp_recv.TT12z;
    udp_recv.TT13z;
]);

u = 0.0;

currentMode = 1;

%%

fig1 = figure(1);
set(fig1, 'Position', [0 0 1280 1024])

k = 0;
while(k <= 140)
    k = k + 1;

    % Save timestamps (unix epoch and relative)
    t_lastUpdate = posixtime(datetime); % Gets current unix time
    save_data.time_unix(:,end+1) = t_lastUpdate;
    save_data.time(:,end+1) = k*Ts_mpc;

    % Stop controller if system experiences an emergency shutdown
    if udp_recv.EmergencyShotdown
        DisplayShutdownMessage(udp_recv, udp_comms);
        shutdownSystem(udp_comms)
        break
    end

    % Commanded exit from system, done through simulink interface
    if (udp_recv.onx == 0 && size(save_data.u,2) > 3 && config.simulate)
        shutdownSystem(udp_comms);
        break
    end

    % Current state
    y = double([
        udp_recv.TT16z;
        udp_recv.TT11z;
        udp_recv.TT17z;
        1.0; % Must be constant 1
        udp_recv.TT12z;
        udp_recv.TT13z;
    ]);

    TT07z = udp_recv.TT07z;
    save_data.TT07z(end+1) = TT07z;

    % Update state space model
    if mpc.sys_is_func
        params_for_system = save_data.systemParameters{end}(1,:);

        Ad = mpc.system.A(params_for_system);
        Bd = mpc.system.B(params_for_system);

        sys = c2d(ss(Ad,Bd,Cy,0), mpc.ts);
        Ad = sys.A;
        Bd = sys.B;
    else
        Ad = mpc.system.A;
        Bd = mpc.system.B;
    end

    % Kalman filter state estimation
    x_est = Ad*x + Bd*u;
    y_diff = y - Cy*x_est;
    K = (Pp*Cy')/(Cy*Pp*Cy'+R);
    IKC = eye(mpc.n_states)-K*Cy;
    Pe = (IKC)*Pp*(IKC)' + K*R*K';
    Pp = Ad*Pe*Ad' + Q;

    x = x_est + K*y_diff;

    % Save state estimate and controlled outputs
    save_data.x(:,end+1) = x;
    save_data.z(:,end+1) = Cz*x;

    % Update room temperature reference and constraint
    room_temp_ref = [room_temp_ref(2:end);room_temp_ref(1)];
    tank_temp_ref = [tank_temp_ref(2:end);tank_temp_ref(1)];

    output_constr_low = [output_constr_low(2:end,:) ; output_constr_low(1,:)];
    output_constr_upp = [output_constr_upp(2:end,:) ; output_constr_upp(1,:)];

    save_data.constraints.output.lower = [save_data.constraints.output.lower, output_constr_low];
    save_data.constraints.output.upper = [save_data.constraints.output.upper, output_constr_upp];

    mpc = set_output_constraint(mpc,output_constr_low, output_constr_upp);

    % Define room temperature reference
    if config.use_tank
        ref = [room_temp_ref(1:Np)'; tank_temp_ref(1:Np)'];
    else
        ref = room_temp_ref(1:Np)';
    end
    save_data.reference(:,:,end+1) = ref;
    ref = ref(:);

    %%%%%%%%%%%%%%%%%%%%%%
    % RULE BASED INITIAL %
    %%%%%%%%%%%%%%%%%%%%%%

    if config.use_price
        save_data.price(:,end+1) = price;
        price_Np = price(1:Np);
    else
        price_Np = [];
    end

    if config.use_price && config.use_tank

        % Save previous system mode
        if ~isempty(save_data.systemModes) 
            save_data.prevSystemModes(end+1) = save_data.systemModes{end}(1);
        end

        [systemParameters, systemModes] = getSystemRbm(mpc, x, price_Np, 45);

        save_data.systemParameters{:,end+1} = systemParameters;
        save_data.systemModes{end+1} = systemModes;

        mpc = neo_mpc_generate_matrices(mpc, 'sys_args', save_data.systemParameters{:,end});

        currentMode = save_data.systemModes{end}(1);
        Param = systemParameters(1,:);
    end

    % Get output of MPC
    [u, du, ypred] = neo_mpc_run(mpc,x,ref,price_Np);

    save_data.u(:,end+1) = u;
    save_data.predictedY(:,:,end+1) = ypred;

    % Convert heat pump power output to compressor frequency
    f_comp = PowerToFrequency(c,udp_recv.TT07z,u);

    %%%%%%%%%%%%%%%%%%%%
    % RULE BASED FINAL %
    %%%%%%%%%%%%%%%%%%%%

    %Generate message for transmission
    switch currentMode
        case 1 % Room Charge
            disp("Mode : Room charge")
            message = getMessage_roomCharge(f_comp);

        case 2 % Tank Charge
            disp("Mode : Tank charge")
            message = getMessage_tankCharge(f_comp, udp_recv.TT13z);

        case 3 % Tank Discharge
            disp("Mode : Tank discharge")
            message = getMessage_tankDischarge();
            message = dischargeBangBangController(message,y,room_temp_ref(1)+[-0.5,+0.5]);

        otherwise
            disp("Mode : Unknown -> shutdown")
            shutdownSystem(udp_comms);
            break
    end

    save_data.fcomp(end+1) = message.SC01x;
    save_data.messagesSent{end+1} = message;

    % Only turn off pump after compressor power is lowered
    if k > 1
        if save_data.messagesSent{end}.HPOnx == 0 && save_data.messagesSent{end-1}.HPOnx == 1 && ~config.simulate
            message.SC02z = 10;
            udp_comms.transmit(message);
            messsge = udp_comms.receive();
            while messsge.JT01x > 100
                messsge = udp_comms.receive();
            end
            message.SC02z = 0;
        end
    end

    udp_comms.transmit(message);

    %Display current time and message
    disp(datetime)
    disp(message)

    % Save log as matlab .mat file
    if config.enable_log
        save("logs/log "+string(start_time)+".mat", "save_data")
    end

    % Wait until next actuation time
    if ~config.simulate
        pause(Ts_mpc - (posixtime(datetime)-t_lastUpdate));
    end

    % Receive struct for next loop iteration
    udp_recv = udp_comms.receive();
    save_data.messagesRecieved{end+1} = udp_recv;
    save_data.JT01x(end+1) = udp_recv.JT01x;

    plot_all(save_data,config,mpc,k,start_time,raw_price)

    % Roll system modes over
    price = [price(2:end);price(1)];
end

fig = figure(1)
fontname(fig,"Times")
exportgraphics(fig,"controller_running.pdf")

disp("Controller ended")
disp("Energy used = " + sum(save_data.JT01x*mpc.ts)/1000/3600 + " kWh")
% disp("Total price = " + save_data.JT01x*mpc.ts/1000/3600*save_data.price(1,:)' + " kr")
disp("Total price = " + save_data.JT01x(1:length(raw_price))*mpc.ts/1000/3600*raw_price + " kr")
disp("Mean temperature = " + string(mean(save_data.z(1,:))))

%%%%%%%%%%%%%%%%%%%%%%%%
% Function definitions %
%%%%%%%%%%%%%%%%%%%%%%%%

function plot_all(save_data,config,mpc,k,start_time,price)

    hold off
    plot_time = save_data.time-save_data.time(1);
    divfct = 3600;

    clf(1)

    if config.use_price && config.use_tank
        subplot(3,1,2)
        hold off
        plotMPCModes(mpc, save_data.systemModes{end}, save_data.prevSystemModes);
        xlim([0,24])
        xticks([0,3,6,9,12,15,18,21,24])
        hold on

        subplot(3,1,3)
        xticks([0,3,6,9,12,15,18,21,24])

        yyaxis right

        plot(plot_time/divfct, save_data.JT01x)
        ylabel("Compressor power [W]")
        ylim([0,2000])

        yyaxis left
        grid on
        plot((0:mpc.ts:(24*3600-mpc.ts))/3600, price)
        ylabel("Electricty Price [DKK]")
        ylim([1,3])
        title("Electricity price and compressor power")
        hold off
        xlim([0,24])
        subplot(3,1,1)
    end

    xticks([0,3,6,9,12,15,18,21,24])
    hold on

    if config.simulate
        title("Room and tank temperature (SIMULATION)")
    else
        title("Room and tank temperature")
    end

    grid on
    plot(plot_time/divfct, save_data.z(1,:),"DisplayName","Room temperature")
    hold on
    ylabel("Temperature [C]")
    if config.use_tank
        plot(plot_time/divfct, save_data.z(2,:),"DisplayName","Tank temperature")
    end

    legend()

    % Plot temperature reference
    plot(plot_time/divfct, reshape(save_data.reference(1,2,2:end),[length(save_data.reference(1,2,2:end)),1]), 'Color', 'black', 'LineStyle','--',"DisplayName","Room reference")


    % Plot output prediction
    plot(mpc.ts*((0:mpc.Np-1)+k)/divfct, save_data.predictedY(1:mpc.n_controlled_outputs:end,1,end), 'LineStyle', ':', 'HandleVisibility','off')
    if config.use_tank
        plot(mpc.ts*((0:mpc.Np-1)+k)/divfct, save_data.predictedY(2:mpc.n_controlled_outputs:end,1,end), 'LineStyle', ':', 'HandleVisibility','off')
    end

    % Plot room temperature constraintsplot_all
    plot_time_constraints = 0:mpc.ts:(length(save_data.constraints.output.lower(:,1))-1)*mpc.ts;
    plot(plot_time_constraints/divfct, save_data.constraints.output.lower(:,1), 'Color', 'red', 'LineStyle','--',"DisplayName","Constraints")
    plot(plot_time_constraints/divfct, save_data.constraints.output.upper(:,1), 'Color', 'red', 'LineStyle','--', 'HandleVisibility','off')

    % Plot tank temperature constraints
    if config.use_tank
        plot(plot_time_constraints/divfct, save_data.constraints.output.lower(:,2), 'Color', 'red', 'LineStyle','--', 'HandleVisibility','off')
        plot(plot_time_constraints/divfct, save_data.constraints.output.upper(:,2), 'Color', 'red', 'LineStyle','--', 'HandleVisibility','off')
    end
    xlabel("Time [Hour]")
    ylim([20,50])
    xlim([0,24])
    drawnow()
    hold off


    % Animate MPC at 30 Fps
    if config.save_gif
        frame = getframe(1);
        im = frame2im(frame);
        [imind,cm] = rgb2ind(im,256);
        if k < 2
            imwrite(imind,cm,"gifs/"+string(start_time)+".gif",'gif','DelayTime',1/5, 'Loopcount',inf);
        else
            imwrite(imind,cm,"gifs/"+string(start_time)+".gif",'gif','DelayTime',1/5,'WriteMode','append');
        end
    end
end

function plot_all_old(save_data,config,mpc,k,start_time,price)

    if size(save_data.time,2) > 1
        hold off
        plot_time = save_data.time-save_data.time(1);
        divfct = 3600;

        clf(1)
        for i = 1:mpc.n_controlled_outputs
            subplot(mpc.n_controlled_outputs,1,i)
            plot(plot_time/divfct, save_data.z(i,:))
            hold on
            if config.simulate
            title("SIMULATION")
            end

    length(save_data.predictedY(i:mpc.n_controlled_outputs:end,1,end))
    length(mpc.ts*((0:mpc.Np-1)+k)/divfct)

            % Plot output prediction
            plot(mpc.ts*((0:mpc.Np-1)+k)/divfct, save_data.predictedY(i:mpc.n_controlled_outputs:end,1,end), 'LineStyle', ':')

            %Plot return water temperature
            %plot(plot_time/divfct, save_data.TT07z)

            if config.use_price
                % Plot price
                plot(plot_time/divfct, save_data.price(2,:)*100, 'Color', 'blue', 'LineStyle',':')
            end

            % Plot temperature rerefence
            plot(plot_time/divfct, reshape(save_data.reference(i,2,2:end),[length(save_data.reference(i,2,2:end)),1]), 'Color', 'black', 'LineStyle','--')
            plot(plot_time/divfct, save_data.fcomp)

            % Plot temperature constraints
            plot_time_constraints = [0:mpc.ts:(length(save_data.constraints.output.lower(i,:))-1)*mpc.ts];

            plot([0,24],[30,30], 'Color', 'red', 'LineStyle','--')
            if i == 1
                plot([0,24],[25,25], 'Color', 'red', 'LineStyle','--')
            else
                plot([0,24],[45,45], 'Color', 'red', 'LineStyle','--')
            end

            xlabel("Hours")
            drawnow()
            hold off
        end

        ylim([0,60])


        % Animate MPC at 30 Fps
        frame = getframe(1);
        im = frame2im(frame);
        [imind,cm] = rgb2ind(im,256);
        if k < 3
            imwrite(imind,cm,"animation_old.gif",'gif','DelayTime',1/5, 'Loopcount',inf);
        else
            imwrite(imind,cm,"animation_old.gif",'gif','DelayTime',1/5,'WriteMode','append');
        end
    end

end

function message = dischargeBangBangController(message, y, limits)
    % Do bang-bang control of tank while in discharge mode.

    persistent onoff;
    if isempty(onoff)
        onoff = 0;
    end

    if y(3) < limits(1)
        onoff = 1;
    elseif y(3) > limits(2)
        onoff = 0;
    end

    if onoff == 1
        message.SC01z = 10;
        message.FC01ON = 10;
        message.FC01z = 5;
    else
        message.SC01z = 0;
        message.FC01ON = 0;
        message.FC01z = 0;
    end
end

function f_comp = PowerToFrequency(c,TT07z,u)
    T_c = 273 + 8;
    T_h = 273 + TT07z;
    P_cp = u/(c.x1 +c.x2 * T_c/(T_h-T_c+0.0001));
    f_comp = (P_cp + 1987)/79.2;
end

function DisplayShutdownMessage(recieved_message)

    switch recieved_message.ErrorMSG
        case 1 ; warning("PT03x: Condenser pressure > 13.5 bar")
        case 2 ; warning("TT02x: Condenser inlet temperature > 110 C")
        case 3 ; warning("TT03x: Expansion valve inlet temperature < -20 C")
        case 4 ; warning("TT06x: Compressor inlet temperature > 50 C")
        case 5 ; warning("TT07x: Heat reservoir inlet temperature < 2 C")
        case 6 ; warning("TT08x: Heat reservoir outlet temperature out of bounds (TT08x < 2 or TT08x > 60)")
        case 7 ; warning("Tsh: Superheat temperature < 3 C")
        otherwise ; warning("Unknown error")
    end
end

function shutdownSystem(udp_obj)

    warning("Emergency shutdown")

    shutdownMessage = struct;
    shutdownMessage.SC01x = 35;
    shutdownMessage.FC01z = 0;
    shutdownMessage.FC02z = 0;
    shutdownMessage.DC01z = 0;
    shutdownMessage.DC02z = 0;
    shutdownMessage.DC03z = 0;
    shutdownMessage.HPOnx = 0;

    udp_obj.transmit(shutdownMessage);
end


function startUpMessage = initiateSystem(udp_obj)
    disp("Preparing system for start up")
    startUpMessage = struct;
    startUpMessage.VC03z = 0;
    startUpMessage.VC02z = 0;
    startUpMessage.SC02z = 0;
    startUpMessage.SC01z = 0;
    startUpMessage.HPOnx = 0;
    startUpMessage.SC01x = 0;
    startUpMessage.FC01z = 0;
    startUpMessage.FC02z = 0;
    startUpMessage.DC01z = 0;
    startUpMessage.DC02z = 0;
    startUpMessage.DC03z = 0;
    startUpMessage.FC01ON = 0;

    udp_obj.transmit(startUpMessage);
end

function message = getMessage_roomCharge(f_comp)
    if f_comp > 33
        message.HPOnx = 1;  % Compressor on
        message.SC02z = 10; % Pump_hp on
        message.FC01z = 5;  % Fan speed
        message.FC01ON = 10;% Fan on

    else
        f_comp = 0;
        message.HPOnx = 0;  % Compressor off
        message.SC02z = 0;  % Pump_hp off
        message.FC01z = 0;  % Fan speed
        message.FC01ON = 0; % Fan off
    end

    % Max compressor frequency 60 Hz
    if f_comp > 60
        f_comp = 60;
    end

    message.SC01x = f_comp; % Compressor
    message.VC01z = 0;      % Solenoid
    message.VC02z = 10;     % Theta_p1
    message.VC03z = 0;      % Theta_hp
    message.SC01z = 0;      % Pump_p1 off
end

function message = getMessage_tankCharge(f_comp, TT13z)
    if f_comp > 33 && TT13z < 45
        message.HPOnx = 1;  % Compressor on
        message.SC02z = 10; % Pump_hp on
    else
        f_comp = 0;
        message.HPOnx = 0;  % Compressor off
        message.SC02z = 0;  % Pump off
    end

    % Max compressor frequency 60 Hz
    if f_comp > 60
        f_comp = 60;
    end

    message.SC01x = f_comp; % Compressor
    message.FC01ON = 0;     % Fan on/off
    message.FC01z = 0;      % Fan speed
    message.VC01z = 0;      % Solenoid
    message.VC03z = 10;      % Theta_hp
    message.VC02z = 10;     % Theta_p1
    message.SC01z = 0;      % Pump_p1 off
end

function message = getMessage_tankDischarge()
    message.HPOnx = 0;      % Compressor off
    message.SC01x = 0;      % Compressor
    message.FC01ON = 10;    % Fan on
    message.FC01z = 5;      % Fan speed
    message.VC01z = 10;     % Solenoid
    message.VC02z = 10;     % Theta_p1
    message.VC03z = 10;     % Theta_hp
    message.SC01z = 10;     % Pump_p1 on
    message.SC02z = 0;      % Pump_hp off

end