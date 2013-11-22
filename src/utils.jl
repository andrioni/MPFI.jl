# Macros and functions to check if the BigNumber RNG is defined.
# Based on _os_test from osutils.jl
function bigrng_test(qm, ex, test)
    @assert qm == :?
    @assert isa(ex, Expr)
    @assert ex.head == :(:)
    @assert length(ex.args) == 2
    if test
        return esc(ex.args[1])
    else
        return esc(ex.args[2])
    end
end

macro bigrng(qm, ex)
    bigrng_test(qm, ex, isdefined(:BigRNG))
end

macro have_bigrng(ex)
    @bigrng? esc(ex) : nothing
end

macro no_bigrng(ex)
    @bigrng? nothing : esc(ex)
end
