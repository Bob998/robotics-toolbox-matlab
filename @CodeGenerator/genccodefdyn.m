%CODEGENERATOR.GENCCODEFDYN Generate C-code for forward dynamics
%
% cGen.genccodeinvdyn() generates a robot-specific C-code to compute the
% forward dynamics.
%
% Notes::
% - Is called by CodeGenerator.genfdyn if cGen has active flag genccode or
%   genmex.
% - The .c and .h files are generated in the directory specified
%   by the ccodepath property of the CodeGenerator object.
% - The resulting C-function is composed of previously generated C-functions
%   for the inertia matrix, Coriolis matrix, vector of gravitational load and
%   joint friction vector. This function recombines these components to
%   compute the forward dynamics.
%
% Author::
%  Joern Malzahn, (joern.malzahn@tu-dortmund.de)
%
% See also CodeGenerator.CodeGenerator, CodeGenerator.genfdyn,CodeGenerator.genccodeinvdyn.

% Copyright (C) 2012-2014, by Joern Malzahn
%
% This file is part of The Robotics Toolbox for Matlab (RTB).
%
% RTB is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% RTB is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Lesser General Public License for more details.
%
% You should have received a copy of the GNU Leser General Public License
% along with RTB.  If not, see <http://www.gnu.org/licenses/>.
%
% http://www.petercorke.com

function [ ] = genccodefdyn( CGen )

checkexistanceofcfunctions(CGen);
[Q, QD] = CGen.rob.gencoords;
tau = CGen.rob.genforces;
nJoints = CGen.rob.n;

% Check for existance of C-code directories
srcDir = fullfile(CGen.ccodepath,'src');
hdrDir = fullfile(CGen.ccodepath,'include');
if ~exist(srcDir,'dir')
    mkdir(srcDir);
end
if ~exist(hdrDir,'dir')
    mkdir(hdrDir);
end

symname = 'fdyn';
outputname = 'QDD';

funname = [CGen.getrobfname,'_accel'];
funfilename = [funname,'.c'];
hfilename = [funname,'.h'];

CGen.logmsg([datestr(now),'\tGenerating forward dynamics C-code']);


% Convert symbolic expression into C-code
dummy = sym(zeros(nJoints,1));
[funstr hstring] = ccodefunctionstring(dummy,...
    'funname',funname,...
    'vars',{Q, QD, tau},'output',outputname,...
    'flag',1);

% Create the function description header
hStruct = createHeaderStruct(CGen.rob,funname); % create header
hStruct.calls = hstring;
hFString = CGen.constructheaderstringc(hStruct);

%% Generate C implementation file
fid = fopen(fullfile(srcDir,funfilename),'w+');

% Includes
fprintf(fid,'%s\n\n',...
    ['#include "', hfilename,'"']);
% fprintf(fid,'%s\n%s\n\n',...
%     '#include "mex.h"',...
%     ['#include "',hfilename,'"']);
% Function
fprintf(fid,'%s{\n\n',funstr);


% Allocate memory
fprintf(fid,'\t%s\n','/* declare variables */');
fprintf(fid,'\t%s\n','int iCol;');
fprintf(fid,'\t%s\n',['double inertia[',num2str(nJoints),'][',num2str(nJoints),'];']);
fprintf(fid,'\t%s\n',['double invinertia[',num2str(nJoints),'][',num2str(nJoints),'];']);
fprintf(fid,'\t%s\n',['double coriolis[',num2str(nJoints),'][',num2str(nJoints),'];']);
fprintf(fid,'\t%s\n',['double gravload[',num2str(nJoints),'][1];']);
fprintf(fid,'\t%s\n',['double friction[',num2str(nJoints),'][1];']);
fprintf(fid,'\t%s\n',['double tmpTau[1][',num2str(nJoints),'];']);

fprintf(fid,'\t%s\n','/* !!! DEBUGGING !!! >>>>> */');
fprintf(fid,'\t%s\n','FILE *fp;');
fprintf(fid,'\t%s\n','int i;');

fprintf(fid,'\t%s\n','fp = fopen("numbers_ccode.txt", "a");');

fprintf(fid,'\t%s\n','if(fp == NULL) {');
fprintf(fid,'\t%s\n','	printf("Datei konnte nicht geoeffnet werden.\n");');
fprintf(fid,'\t%s\n','}else {');

fprintf(fid,'\t%s\n','/* <<<<< !!! DEBUGGING !!! */');

fprintf(fid,'%s\n',' '); % empty line

fprintf(fid,'\t%s\n','/* call the computational routines */');
fprintf(fid,'\t%s\n',[CGen.getrobfname,'_','inertia(inertia, input1);']);
fprintf(fid,'\t%s\n',['gaussjordan(inertia, invinertia, ',num2str(nJoints),');']);
fprintf(fid,'\t%s\n',[CGen.getrobfname,'_','coriolis(coriolis, input1, input2);']);
fprintf(fid,'\t%s\n',[CGen.getrobfname,'_','gravload(gravload, input1);']);
fprintf(fid,'\t%s\n',[CGen.getrobfname,'_','friction(friction, input2);']);

fprintf(fid,'%s\n',' '); % empty line

fprintf(fid,'\t%s\n','/* fill temporary vector */');
fprintf(fid,'\t%s\n',['matvecprod(tmpTau, coriolis, input2,',num2str(nJoints),',',num2str(nJoints),');']);

fprintf(fid,'\t%s\n','/* !!! DEBUGGING !!! >>>>> */');

fprintf(fid,'\t%s\n','fprintf(fp, "coriolis: %f %f %f\n", tmpTau[0][0], tmpTau[0][1], tmpTau[0][2]);');

fprintf(fid,'\t%s\n','fprintf(fp, "\n\n");');

fprintf(fid,'\t%s\n','/* <<<<< !!! DEBUGGING !!! */');

fprintf(fid,'\t%s\n',['for (iCol = 0; iCol < ',num2str(nJoints),'; iCol++){']);
fprintf(fid,'\t\t%s\n','tmpTau[0][iCol] = input3[iCol] -  tmpTau[0][iCol] - gravload[iCol][0] + friction[iCol][0];');
fprintf(fid,'\t%s\n','}');

fprintf(fid,'\t%s\n','/* compute acceleration */');
fprintf(fid,'\t%s\n',['matvecprod(QDD, invinertia, tmpTau,',num2str(nJoints),',',num2str(nJoints),');']);

fprintf(fid,'\t%s\n','/* !!! DEBUGGING !!! >>>>> */');
 

fprintf(fid,'\t%s\n','fprintf(fp,"q: %f %f %f\n", input1[0],input1[1],input1[2]);');
fprintf(fid,'\t%s\n','fprintf(fp,"qd: %f %f %f\n", input2[0],input2[1],input2[2]);');
fprintf(fid,'\t%s\n','fprintf(fp,"tau: %f %f %f\n", input3[0],input3[1],input3[2]);');

fprintf(fid,'\t%s\n','fprintf(fp, "Inertia 1: %f %f %f\n", inertia[0][0],inertia[0][1],inertia[0][2]);');
fprintf(fid,'\t%s\n','fprintf(fp, "Inertia 2: %f %f %f\n", inertia[1][0],inertia[1][1],inertia[1][2]);');
fprintf(fid,'\t%s\n','fprintf(fp, "Inertia 3: %f %f %f\n", inertia[2][0],inertia[2][1],inertia[2][2]);');

fprintf(fid,'\t%s\n','fprintf(fp,"\n\n");');

fprintf(fid,'\t%s\n','fprintf(fp, "Inv Inertia 1: %f %f %f\n", invinertia[0][0],invinertia[0][1],invinertia[0][2]);');
fprintf(fid,'\t%s\n','fprintf(fp, "Inv Inertia 2: %f %f %f\n", invinertia[1][0],invinertia[1][1],invinertia[1][2]);');
fprintf(fid,'\t%s\n','fprintf(fp, "Inv Inertia 3: %f %f %f\n", invinertia[2][0],invinertia[2][1],invinertia[2][2]);');

fprintf(fid,'\t%s\n','fprintf(fp, "\n\n");');

fprintf(fid,'\t%s\n','fprintf(fp, "QDD: %f %f %f\n", QDD[0][0], QDD[0][1], QDD[0][2]);');

fprintf(fid,'\t%s\n','fprintf(fp, "\n\n");');

fprintf(fid,'\t%s\n','fprintf(fp, "tmpTau: %f %f %f\n", tmpTau[0][0], tmpTau[0][1], tmpTau[0][2]);');
% fprintf(fid,'\t%s\n','fprintf(fp, "tmpTau: %f %f %f\n", tmpTau[0], tmpTau[1], tmpTau[2]);');

fprintf(fid,'\t%s\n','fprintf(fp, "\n\n");');

fprintf(fid,'\t%s\n','fprintf(fp, "\n ------------------------------------------- \n");');

fprintf(fid,'\t%s\n','	fclose(fp);');
fprintf(fid,'\t%s\n','}');

fprintf(fid,'\t%s\n','/* <<<<< !!! DEBUGGING !!! */');

fprintf(fid,'%s\n','}');

fclose(fid);


%% Generate C header file
fid = fopen(fullfile(hdrDir,hfilename),'w+');

% Function description header
fprintf(fid,'%s\n\n',hFString);

% Include guard
fprintf(fid,'%s\n%s\n\n',...
    ['#ifndef ', upper([funname,'_h'])],...
    ['#define ', upper([funname,'_h'])]);

% Includes
fprintf(fid,'%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n',...
    '#include "matvecprod.h"',...
    '#include "gaussjordan.h"',...
    ['#include "',CGen.getrobfname,'_inertia.h"'],...
    ['#include "',CGen.getrobfname,'_coriolis.h"'],...
    ['#include "',CGen.getrobfname,'_gravload.h"'],...
    '#include "stdio.h"',...
    '#include "stdlib.h"',...
    '#include "mex.h"',...
    ['#include "',CGen.getrobfname,'_gravload.h"'],...
    ['#include "',CGen.getrobfname,'_friction.h"']);


fprintf(fid,'%s\n\n',hstring);

% Include guard
fprintf(fid,'%s\n',...
    ['#endif /*', upper([funname,'_h */'])]);

fclose(fid);

CGen.logmsg('\t%s\n',' done!');

end

function [] = checkexistanceofcfunctions(CGen)

if ~(exist(fullfile(CGen.ccodepath,'src','inertia.c'),'file') == 2) || ~(exist(fullfile(CGen.ccodepath,'include','inertia.h'),'file') == 2)
    CGen.logmsg('\t\t%s\n','Inertia C-code not found or not complete! Generating:');
    CGen.genccodeinertia;
end

if ~(exist(fullfile(CGen.ccodepath,'src','coriolis.c'),'file') == 2) || ~(exist(fullfile(CGen.ccodepath,'coriolis','inertia.h'),'file') == 2)
    CGen.logmsg('\t\t%s\n','Coriolis C-code not found or not complete! Generating:');
    CGen.genccodecoriolis;
end

if ~(exist(fullfile(CGen.ccodepath,'src','gravload.c'),'file') == 2) || ~(exist(fullfile(CGen.ccodepath,'include','gravload.h'),'file') == 2)
    CGen.logmsg('\t\t%s\n','Gravload C-code not found or not complete! Generating:');
    CGen.genccodegravload;
end

if ~(exist(fullfile(CGen.ccodepath,'src','friction.c'),'file') == 2) || ~(exist(fullfile(CGen.ccodepath,'include','friction.h'),'file') == 2)
    CGen.logmsg('\t\t%s\n','Friction C-code not found or not complete! Generating:');
    CGen.genccodefriction;
end

if ~(exist(fullfile(CGen.ccodepath,'src','matvecprod.c'),'file') == 2) || ~(exist(fullfile(CGen.ccodepath,'include','matvecprod.h'),'file') == 2)
    CGen.logmsg('\t\t%s\n','Matrix-Vector product C-code not found or not complete! Generating:');
    CGen.genmatvecprodc;
end

if ~(exist(fullfile(CGen.ccodepath,'src','gaussjordan.c'),'file') == 2) || ~(exist(fullfile(CGen.ccodepath,'include','gaussjordan.h'),'file') == 2)
    CGen.logmsg('\t\t%s\n','Gauss-Jordan matrix inversion C-code not found or not complete! Generating:');
    CGen.gengaussjordanc;
end

end

%% Definition of the header contents for each generated file
function hStruct = createHeaderStruct(rob,fname)
[~,hStruct.funName] = fileparts(fname);
hStruct.shortDescription = ['C-implementation of the forward dynamics for the ',rob.name,' arm.'];
hStruct.detailedDescription = {'Given a full set of joint angles and velocities',...
    'this function computes the joint space accelerations effected by the generalized forces. Angles have to be given in radians!'};
hStruct.inputs = { ['input1:  ',int2str(rob.n),'-element vector of generalized coordinates'],...
    ['input2:  ',int2str(rob.n),'-element vector of generalized velocities'],...
    ['input3:  [',int2str(rob.n),'x1] vector of generalized forces.']};
hStruct.outputs = {['QDD:  ',int2str(rob.n),'-element output vector of generalized accelerations.']};
hStruct.references = {'Robot Modeling and Control - Spong, Hutchinson, Vidyasagar',...
    'Modelling and Control of Robot Manipulators - Sciavicco, Siciliano',...
    'Introduction to Robotics, Mechanics and Control - Craig',...
    'Modeling, Identification & Control of Robots - Khalil & Dombre'};
hStruct.authors = {'This is an autogenerated function!',...
    'Code generator written by:',...
    'Joern Malzahn (joern.malzahn@tu-dortmund.de)'};
hStruct.seeAlso = {'invdyn'};
end