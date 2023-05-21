clear
close all
clc
set(0, 'DefaultAxesFontName', 'Times');

%%The purpose of this script is to test the functionality of the kalman filter
addpath '..'\logs\


addpath '..\..'\Modelling\'Full model'\
c = fitted_constants;
[A, B, Cy, c_out] = Model(c);
C_sens = [2,4,5,6,7,8];
C_est = [1,3];

kalman_process_noise = diag([0.01,0.01,0.01,0.01,0.5,0,0.5,0.5]);
var_temp = 0.0015;
kalman_measurement_noise = diag([var_temp,var_temp,var_temp,0.00000001,var_temp,var_temp]);
kalman = struct;
kalman.R = kalman_measurement_noise;
kalman.Q = kalman_process_noise;
kalman.Pp = eye(8)*0.1;

step_path = '..\..\labRepo\UDPInterface\Steps\';
tank_charge = getAllCSVDataInFolder(strcat(step_path,'Tank_45Hz\'));
room_charge = getAllCSVDataInFolder(strcat(step_path,'Room_38Hz\'));
tank_discharge = getAllCSVDataInFolder(strcat(step_path,'Tank_discharge\'));



plot(tank_charge.TT13z)
hold on
plot(room_charge.TT17z)
plot(tank_discharge.TT17z)
hold off

simulateStep(tank_charge, A,B,Cy, kalman,c_out, 'Charge tank', [0, 1, 1, 0, 3.5, 1])
simulateStep(tank_discharge(tank_discharge.SC01z == 10,:), A,B,Cy, kalman,c_out, 'Discharge tank', [1, 1, 1, 0, 0, 1])
simulateStep(room_charge, A,B,Cy, kalman,c_out, 'Heat room', [1, 1, 0, 1, 4, 1])

checkSwitching(c_out)

function checkSwitching(c_out)
    load ..\logs\'log 2023-05-21 - 12-04.mat'

    t = save_data.time - save_data.time(1);

    figure
    plot(t/3600, save_data.systemModes, 'o')
    xlabel("Time [hr]")
    yticks([1 2 3])
    ylim([0,4])
    yticklabels({'room charge', 'tank charge', ' tank discharge'})
    grid on
    exportgraphics(gcf, strcat("modes" ,".pdf"))


    y_index = 1;
    figure
    for i = 1:size(c_out.states,2)
        subplot(4,2,i)
        plot(t/3600,save_data.x(i,:))
        if c_out.states(i).isMeasureable
            hold on
            plot(t/3600, save_data.y(y_index,:))
            hold off
            state_var = mean((save_data.x(i,:) - save_data.y(y_index,:)).^2);
            %subtitle(strcat("Variance: ", string(state_var)))
            disp(state_var)
            y_index = y_index+1;
        end
        xlabel("Time [hr]")
        if c_out.states(i).symbol ~= "x_d"
            ylabel("Temperature [^o C]")
        else
            ylabel("Disturbance []")
        end
        
        
        title(c_out.states(i).name)
    end
    exportgraphics(gcf, strcat("switching" ,".pdf"))
end


%Simulate for tank_charge
function simulateStep(data, A,B,C,kalman, c_out, name, sys_settings)
    ts = mean(diff(data.TimeHP));
    ts_mpc = 300;
    t = 0:ts_mpc:data.TimeHP(end)-data.TimeHP(1);

    sys_sett_data = kron(ones(length(data.TT13z),1),sys_settings);
    sys_sett_data(:,end) = data.TT03z;
    sys_sett_data = sys_sett_data(1:round(ts_mpc/ts):end,:);

    y = double([
            data.TT16z';
            data.TT11z';
            data.TT17z';
            ones(1, length(data.TT17z)); % Must be constant 1
            data.TT12z';
            data.TT13z';
        ]);
    y = y(:,1:round(ts_mpc/ts):end);
    x = zeros(8,size(y,2)+1);
    x(:,1) = [20, 20, 20, 20, 20, 1, 35,35]';
    u = [0; 0.182*(273 +8)./(273 + data.TT07z -(273 + 8) )];
    u = u(1:round(ts_mpc/ts):end);

    for i = 1:size(y,2)
    
        Ad = A(sys_sett_data(i,:));
        Bd = B(sys_sett_data(i,:));
    
        sys = c2d(ss(Ad,Bd,C,0), ts_mpc);
        Ad = sys.A;
        Bd = sys.B;
    
        
        x_est = Ad*x(:,i) + Bd*u(i);
        y_diff = y(:,i) - C*x_est;
        K = (kalman.Pp*C')/(C*kalman.Pp*C'+kalman.R);
        IKC = eye(8)-K*C;
        kalman.Pe = (IKC)*kalman.Pp*(IKC)' + K*kalman.R*K';
        kalman.Pp = Ad*kalman.Pe*Ad' + kalman.Q;
    
        x(:,i+1) = x_est + K*y_diff;
    
    end
    y_est = C*x;
    figure
    y_index = 1;
    for i = 1:size(x,1)
        subplot(4,2,i)
        plot(t/3600, x(i,2:end))
        if c_out.states(i).isMeasureable
            hold on
            plot(t/3600,y(y_index,:))
            hold off
            %subtitle(strcat("Variance: ", string(mean((y_est(y_index,2:end)-y(y_index,:)).^2))))
            %disp(cov(y_est(y_index,2:end)-y(y_index,:)))
            disp(mean((y_est(y_index,2:end)-y(y_index,:)).^2))
            y_index = y_index + 1;
        end
        xlabel("Time [hr]")
        if c_out.states(i).symbol ~= "x_d"
            ylabel("Temperature [^o C]")
        else
            ylabel("Disturbance []")
        end
        
        title(c_out.states(i).name)
    end
    %sgtitle(name)
    exportgraphics(gcf, strcat(name ,".pdf"))
end


function [data] = getAllCSVDataInFolder(folder)
    folderinfo = fullfile(folder, '*.csv');
    files = dir(folderinfo);
    data = [];
    for i = 1:length(files)
        data = [data; readtable(strcat(folder,files(i).name))];
    end
end