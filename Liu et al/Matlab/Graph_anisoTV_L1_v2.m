function u=Graph_anisoTV_L1_v2(F,lambda,nNeighbors,biThread)
% Solve
%    min TV(u) + lambda * ||u-F||_L1
%   OR
%    min TV(u) + sum_i ( lambda_i |u_i - F_i| )
%
% Difference between 
%     Graph_anisoTV_L1_v2
% and
%     Graph_anisoTV_L1_v2_consistent_weights:
% the latter file use the new neighbhor weights described in Rice CAAM TR07-09 that
% are better than those used before in the sense they better approximate the true
% isotropic TV.
%
% F = input 1/8/16-bit image 2D/3D matrix
%                1-bit F: "logical", values: 0, 1
%                8-bit F: "uint8", values: 0, 1, ..., 255
%               16-bit F: "uint16",values: 0, 1, ..., 65535
% lambda = a positive scalar OR a matrix with positive scalars of double type
% nNeighbors =  4:  anisotropic  4 neighbors for 2D images
%            or 8: anisotropic 16 neighbors for 2D images
%            or 16: anisotropic 16 neighbors for 2D images
%            or 5:  isotropic    5 neighbors for 2D binary images, no longer provided
%            or 6:  anisotropic  6 neighbors for 3D images
% biThread: binary number 'xy' where
%              x={0,1} switch for UP thread
%              y={0,1} switch for DN thread
%           So, set
%           xy = 1 for DN thread;
%           xy = 2 for UP thread;
%           xy = 3 for BOTH threads (now turned off for technical reasons)
%
% Data scaling example:
%           To solve
%             min TV(u) + mu ||u-f||_L1, where u and f are matrices with entries in [0,1],
%           using the 16-bit resolution, apply the following steps:
%
%           bit = 16;
%           nNeighbors = 4;
%           scale = 2^bit - 1;
%           F = uint16(scale*f); % map to 16 positive integers
%           lambda = mu;
%           u = Graph_anisoTV_L1_v2(F,lambda,nNeighbors,biThread);
%           u = double(u)/scale; % map to [0,1]
%
% Author: Wotao Yin, wotao.yin@rice.edu, 2010

%% test input
if ~(exist('F','var') || exist('lambda','var')...
   ||exist('nNeighbors','var') || exist('biThread','var'))
    warndlg('No input is specified. Running a tiny demo.');
    F=logical([0 1 1; 1 0 0]);
    lambda = 2.0;
    nNeighbors = 4;
    biThread = 2;
end

if ~exist('biThread','var'); biThread=2; end

%% Graph neighborhood topology
    %% type information
    % each row correspondes to an arc
    % 1st element: 0 = incoming; 1 = outgoing;
    %              2 = related arcs;
    %              3 = incoming s arc;
    %              4 = outgoing t arc;
    %              5 = related incoming s arc;
    %              6 = ralated outgoing t arc;
    %              ** Now: only 1, 3, 4 are allowed **
    % 2nd element: outgoing arc capacity (except for s-arc, that's the incoming capacity)
    % (3rd,4th) elements: (row col) offset to the partner node if not terminal arc
ndim = ndims(F);
if (any(size(F)==1)); error('There is a trivial dimension (size=1) in F. Please correct.'); end

if (nNeighbors==4 && ndim==2)
     
    % 2D: 4-point neighbors  (ANISOTROPIC)
    type = [
        1   1          0   1 ;      
        1   1          1   0 ;
        1   1          0  -1 ;
        1   1         -1   0 ]';

elseif (nNeighbors==16 && ndim==2)
    
    % 2D: 16-point neighbor  (ANISOTROPIC)
    type = [
        1   0.26        0   1;
        1   0.26        1   0;
        1   0.26        0  -1;
        1   0.26       -1   0;
        1   0.19        1   1;
        1   0.19        1  -1;
        1   0.19       -1  -1;
        1   0.19       -1   1;
        1   0.06        1   2;
        1   0.06        2   1;
        1   0.06        2  -1;
        1   0.06        1  -2;
        1   0.06       -1  -2;
        1   0.06       -2  -1;
        1   0.06       -2   1;
        1   0.06       -1  +2]';
    
elseif (nNeighbors==5 && ndim==2 && isa(F, 'logical'))
    % coeff's for Nodes 1: (i,j), 2: (i+1,j), 3: (i,j+1)
    % For S=1, T=0:
    % a: 1 -> 2: 1              down
    % b: 2 -> 1: sqrt(2)-1      up
    % c: 1 -> 3: sqrt(2)-1      right
    % d: 3 -> 1: 1              left
    % e: 2 -> 3: 2-sqrt(2)      up-right
    % f: 3 -> 2: 0
    % 
    % For S=0, T=1:
    % a: 2 -> 1: sqrt(2)-1      up
    % b: 1 -> 2: 1              down
    % c: 3 -> 1: 1              left
    % d: 1 -> 3: sqrt(2)-1      right
    % e: 3 -> 2: 0
    % f: 2 -> 3: 2-sqrt(2)      up-right
    % 
    % obj   |   1   2   3   |   arcs in cut
    %---------------------------------------
    %   0   |   0   0   0   |   none
    %   1   |   0   0   1   |   d, f
    %   1   |   0   1   0   |   b, e
    %sqrt(2)|   0   1   1   |   b, d
    %sqrt(2)|   1   0   0   |   a, c
    %   1   |   1   0   1   |   a, f
    %   1   |   1   1   0   |   c, e
    %   0   |   1   1   1   |   none
    
    stmo = sqrt(2)-1;
    tmst = 2-sqrt(2);
    % 2D: 5-point neighbor (ISOTROPIC)
    type = [
        1   stmo        0   1;  % right: sqrt(2)-1
        1   1.00        1   0;  % down:  1
        1   1.00        0  -1;  % left:  1
        1   stmo       -1   0;  % up:    sqrt(2)-1
        1   tmst       -1   1;  % up-right: 2-sqrt(2)
        1   0           1  -1]';% down-left:0
     
    %% Warning: this implements sqrt((grad_1 x)^2 + (grad_2 x)^2) for
    %% binary x. The results are not as good as expected since the output
    %% of the graph-cut code must also be logical. It turns out that the
    %% double solution of minimizing sqrt((grad_1 x)^2 + (grad_2 x)^2) is
    %% not necessarily binary. 

elseif (nNeighbors==6 && ndim==3)
    
    % 3D: 6-point neighbor  (ANISOTROPIC)
    type = [
        1   1           0   0   1;
        1   1           0   1   0;
        1   1           0   0  -1;
        1   1           0  -1   0;
        1   1           1   0   0;
        1   1          -1   0   0]';
else
    error('Unsupported data, dimension, or neighbor type.');
end
        
    
%% call parametric max-flow
if (isa(F, 'logical'))
    if (isscalar(lambda))
        u = mt_TV_L1_1bit(F,lambda,type,biThread);
    else
        u = mt_TV_L1_1bit_A(F,lambda,type,biThread);
    end
elseif (isa(F, 'uint8'))
    if (isscalar(lambda))
        u = mt_TV_L1_8bit(F,lambda,type,biThread);
    else
        u = mt_TV_L1_8bit_A(F,lambda,type,biThread);
    end
elseif (isa(F, 'uint16'))
    if (isscalar(lambda))
        u = mt_TV_L1_16bit(F,lambda,type,biThread);
    else
        u = mt_TV_L1_16bit_A(F,lambda,type,biThread);
    end
else
    error('This program only supports inputs of type uint8 or uint16.');
end

%% Show final energy for verification
%energy_l2TVL1(F,u,lambda);