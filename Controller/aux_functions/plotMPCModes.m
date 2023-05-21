function plotMPCModes(mpc, future_modes, past_modes)

if ~isempty(past_modes)
    t_prev = (0:mpc.ts:length(past_modes)*mpc.ts- mpc.ts)/60/60;
    scatter(t_prev, past_modes, 'DisplayName','Previous modes')
end

hold on
t_pred = linspace(mpc.ts*length(past_modes),mpc.ts*length(future_modes) + mpc.ts*length(past_modes), length(future_modes))/60/60;
scatter(t_pred(2:end), future_modes(2:end), 'DisplayName','Planned modes')
plot(t_pred(1), future_modes(1), 'DisplayName','Current mode',"Marker","x","MarkerSize",15)

hold off

title("System modes")
yticks(1:1:3);
yticklabels({'Heat room', 'Charge tank', 'Discharge tank'})
ylim([0,4])
grid on

legend
