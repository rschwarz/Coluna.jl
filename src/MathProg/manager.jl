const DynSparseVector{I} = DynamicSparseArrays.PackedMemoryArray{I, Float64} 

const VarDict = Dict{VarId, Variable}
const ConstrDict = Dict{ConstrId, Constraint}
const VarMembership = Dict{VarId,Float64}
const ConstrMembership = Dict{ConstrId,Float64}
const ConstrConstrMatrix = MembersMatrix{ConstrId,ConstrId,Float64}
const ConstrVarMatrix = MembersMatrix{ConstrId,VarId,Float64}
const VarVarMatrix = MembersMatrix{VarId,VarId,Float64}

# Define the semaphore of the dynamic sparse matrix using MathProg.Id as index
DynamicSparseArrays.semaphore_key(::Type{I}) where {I <: Id} = zero(I)

struct FormulationManager
    vars::VarDict
    constrs::ConstrDict
    coefficients::ConstrVarMatrix # rows = constraints, cols = variables
    expressions::VarVarMatrix # cols = variables, rows = expressions
    primal_sols::VarVarMatrix # cols = primal solutions with varid, rows = variables 
    primal_sol_costs::DynSparseVector{VarId} # primal solutions with varid map to their cost
    dual_sols::ConstrConstrMatrix # cols = dual solutions with constrid, rows = constrs
    dual_sol_rhss::DynSparseVector{ConstrId} # dual solutions with constrid map to their rhs
    robust_constr_generators::Vector{RobustConstraintsGenerator}
end

function FormulationManager()
    vars = VarDict()
    constrs = ConstrDict()
    return FormulationManager(
        vars,
        constrs,
        ConstrVarMatrix(),
        VarVarMatrix(),
        VarVarMatrix(),
        dynamicsparsevec(VarId[], Float64[]),
        ConstrConstrMatrix(),
        dynamicsparsevec(ConstrId[], Float64[]),
        RobustConstraintsGenerator[]
    )
end

haskey(m::FormulationManager, id::Id{Variable}) = haskey(m.vars, id)
haskey(m::FormulationManager, id::Id{Constraint}) = haskey(m.constrs, id)

function _addvar!(m::FormulationManager, var::Variable)
    haskey(m.vars, var.id) && error(string("Variable of id ", var.id, " exists"))
    m.vars[var.id] = var
    return 
end

function _addconstr!(m::FormulationManager, constr::Constraint)
    haskey(m.constrs, constr.id) && error(string("Constraint of id ", constr.id, " exists"))
    m.constrs[constr.id] = constr
    return 
end

getvar(m::FormulationManager, id::VarId) = m.vars[id]
getconstr(m::FormulationManager, id::ConstrId) = m.constrs[id]
getvars(m::FormulationManager) = m.vars
getvardatas(m::FormulationManager) = m.vardatas
getconstrs(m::FormulationManager) = m.constrs
getcoefmatrix(m::FormulationManager) = m.coefficients
getexpressionmatrix(m::FormulationManager) = m.expressions
getprimalsolmatrix(m::FormulationManager) = m.primal_sols
getprimalsolcosts(m::FormulationManager) = m.primal_sol_costs
getdualsolmatrix(m::FormulationManager) =  m.dual_sols
getdualsolrhss(m::FormulationManager) =  m.dual_sol_rhss

function Base.show(io::IO, m::FormulationManager)
    println(io, "FormulationManager :")
    println(io, "> variables : ")
    for (id, var) in m.vars
        println(io, "  ", id, " => ", var)
    end
    println(io, "> constraints : ")
    for (id, constr) in m.constrs
        println(io, " ", id, " => ", constr)
    end
    return
end
