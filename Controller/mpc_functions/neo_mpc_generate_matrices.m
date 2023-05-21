function mpc = neo_mpc_generate_matrices(mpc,opts)

arguments
    mpc;
    opts.sys_args = []
end

A = mpc.system.A;
B = mpc.system.B;

Nc = mpc.Nc;
Np = mpc.Np;

[mpc.yA,mpc.yBu,mpc.yBdu] = generate_mpc_matrices(A,B,mpc.Cz,Nc,Np,"sys_args",opts.sys_args,"ts",mpc.ts);
[mpc.xA,mpc.xBu,mpc.xBdu] = generate_mpc_matrices(A,B,'I',Nc,Np,"sys_args",opts.sys_args,"ts",mpc.ts);