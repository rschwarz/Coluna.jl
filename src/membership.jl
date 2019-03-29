struct VarMembership <: AbstractMembership
    members::Dict{VarId, Float64}    #SparseVector{Float64, VarId}
end

function VarMembership()
    return VarMembership(Dict{VarId, Float64}())
end

function clone_membership(orig_memb::VarMembership)
    membership = VarMembership()
    for (id, val) in orig_memb
        membership[id] = val
    end
    return membership
end

struct ConstrMembership <: AbstractMembership
    members::Dict{ConstrId, Float64} #SparseVector{Float64, ConstrId}
end

function ConstrMembership()
    return ConstrMembership(Dict{ConstrId, Float64}())
end

function add!(m::AbstractMembership, varconstr_id, val::Float64)
    if haskey(m.members, varconstr_id)
        # if (reset)
        #    m.members[varconstr_id] = val
        # else            
        m.members[varconstr_id] += val
    else
        m.members[varconstr_id] = val
    end
    return
end

function set!(m::AbstractMembership, varconstr_id, val::Float64)
    m.members[varconstr_id] = val
    return
end

function get_ids_vals(m::VarMembership)
    #return findnz(m)
    uids = Vector{VarId}()
    vals = Vector{Float64}()
    for (uid,val) in m.members
        push!(uids, uid)
        push!(vals, val)
    end
    return uids, vals
end

function get_ids_vals(m::ConstrMembership)
    #return findnz(m)
    uids = Vector{ConstrId}()
    vals = Vector{Float64}()
    for (uid,val) in m.members
        push!(uids, uid)
        push!(vals, val)
    end
    return uids, vals
end

struct Memberships
    var_to_constr_members::Dict{VarId, ConstrMembership}
    constr_to_var_members::Dict{ConstrId, VarMembership}
    var_to_partialsol_members::Union{Nothing,Dict{VarId, VarMembership}}
    partialsol_to_var_members::Union{Nothing,Dict{VarId, VarMembership}}
    var_to_expression_members::Union{Nothing,Dict{VarId, VarMembership}}
    expression_to_var_members::Union{Nothing,Dict{VarId, VarMembership}}
end

function check_if_exists(dict::Dict{Int, AbstractMembership}, membership::AbstractMembership)
    for (id, m) in dict
        if (m == membership)
            return id
        end
    end
    return 0
end


function Memberships()
    var_m = Dict{VarId, ConstrMembership}()
    constr_m = Dict{ConstrId, ConstrMembership}()
    return Memberships(var_m, constr_m, nothing, nothing, nothing, nothing)
end

#function add_var!(m::VarMembership, var_uid::VarId, val::Float64)
#    m[var_uid] = val
#end

#function add_constr!(m::ConstrMembership, constr_uid::VarId, val::Float64)
#    m[constr_uid] = val
#end

hasvar(m::Memberships, uid) = haskey(m.var_to_constr_members, uid)
hasconstr(m::Memberships, uid) = haskey(m.constr_to_var_members, uid)
hasexpression(m::Memberships, uid) = haskey(m.var_to_expression_members, uid)
haspartialsol(m::Memberships, uid) = haskey(m.var_to_partialsol_members, uid)

function get_constr_members_of_var(m::Memberships, var_uid::VarId) 
    if haskey(m.var_to_constr_members, var_uid)
        return m.var_to_constr_members[var_uid]
    end
    error("Variable $var_uid not stored in formulation.")
end

function get_var_members_of_constr(m::Memberships, constr_uid::ConstrId) 
    if haskey(m.constr_to_var_members, constr_uid)
        return m.constr_to_var_members[constr_uid]
    end
    error("Constraint $constr_uid not stored in formulation.")
end


function get_var_members_of_expression(m::Memberships, eprex_uid::VarId) 
    if haskey(m.expression_to_var_members, eprex_uid)
        return m.expression_to_var_members[eprex_uid]
    end
    error("Expression $uid not stored in formulation.")
end

function add_constr_members_of_var!(m::Memberships, var_uid::VarId, constr_uid::ConstrId, coef::Float64)

    if !haskey(m.var_to_constr_members, var_uid)
        m.var_to_constr_members[var_uid] = ConstrMembership()
    end

    add!(m.var_to_constr_members[var_uid], constr_uid, coef)
    if !haskey(m.constr_to_var_members, constr_uid)
        m.constr_to_var_members[constr_uid] = VarMembership()
    end
    add!(m.constr_to_var_members[constr_uid], var_uid, coef)
end

function add_constr_members_of_var!(m::Memberships, var_uid::VarId, new_membership::ConstrMembership) 

    if !haskey(m.var_to_constr_members, var_uid)
        m.var_to_constr_members[var_uid] = ConstrMembership()
    end

    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        add!(m.var_to_constr_members[var_uid], constr_uids[j], vals[j])
        if !haskey(m.constr_to_var_members, constr_uids[j])
            m.constr_to_var_members[constr_uids[j]] = VarMembership()
        end
        add!(m.constr_to_var_members[constr_uids[j]], var_uid, vals[j])
    end
end

function add_var_members_of_constr!(m::Memberships, constr_uid::ConstrId, new_membership::VarMembership) 

    if !haskey(m.constr_to_var_members, constr_uid)
        m.constr_to_var_members[constr_uid] = VarMembership()
    end

    var_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(var_uids)
        add!(m.constr_to_var_members[constr_uid], var_uids[j], vals[j])
        if !haskey(m.var_to_constr_members, var_uids[j])
            m.var_to_constr_members[var_uids[j]] = ConstrMembership()
        end
        add!(m.var_to_constr_members[var_uids[j]], constr_uid, vals[j])
    end
end

function add_partialsol_members_of_var!(m::Memberships, spvar_uid::VarId, mc_uid, coef::Float64)
    if !haskey(m.var_to_partialsol_members, spvar_uid)
        m.var_to_partialsol_members[spvar_uid] = VarMembership()
    end
    add!(m.var_to_partialsol_members[spvar_uid], mc_uid, coef)

    if !haskey(m.partialsol_to_var_members, mc_uid)
        m.partialsol_to_var_members[mc_uid] = VarMembership()
    end
    add!(m.partialsol_to_var_members[mc_uid], spvar_uid, coef)
end

function add_partialsol_members_of_var!(m::Memberships, spvar_uid::VarId, new_membership::VarMembership) 
    if !haskey(m.var_to_partialsol_members, spvar_uid)
        m.var_to_partialsol_members[spvar_uid] = VarMembership()
    end
    
    mc_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(mc_uids)
        add!(m.var_to_partialsol_members[spvar_uid], mc_uids[j], vals[j])
        if !haskey(m.partialsol_to_var_members, mc_uids[j])
            m.partialsol_to_var_members[mc_uids[j]] = VarMembership()
        end
        add!(m.partialsol_to_var_members[mc_uids[j]], spvar_uid, vals[j])
    end
end

function add_var_members_of_partialsol!(m::Memberships, mc_uid::VarId, spvar_uid, coef::Float64)
    if !haskey(m.partialsol_to_var_members, mc_uid)
        m.partialsol_to_var_members[mc_uid] = VarMembership()
    end
    add!(m.partialsol_to_var_members[mc_uid], spvar_uid, coef)

    if !haskey(m.var_to_partialsol_members, spvar_uid)
        m.var_to_partialsol_members[spvar_uid] = VarMembership()
    end
    add!(m.var_to_partialsol_members[spvar_uid], mc_uid, coef)
end

function add_var_members_of_partialsol!(m::Memberships, mc_uid::VarId, new_membership::VarMembership) 
    if !haskey(m.partialsol_to_var_members, mc_uid)
        m.partialsol_to_var_members[mc_uid] = VarMembership()
    end
    
    spvar_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(mc_uids)
        add!(m.partialsol_to_var_members[mc_uid], spvar_uids[j], vals[j])
        if !haskey(m.var_to_partialsol_members, spvar_uids[j])
            m.var_to_partialsol_members[spvar_uids[j]] = VarMembership()
        end
        add!(m.var_to_partialsol_members[spvar_uids[j]], mc_uid, vals[j])
    end
end


function reset_constr_members_of_var!(m::Memberships, var_uid::VarId, new_membership::ConstrMembership) 
    m.var_to_constr_members[var_uid] = ConstrMembership() #spzeros(MAX_SV_ENTRIES)
    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        set!(m.var_to_constr_members[var_uid],constr_uids[j], vals[j])
    end   
end

function reset_var_members_of_constr!(m::Memberships, constr_uid::ConstrId, new_membership::VarMembership) 
    m.constr_to_var_members[constr_uid] = VarMembership() #spzeros(MAX_SV_ENTRIES)
    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        set!(m.constr_to_var_members[constr_uid], var_uids[j], vals[j])
    end
end

function set_constr_members_of_var!(m::Memberships, var_uid::VarId, new_membership::ConstrMembership) 
    m.var_to_constr_members[var_uid] = ConstrMembership() #spzeros(MAX_SV_ENTRIES)
    constr_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(constr_uids)
        add!(m.var_to_constr_members[var_uid],constr_uids[j], vals[j])
        if !hasconstr(m, constr_uids[j])
            m.constr_to_var_members[constr_uids[j]] = VarMembership() #spzeros(MAX_SV_ENTRIES)
        end
        add!(m.constr_to_var_members[constr_uids[j]], var_uid, vals[j])
    end
end

function set_var_members_of_constr!(m::Memberships, constr_uid::ConstrId, new_membership::VarMembership) 
    m.constr_to_var_members[constr_uid] = VarMembership() #spzeros(MAX_SV_ENTRIES)
    var_uids, vals = get_ids_vals(new_membership)
    for j in 1:length(var_uids)
        add!(m.constr_to_var_members[constr_uid],var_uids[j], vals[j])
        if !hasvar(m, var_uids[j])
            m.var_to_constr_members[var_uids[j]] = ConstrMembership() #spzeros(MAX_SV_ENTRIES)
        end
        add!(m.var_to_constr_members[var_uids[j]], constr_uid, vals[j])
    end
end


function add_variable!(m::Memberships, var_uid::VarId)
    haskey(m.var_to_constr_members, var_uid) && error("Variable with uid $var_uid already registered.")
    m.var_to_constr_members[var_uid] = ConstrMembership() #spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_variable!(m::Memberships, var_uid::VarId, membership::ConstrMembership)
    haskey(m.var_to_constr_members, var_uid) && error("Variable with uid $var_uid already registered.")
    set_constr_members_of_var!(m, var_uid, membership)
    return
end

function add_constraint!(m::Memberships, constr_uid::ConstrId)
    haskey(m.constr_to_var_members, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    m.constr_to_var_members[constr_uid] = VarMembership() #spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function add_constraint!(m::Memberships, constr_uid::ConstrId, membership::VarMembership) 
    haskey(m.constr_to_var_members, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    add_var_members_of_constr!(m, constr_uid, membership)
    return
end
