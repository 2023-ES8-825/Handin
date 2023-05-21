% Initalize MPC object
function mpc = neo_mpc_init(A,B,Cy,Cz,ts,Nc,Np,Q,R)

arguments
 A,B,Cy,Cz,ts,Nc,Np
 Q = [];
 R = [];
end

mpc.ts = ts;
mpc.Nc = Nc;
mpc.Np = Np;

% Determine if system matrices are functions
mpc.Aisfunc = class(A) == "function_handle";
mpc.Bisfunc = class(B) == "function_handle";
mpc.Cyisfunc = class(Cy) == "function_handle";
mpc.Czisfunc = class(Cz) == "function_handle";
mpc.sys_is_func = mpc.Aisfunc || mpc.Bisfunc || mpc.Cyisfunc || mpc.Czisfunc;

mpc.Cz = Cz;

% Initialize discrete system
if ~ mpc.sys_is_func

    mpc.system = c2d(ss(A,B,Cy,0),ts);

    % Save system size information
    mpc.n_states = size(mpc.system.A,2);
    mpc.n_inputs = size(mpc.system.B,2);
    mpc.n_outputs = size(mpc.system.C,1);
    mpc.n_controlled_outputs = size(Cz,1);

else
    disp("MPC INFO : One or more system matrices are identified as functions")
    mpc.system.A = A;
    mpc.system.B = B;
    mpc.system.C = Cy;

    % Save system size information

    if mpc.Aisfunc; sizeA = size(A(randn(1000,1))); else;  sizeA = size(A); end
    if mpc.Bisfunc; sizeB = size(B(randn(1000,1))); else;  sizeB = size(B); end
    if mpc.Cyisfunc; sizeCy = size(Cy(randn(1000,1))); else;  sizeCy = size(Cy); end
    if mpc.Czisfunc; sizeCz = size(Cz(randn(1000,1))); else;  sizeCz = size(Cz); end

    mpc.n_states = sizeA(2);
    mpc.n_inputs = sizeB(2);
    mpc.n_outputs = sizeCy(1);
    mpc.n_controlled_outputs = sizeCz(1);
end

if isempty(Q) % Reference deviation penalty
    mpc.Q = eye(mpc.n_controlled_outputs*mpc.Np); 
else
    mpc.Q = Q;
end

if isempty(R) % Actuation change penalty
    mpc.R = zeros(mpc.n_inputs*mpc.Nc);
else
    mpc.R = R;
end

% Slack variable
mpc.rho = [];

% Crate constraint entries
mpc.D_input_rate_constraint = [];
mpc.F_input_constraint = [];
mpc.G_output_constraint = [];

% Previous information
mpc.x_prev = [];
mpc.U_prev = [];
mpc.dU_saved = [];

if ~ mpc.sys_is_func
    mpc = neo_mpc_generate_matrices(mpc);
end
