% Finalize configuration of MPC
function mpc = neo_mpc_finalize(mpc,opts)

arguments
    mpc;
    opts.sys_args = []
end

% Generated lifted matrices
sys = mpc.system;

[mpc.yA,mpc.yBu,mpc.yBdu] = generate_mpc_matrices(sys.A,sys.B,sys.C,mpc.Nc,mpc.Np,'sys_args',opts.sys_args,'ts',mpc.ts);
[mpc.xA,mpc.xBu,mpc.xBdu] = generate_mpc_matrices(sys.A,sys.B,'I',mpc.Nc,mpc.Np,'sys_args',opts.sys_args,'ts',mpc.ts);


mpc.Q = eye(mpc.n_outputs*mpc.Np); % Error penalty
mpc.R = zeros(mpc.n_inputs*mpc.Nc); % Actuation penalty