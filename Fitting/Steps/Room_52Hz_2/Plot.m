

data = [readtable("Log1682595590.csv")];


data.TimeHP = data.TimeHP/3600-data.TimeHP(1)/3600;

figure(1)
plot(data.TimeHP,data.TT17z)
figure(2)
plot(data.TimeHP,data.onx)
