c=standardConstants();
set(0, 'DefaultAxesFontName', 'Times');

%Fitting of room
c.Gwall=80; 	%OK
c.Mtr =400;		%OK

c.xGc=3/2;		%OK
c.Mhca = 5;		%OK
c.Mhcw = 5;		%OK

c.xa=0.469/1.4;	%OK

%Tank fitting
c.Gt = 450;		%OK
c.Mhxt = 80;    %OK
c.Mtank = 320;  %OK

c.divisionByZeroFix = 0.00000145;


%% Room 38 Hz
room38=getAllCSVDataInFolder("Steps/Room_38Hz/");
[A,B,C, ssPar] = Model(c);  
U=[0,0,1,0,5/1,10]; %Model settings




figure(1)
plotStepDataRoom(room38(200:end,:))


hold on
set(gca,'ColorOrderIndex',1)
[y,time,names]=simpleSimulation(room38(200:end,:),A,B,C,U,100,c,ssPar);
plot(time/3600,y(1:3,:),LineStyle="- -",Linewidth=3)
hold off
l=legend('$T_{ca,N_c}$', '$T_{cw,N_c}$', '$T_{tr}$');
set(l,'Interpreter','Latex');
legend('Location', 'southeast')
xlabel('Time [hr]')
ylabel('Temperature [C^\circ]')

exportgraphics(gca,'FittingResult/room38.pdf')



%% Room 45
room45=getAllCSVDataInFolder("Steps/Room45_Hz_2/");
[A,B,C, ssPar] = Model(c);  
U=[0,0,1,0,5/1,10]; %Model settings

figure(2)
plotStepDataRoom(room45(1:end-100,:))

hold on
set(gca,'ColorOrderIndex',1)
[y,time,names]=simpleSimulation(room45(1:end-100,:),A,B,C,U,100,c,ssPar);
plot(time/3600,y(1:3,:),LineStyle="- -",Linewidth=3)
hold off
l=legend('$T_{ca,N_c}$', '$T_{cw,N_c}$', '$T_{tr}$');
set(l,'Interpreter','Latex');
legend('Location', 'southeast')
xlabel('Time [hr]')
ylabel('Temperature [C^\circ]')
exportgraphics(gca,'FittingResult/room45.pdf')

%% Room 52
room52=getAllCSVDataInFolder("Steps/Room_52Hz_2/");
[A,B,C, ssPar] = Model(c);  
U=[0,0,1,0,5/1,10]; %Model settings

figure(3)
plotStepDataRoom(room52(1:end-2260,:))

hold on
set(gca,'ColorOrderIndex',1)
[y,time,names]=simpleSimulation(room52(1:end-2260,:),A,B,C,U,100,c,ssPar);
plot(time/3600,y(1:3,:),LineStyle="- -",Linewidth=3)
hold off
l=legend('$T_{ca,N_c}$', '$T_{cw,N_c}$', '$T_{tr}$');
set(l,'Interpreter','Latex');
legend('Location', 'southeast')
xlabel('Time [hr]')
ylabel('Temperature [C^\circ]')
exportgraphics(gca,'FittingResult/room52.pdf')

%%




%% Tank 35 Hz
tank35=getAllCSVDataInFolder("Steps/Tank_35Hz/");
[A,B,C, ssPar] = Model(c);  



U=[1,0,1,0,0/1.4,10]; %Model settings
sys=c2d(ss(A(U),B(U),C,0),10)

figure(4)
plotStepDataTank(tank35(1:end-1200,:))

hold on
set(gca,'ColorOrderIndex',1)
[y,time,names]=simpleSimulation(tank35(1:end-1200,:),A,B,C,U,100,c,ssPar);
plot(time/3600,y(4:5,:),LineStyle="- -",Linewidth=3)
hold off
l=legend('$T_{t,N_t}$', '$T_{Tank}$');
set(l,'Interpreter','Latex');
legend('Location', 'southeast')
xlabel('Time [hr]')
ylabel('Temperature [C^\circ]')
exportgraphics(gca,'FittingResult/tank35.pdf')

%% Tank 45 Hz
tank45=getAllCSVDataInFolder("Steps/Tank_45Hz/");
[A,B,C, ssPar] = Model(c);  



U=[1,0,1,0,0/1.4,10]; %Model settings
sys=c2d(ss(A(U),B(U),C,0),10)

figure(5)
plotStepDataTank(tank45(80:end-400,:))

hold on
set(gca,'ColorOrderIndex',1)
[y,time,names]=simpleSimulation(tank45(80:end-400,:),A,B,C,U,100,c,ssPar);
plot(time/3600,y(4:5,:),LineStyle="- -",Linewidth=3)
hold off
l=legend('$T_{t,N_t}$', '$T_{Tank}$');
set(l,'Interpreter','Latex');
legend('Location', 'southeast')
xlabel('Time [hr]')
ylabel('Temperature [C^\circ]')
exportgraphics(gca,'FittingResult/tank45.pdf')



%% Tank 55 Hz
tank55=getAllCSVDataInFolder("Steps/Tank_55Hz/");
[A,B,C, ssPar] = Model(c);  



U=[1,0,1,0,0/1.4,10]; %Model settings
sys=c2d(ss(A(U),B(U),C,0),10)

figure(6)
plotStepDataTank(tank55(80:end-10,:))

hold on
set(gca,'ColorOrderIndex',1)
[y,time,names]=simpleSimulation(tank55(80:end-10,:),A,B,C,U,100,c,ssPar);
plot(time/3600,y(4:5,:),LineStyle="- -",Linewidth=3)
hold off
l=legend('$T_{t,N_t}$', '$T_{Tank}$');
set(l,'Interpreter','Latex');
legend('Location', 'southeast')
xlabel('Time [hr]')
ylabel('Temperature [C^\circ]')
exportgraphics(gca,'FittingResult/tank55.pdf')



%% Tank discharge

tankDis=readtable("Steps/TankDischarge/Log1682696127.csv");
tankDis = [tankDis; readtable("Steps/TankDischarge/Log1682703328.csv")];
[A,B,C, ssPar] = Model(c);  
U=[1,1,0,1,5/1,10.5]; %Model settings

figure(7)
plotStepDataDischarge(tankDis(280:end,:));

hold on
set(gca,'ColorOrderIndex',1)
[y,time,names]=simpleSimulationNoPower(tankDis(280:end,:),A,B,C,U,100,c,ssPar);
z=[1,2,3,5];
plot(time/3600,y(z,:),LineStyle="- -",Linewidth=3)
hold off
l=legend('$T_{ca,N_c}$', '$T_{cw,N_c}$', '$T_{tr}$','$T_{Tank}$');
set(l,'Interpreter','Latex');
legend('Location', 'northeast')
xlabel('Time [hr]')
ylabel('Temperature [C^\circ]')
exportgraphics(gca,'FittingResult/tankDischarge.pdf')






%%

function [y_save,t,yLabels]=simpleSimulation(data,A,B,C,U,Ts,c,ssPar)

    
    stepTime = data.TimeHP(end)-data.TimeHP(1);
    data.TimeRel=data.TimeHP-data.TimeHP(1);
    n_simSamples = round(stepTime/Ts);
    y_save = zeros(size(C,1),n_simSamples);
    t=(1:n_simSamples)*Ts;
    
  
    %Initial conditions
    x(1)=data.TT17z(1);     %Air heating coil
    x(2)=data.TT17z(1);     %Air heating coil
    x(3)=data.TT17z(1);     %Water heating coil
    x(4)=data.TT17z(1);     %Water heating coil
    x(5)=data.TT17z(1);     %Target room
    x(6)=1;                 %Distrubance
    x(7)=data.TT13z(1);     %Heat exghanger
    x(8)=data.TT13z(1);     %Temperature of tank
    x=x';

    %Simulation
    for i=1:n_simSamples
        [~, index]=min(abs(data.TimeRel-i*Ts));         %Find matching time
        u=heatpumpPowerCalculation(data(index,:),c);
        %u=0;
        U(6)=data.TT03z(index);                         %Adjust for outdoor temp
        sys= c2d(ss(A(U),B(U),C,0),Ts);
        x=(sys.A)*x+sys.B*u;

        y_save(:,i)=C*x;
    end
    y_save = y_save([1, 2, 3, 5, 6],:);

    %Label names
    index = 1;
    strctOut = struct;
    yLabels = [];
    for i = 1:length(ssPar.states)
        if ssPar.states(i).isMeasureable && ssPar.states(i).sensor ~= ""
            yLabels = [yLabels; ssPar.states(i).name+": sim"];
            index = index +1;
        end
    end

    %yLabels = yLabels([1, 2, 3, 5, 6])

end

function [y_save,t,yLabels]=simpleSimulationNoPower(data,A,B,C,U,Ts,c,ssPar)

    
    stepTime = data.TimeHP(end)-data.TimeHP(1);
    data.TimeRel=data.TimeHP-data.TimeHP(1);
    n_simSamples = round(stepTime/Ts);
    y_save = zeros(size(C,1),n_simSamples);
    t=(1:n_simSamples)*Ts;
    
  
    %Initial conditions
    x(1)=data.TT17z(1);     %Air heating coil
    x(2)=data.TT17z(1);     %Air heating coil
    x(3)=data.TT17z(1);     %Water heating coil
    x(4)=data.TT17z(1);     %Water heating coil
    x(5)=data.TT17z(1);     %Target room
    x(6)=1;                 %Distrubance
    x(7)=data.TT13z(1);     %Heat exghanger
    x(8)=data.TT13z(1);     %Temperature of tank
    x=x';

    %Simulation
    for i=1:n_simSamples
        [~, index]=min(abs(data.TimeRel-i*Ts));         %Find matching time
        %u=heatpumpPowerCalculation(data(index,:),c);
        u=0;
        U(6)=data.TT03z(index);                         %Adjust for outdoor temp
        sys= c2d(ss(A(U),B(U),C,0),Ts);
        x=(sys.A)*x+sys.B*u;

        y_save(:,i)=C*x;
    end
    y_save = y_save([1, 2, 3, 5, 6],:);

    %Label names
    index = 1;
    strctOut = struct;
    yLabels = [];
    for i = 1:length(ssPar.states)
        if ssPar.states(i).isMeasureable && ssPar.states(i).sensor ~= ""
            yLabels = [yLabels; ssPar.states(i).name+": sim"];
            index = index +1;
        end
    end

    %yLabels = yLabels([1, 2, 3, 5, 6])

end


function P_hp = heatpumpPowerEstimat(data, c)

P_cp = 79.2*data.JT01x-1987;

T_c=273+10;
T_h=data.TT07z;

P_hp=(c.x1+c.x2*T_c/(T_h-T_c))*P_cp;

end

function plotStepDataRoom(data)
relativeTime = (data.TimeHP-data.TimeHP(1))/3600;
plot(relativeTime,data.TT16z,relativeTime,data.TT11z,relativeTime,data.TT17z)

end

function plotStepDataTank(data)
relativeTime = (data.TimeHP-data.TimeHP(1))/3600;
plot(relativeTime,data.TT12z,relativeTime,data.TT13z)
end


function plotStepDataDischarge(data)
relativeTime = (data.TimeHP-data.TimeHP(1))/3600;
plot(relativeTime,data.TT16z,relativeTime,data.TT11z,relativeTime,data.TT17z,relativeTime,data.TT13z)
end



