classdef CCPLX_Case2_P5 < Problem
    % <Multi-task> <Single-objective> <Competitive>

    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 Yanchi Li. You are free to use the MTO-Platform for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "MTO-Platform" and cite
    % or footnote "https://github.com/intLyc/MTO-Platform"
    %--------------------------------------------------------------------------

    methods
        function Prob = CCPLX_Case2_P5(varargin)
            Prob = Prob@Problem(varargin);
            Prob.maxFE = 1000 * 200;
        end

        function setTasks(Prob)
            Tasks = benchmark_Comp_CPLX(5, 2);
            Prob.T = length(Tasks);
            for t = 1:Prob.T
                Prob.D(t) = Tasks(t).Dim;
                Prob.Fnc{t} = Tasks(t).Fnc;
                Prob.Lb{t} = Tasks(t).Lb;
                Prob.Ub{t} = Tasks(t).Ub;
            end
        end
    end
end
