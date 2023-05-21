function temp = generate_room_temp_ref(Ts,night_temp,day_temp, day_start,night_start,transition)

arguments
    Ts = 5*60;
    night_temp = 18;
    day_temp = 22;
    day_start = 7;
    night_start = 22;
    transition = 3.5
end

temp = ones(24*3600/Ts,1)*night_temp;
temp(day_start*3600/Ts:night_start*3600/Ts) = day_temp;

temp = smoothdata(temp,"gaussian",transition*3600/Ts);

%plot(Ts/3600:Ts/3600:24,temp)