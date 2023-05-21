c=standardConstants();
[~,~,~,ssPar] = Model(c);





%%
N=200;
room38=getAllCSVDataInFolder("Steps/Room_38Hz/");
room38 = room38(200:end-200,:);         %Selecting on data

room45=getAllCSVDataInFolder("Steps/Room45_Hz_2/");
room45 = room45(200:end-400,:);         %Selecting on data

room52=getAllCSVDataInFolder("Steps/Room_52Hz/");
room52 = room52(400:end-400,:);         %Selecting on data

tank35=getAllCSVDataInFolder("Steps/Tank_35Hz/");
tank35=tank35(200:end-1500,:);

tank45=getAllCSVDataInFolder("Steps/Tank_45Hz/");
tank45=tank45(200:end-600,:);

tank55=getAllCSVDataInFolder("Steps/Tank_55Hz/");
tank55=tank55(400:end-200,:);

r38=floor(rand(1,N)*height(room38))+1;        %Taking random samples
r45=floor(rand(1,N)*height(room45))+1;
r52=floor(rand(1,N)*height(room52))+1;

t38=floor(rand(1,N)*height(tank35))+1;
t45=floor(rand(1,N)*height(tank45))+1;
t52=floor(rand(1,N)*height(tank55))+1;

data=[room38(r38,:);room45(r45,:);room52(r52,:);tank35(t38,:);tank45(t45,:);tank55(t52,:)];

data=data(data.onx==1,:);

x1=optimvar('x1',1,'LowerBound',0,'UpperBound',1);
x2=optimvar('x2',1,'LowerBound',0,'UpperBound',1);


startingPoint.x1 = 1;
startingPoint.x2 = 1;


P_cp = 79.2.*data.SC01x -1983;
T_c=273+10;
T_h=data.TT07z+273;
P_est=(x1 + x2.*T_c./(T_h-T_c)) .*P_cp;

P_real=(data.TT09z-data.TT07z)*c.cw*c.mhp;

cost=(P_real-P_est)'*(P_real-P_est);

problem=optimproblem('Objective',cost)
solution=solve(problem,startingPoint)

c.x1=solution.x1;
c.x2=solution.x2


%%

hold on

plot(0.001*heatpumpPowerCalculation(data,c),'.')
plot(0.001*heatpumpPowerEstimat(data,c),'.')
grid on
xlabel("Sample number [ ]")
ylabel("Power [kW]")
legend("Realized","Estimated")
exportgraphics(gca,'FittingResult/power.pdf')
