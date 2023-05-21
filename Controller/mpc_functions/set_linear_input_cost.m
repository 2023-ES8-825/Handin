function mpc =  set_linear_input_cost(mpc,Cz)

mpc.dU_integrator = [kron(tril(ones(mpc.Np, mpc.Nc)),Cz') kron(ones(mpc.Np,1), Cz')];
