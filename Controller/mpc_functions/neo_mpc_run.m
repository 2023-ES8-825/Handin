function [u,dU,Y_pred] = neo_mpc_run(mpc,X0,r,prices,u_init)
% Execute one timestep of the MPC controller.
% Arguments
%   mpc     : Configured MPC struct
%   X0      : Current state (estimate)
%   r       : Reference to follow
% Returns* 
%   u       : Actuation signal to be applies
%   dU      : Future predicted changes in u
%   Y_pred  : Future predicted system outputs

arguments
    mpc; X0; r;
    prices = [];
    u_init = 0;
end

persistent dU_saved
if isempty(dU_saved)
    dU_saved = zeros(mpc.Nc*mpc.n_inputs,1);
end

persistent U_prev
if isempty(U_prev)
    U_prev = ones(mpc.n_inputs,1)*u_init;
end

% Initialize problem
Problem = optimproblem();
optimvar_init = struct;
optimvar_init.dU = dU_saved;
J = 0;

% Reformulate dU, U and Y constraints in terms of only dU
[lhs, rhs] = neo_mpc_unify_constraints(mpc,U_prev,X0);

% Array of optimization variables
dU = optimvar('dU',mpc.Nc*mpc.n_inputs, 1);

% Define reference following cost function
K = 2*mpc.yBdu'*mpc.Q*(r - mpc.yA*X0 - mpc.yBu*U_prev);
H = mpc.yBdu' * mpc.Q * mpc.yBdu + mpc.R;

J = J - dU'*K + dU'*H*dU;

% Handle price term
if ~isempty(prices)
    U = mpc.dU_integrator * [dU ; U_prev];
    J = J + prices(1:length(U))'*U;
end  

% Short-hand definitions
D = mpc.D_input_rate_constraint;
F = mpc.F_input_constraint;
G = mpc.G_output_constraint;

% Apply slack variables
if ~isempty(lhs) && ~isempty(rhs) && ~isempty(mpc.rho)

    % Append slack variables to cost function using 2-norm
    epsilon = optimvar('epsilon',size(G,1), 1);
    J = J + mpc.rho*(epsilon'*epsilon); % 2-norm

    % Append slack variables to constraints right-hand-side
    rhs = rhs + [zeros(size(D,1),1);zeros(size(F,1),1);epsilon];
    Problem.Constraints.epsilon = epsilon >= 0;

    % Define initial values for epsilon if needed
    optimvar_init.epsilon = zeros(size(G,1),1);
end

% Apply constraints
if ~isempty(lhs) && ~isempty(rhs)
    Problem.Constraints.combined = lhs*dU <= rhs;
end

% Assign objective function
Problem.Objective = J;

% Get optimal MPC solution
solution = solve(Problem,optimvar_init);

% Evaluate solution
if ~isempty(solution.dU)
    dU = solution.dU;
else
    disp("MPC ERROR : Problem was infeasible, applying previous command");
    dU = [dU_saved((mpc.n_outputs+1):end) ; zeros(mpc.n_outputs,1)];
end

% Predict system outputs
dU_saved = dU;
Y_pred = mpc.yA*X0 + mpc.yBu*U_prev + mpc.yBdu*dU;

% Return first actuation
U_prev = U_prev + dU(1:mpc.n_inputs);
u = U_prev;