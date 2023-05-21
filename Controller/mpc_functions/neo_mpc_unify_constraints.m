function [lhs,rhs] = unify_constraints(mpc,U_prev,X)

% Allocate lhs and rhs matrices
lhs = zeros( ...
    size(mpc.D_input_rate_constraint,1)+ ...
    size(mpc.F_input_constraint,1)+ ...
    size(mpc.G_output_constraint,1),mpc.Nc*mpc.n_inputs); 

rhs = zeros( ...
    size(mpc.D_input_rate_constraint,1)+ ...
    size(mpc.F_input_constraint,1)+ ...
    size(mpc.G_output_constraint,1),1);

% Short-hand definitions
D = mpc.D_input_rate_constraint;
F = mpc.F_input_constraint;
G = mpc.G_output_constraint;

Dh = size(D,1);
Fh = size(F,1);
Gh = size(G,1);

% Fill with contents
if ~isempty(D)
    lhs( 1 : Dh ,:) = D(:,1:end-1);
    rhs( 1 : Dh ,:) = -D(:,end);
end
if ~isempty(F)
    lhs( 1+Dh : Dh+Fh ,:) = F(:,1:end-1);
    rhs( 1+Dh : Dh+Fh ,:) = -F(:,1:mpc.n_inputs)*U_prev-F(:,end);
end
if ~isempty(G)
    lhs( 1+Dh+Fh : Dh+Fh+Gh ,:) = G(:,1:end-1)*mpc.yBdu;
    rhs( 1+Dh+Fh : Dh+Fh+Gh ,:) = -G(:,1:end-1)*(mpc.yA*X + mpc.yBu*U_prev) - G(:,end);
end