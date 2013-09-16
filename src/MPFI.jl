module MPFI

export
    Interval

import
    Base: precision, string, print, show, showcompact

type Interval <: Number
    left_prec::Clong
    left_sign::Cint
    left_exp::Clong
    left_d::Ptr{Void}
    right_prec::Clong
    right_sign::Cint
    right_exp::Clong
    right_d::Ptr{Void}
    function Interval()
        N = get_bigfloat_precision()
        z = new(zero(Clong), zero(Cint), zero(Clong), C_NULL,
                zero(Clong), zero(Cint), zero(Clong), C_NULL)
        ccall((:mpfi_init2,:libmpfi), Void, (Ptr{Interval}, Clong), &z, N)
        finalizer(z, MPFI_clear)
        return z
    end
end

MPFI_clear(mpfi::Interval) = ccall((:mpfi_clear, :libmpfi), Void, (Ptr{Interval},), &mpfi)

Interval(x::Interval) = x

for (fJ, fC) in ((:si,:Clong), (:ui,:Culong), (:d,:Float64))
    @eval begin
        function Interval(x::($fC))
            z = Interval()
            ccall(($(string(:mpfi_set_,fJ)), :libmpfi), Int32, (Ptr{Interval}, ($fC)), &z, x)
            return z
        end
    end
end

function Interval(x::BigInt)
    z = Interval()
    ccall((:mpfi_set_z, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigInt}), &z, &x)
    return z
end

function Interval(x::BigFloat)
    z = Interval()
    ccall((:mpfi_set_fr, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigFloat}), &z, &x)
    return z
end

function Interval(x::String, base::Int)
    z = Interval()
    err = ccall((:mpfi_set_str, :libmpfi), Int32, (Ptr{Interval}, Ptr{Uint8}, Int32), &z, x, base)
    if err != 0; error("Invalid input"); end
    return z
end
Interval(x::String) = Interval(x, 10)

Interval(x::Integer) = Interval(BigInt(x))

Interval(x::Union(Bool,Int8,Int16,Int32)) = Interval(convert(Clong,x))
Interval(x::Union(Uint8,Uint16,Uint32)) = Interval(convert(Culong,x))

Interval(x::Float32) = Interval(float64(x))
Interval(x::Rational) = Interval(num(x)) / Interval(den(x))

function precision(x::Interval)
    return ccall((:mpfi_get_prec, :libmpfi), Clong, (Ptr{Interval},), &x)
end

function string(x::Interval)
    # We use the alternate constructor to avoid the GC,
    # since MPFI manages the memory here
    left = BigFloat(x.left_prec, x.left_sign, x.left_exp, x.left_d)
    right = BigFloat(x.right_prec, x.right_sign, x.right_exp, x.right_d)
    return "[$(string(left)), $(string(right))]"
end

print(io::IO, b::Interval) = print(io, string(b))
show(io::IO, b::Interval) = print(io, string(b), " with $(precision(b)) bits of precision")
showcompact(io::IO, b::Interval) = print(io, string(b))

end # module
