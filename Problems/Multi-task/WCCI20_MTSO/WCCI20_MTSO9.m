classdef WCCI20_MTSO9 < Problem
    % <Multi> <None>

    properties
    end

    methods
        function parameter = getParameter(obj)
            parameter = obj.getRunParameter();
        end

        function obj = setParameter(obj, parameter_cell)
            obj.setRunParameter(parameter_cell);
        end

        function Tasks = getTasks(obj)
            Tasks = benchmark_WCCI20_MTSO(9);
        end

    end

end
