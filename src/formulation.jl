abstract type AbstractSubproblems end
abstract type AbstractFormulationNature end

struct Formulation{FormNature <: AbstractFormulationNature, SubProbsType <: AbstractSubproblems}
    parent::Formulation
    master::FormNature
    subproblems::SubProbsType
    variables_manager
    constraints_manager
end

struct ExplicitFormulation <: AbstractFormulationNature
    moi_definition
end

struct ImplicitFormulation <: AbstractFormulationNature
    callback
end

struct NoSubproblem <: AbstractSubproblems end

struct LazySeparationSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct UserSeparationSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct BlockGenSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct BendersSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct DantzigWolfeSubproblem <: AbstractSubproblems
    subproblems::Vector{Formulation}
end

struct HybdridSubproblems <: AbstractSubproblems
    subproblems::Vector{AbstractSubproblems}
end
