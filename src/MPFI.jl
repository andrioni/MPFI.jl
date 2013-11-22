module MPFI

export
    Interval,
    bisect,
    blow,
    diam,
    diam_abs,
    diam_rel,
    left,
    mag,
    mid,
    mig,
    isbounded,
    right

import
    Base: precision, string, print, show, showcompact, promote_rule,
        promote, convert, +, *, -, /, exp, isinf, isnan, nan, inf, sqrt,
        square, exp, exp2, expm1, cosh, sinh, tanh, sech, csch, coth, inv,
        sqrt, cbrt, abs, log, log2, log10, log1p, sin, cos, tan, sec,
        csc, acos, asin, atan, acosh, asinh, atanh, isempty, union,
        intersect, in, cmp, ldexp, rand, rand!

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

# Dyadic constructors
Interval(x::Real, y::Real) = Interval(promote(x, y)...)
for (fJ, fC) in ((:si,:Clong), (:ui,:Culong), (:d,:Float64))
    @eval begin
        function Interval(x::($fC), y::($fC))
            z = Interval()
            ccall(($(string(:mpfi_interv_,fJ)), :libmpfi), Int32, (Ptr{Interval}, ($fC), ($fC)), &z, x, y)
            return z
        end
    end
end

function Interval(x::BigInt, y::BigInt)
    z = Interval()
    ccall((:mpfi_interv_z, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigInt}, Ptr{BigInt}), &z, &x, &y)
    return z
end

function Interval(x::BigFloat, y::BigFloat)
    z = Interval()
    ccall((:mpfi_interv_fr, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigFloat}, Ptr{BigFloat}), &z, &x, &y)
    return z
end

Interval(x::MathConst) = convert(Interval, x)

# Promotion of constants
promote_rule{s}(::Type{MathConst{s}}, ::Type{Interval}) = Interval

# Conversions to Interval
convert(::Type{Interval}, x::Rational) = Interval(x)
convert(::Type{Interval}, x::Real) = Interval(x)
convert(::Type{Interval}, x::MathConst) = Interval(big(x))
function convert(::Type{Interval}, ::MathConst{:π})
    z = Interval()
    ccall((:mpfi_const_pi,:libmpfi), Cint, (Ptr{Interval},), &z)
    return z
end
function convert(::Type{Interval}, ::MathConst{:γ})
    z = Interval()
    ccall((:mpfi_const_euler,:libmpfi), Cint, (Ptr{Interval},), &z)
    return z
end
function convert(::Type{Interval}, ::MathConst{:catalan})
    z = Interval()
    ccall((:mpfi_const_catalan,:libmpfi), Cint, (Ptr{Interval},), &z)
    return z
end

# Conversions from Interval
function convert(::Type{BigFloat}, x::Interval)
    z = BigFloat()
    ccall((:mpfi_get_fr,:libmpfi), Void, (Ptr{BigFloat}, Ptr{Interval}), &z, &x)
    return z
end
convert(::Type{Float64}, x::Interval) =
    ccall((:mpfi_get_d,:libmpfi), Float64, (Ptr{Interval},), &x)

for to in (Int8, Int16, Int32, Int64, Uint8, Uint16, Uint32, Uint64, BigInt, Float32)
    @eval begin
        function convert(::Type{$to}, x::Interval)
            convert($to, convert(BigFloat, x))
        end
    end
end
convert(::Type{Integer}, x::Interval) = convert(BigInt, x)
convert(::Type{FloatingPoint}, x::Interval) = convert(BigFloat, x)

# Interval functions with floating-point results
for f in (:diam_abs, :diam_rel, :diam, :mag, :mig, :mid)
    @eval function $(f)(x::Interval)
        z = BigFloat()
        ccall(($(string(:mpfi_,f)), :libmpfi), Int32, (Ptr{BigFloat}, Ptr{Interval}), &z, &x)
        return z
    end
end

# Basic operations between intervals
for (fJ, fC) in ((:+,:add), (:-,:sub), (:*,:mul), (:/,:div))
    @eval begin 
        function ($fJ)(x::Interval, y::Interval)
            z = Interval()
            ccall(($(string(:mpfi_,fC)),:libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &x, &y)
            return z
        end
    end
end

# More efficient commutative operations
for (fJ, fC) in ((:+, :add), (:*, :mul))
    @eval begin
        function ($fJ)(a::Interval, b::Interval, c::Interval)
            z = Interval()
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &a, &b)
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &z, &c)
            return z
        end
        function ($fJ)(a::Interval, b::Interval, c::Interval, d::Interval)
            z = Interval()
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &a, &b)
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &z, &c)
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &z, &d)
            return z
        end
        function ($fJ)(a::Interval, b::Interval, c::Interval, d::Interval, e::Interval)
            z = Interval()
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &a, &b)
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &z, &c)
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &z, &d)
            ccall(($(string(:mpfi_,fC)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &z, &e)
            return z
        end
    end
end

# Basic arithmetic without promotion
# Unsigned addition
function +(x::Interval, c::Culong)
    z = Interval()
    ccall((:mpfi_add_ui, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Culong), &z, &x, c)
    return z
end
+(c::Culong, x::Interval) = x + c
+(c::Unsigned, x::Interval) = x + convert(Culong, c)
+(x::Interval, c::Unsigned) = x + convert(Culong, c)

# Signed addition
function +(x::Interval, c::Clong)
    z = Interval()
    ccall((:mpfi_add_si, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Clong), &z, &x, c)
    return z
end
+(c::Clong, x::Interval) = x + c
+(x::Interval, c::Signed) = x + convert(Clong, c)
+(c::Signed, x::Interval) = x + convert(Clong, c)

# Float64 addition
function +(x::Interval, c::Float64)
    z = Interval()
    ccall((:mpfi_add_d, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Float64), &z, &x, c)
    return z
end
+(c::Float64, x::Interval) = x + c
+(c::Float32, x::Interval) = x + convert(Float64, c)
+(x::Interval, c::Float32) = x + convert(Float64, c)

# BigInt addition
function +(x::Interval, c::BigInt)
    z = Interval()
    ccall((:mpfi_add_z, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigInt}), &z, &x, &c)
    return z
end
+(c::BigInt, x::Interval) = x + c

# BigFloat addition
function +(x::Interval, c::BigFloat)
    z = Interval()
    ccall((:mpfi_add_fr, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigFloat}), &z, &x, &c)
    return z
end
+(c::BigInt, x::Interval) = x + c

# Unsigned subtraction
function -(x::Interval, c::Culong)
    z = Interval()
    ccall((:mpfi_sub_ui, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Culong), &z, &x, c)
    return z
end
function -(c::Culong, x::Interval)
    z = Interval()
    ccall((:mpfi_ui_sub, :libmpfi), Int32, (Ptr{Interval}, Culong, Ptr{Interval}), &z, c, &x)
    return z
end
-(x::Interval, c::Unsigned) = -(x, convert(Culong, c))
-(c::Unsigned, x::Interval) = -(convert(Culong, c), x)

# Signed subtraction
function -(x::Interval, c::Clong)
    z = Interval()
    ccall((:mpfi_sub_si, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Clong), &z, &x, c)
    return z
end
function -(c::Clong, x::Interval)
    z = Interval()
    ccall((:mpfi_si_sub, :libmpfi), Int32, (Ptr{Interval}, Clong, Ptr{Interval}), &z, c, &x)
    return z
end
-(x::Interval, c::Signed) = -(x, convert(Clong, c))
-(c::Signed, x::Interval) = -(convert(Clong, c), x)

# Float64 subtraction
function -(x::Interval, c::Float64)
    z = Interval()
    ccall((:mpfi_sub_d, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Float64), &z, &x, c)
    return z
end
function -(c::Float64, x::Interval)
    z = Interval()
    ccall((:mpfi_d_sub, :libmpfi), Int32, (Ptr{Interval}, Float64, Ptr{Interval}), &z, c, &x)
    return z
end
-(x::Interval, c::Float32) = -(x, convert(Float64, c))
-(c::Float32, x::Interval) = -(convert(Float64, c), x)

# BigInt subtraction
function -(x::Interval, c::BigInt)
    z = Interval()
    ccall((:mpfi_sub_z, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigInt}), &z, &x, &c)
    return z
end
function -(c::BigInt, x::Interval)
    z = Interval()
    ccall((:mpfi_z_sub, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigInt}, Ptr{Interval}), &z, &c, &x)
    return z
end

# BigFloat subtraction
function -(x::Interval, c::BigFloat)
    z = Interval()
    ccall((:mpfi_sub_fr, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigFloat}), &z, &x, &c)
    return z
end
function -(c::BigFloat, x::Interval)
    z = Interval()
    ccall((:mpfi_fr_sub, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigFloat}, Ptr{Interval}), &z, &c, &x)
    return z
end

# Unsigned multiplication
function *(x::Interval, c::Culong)
    z = Interval()
    ccall((:mpfi_mul_ui, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Culong), &z, &x, c)
    return z
end
*(c::Culong, x::Interval) = x * c
*(c::Unsigned, x::Interval) = x * convert(Culong, c)
*(x::Interval, c::Unsigned) = x * convert(Culong, c)

# Signed multiplication
function *(x::Interval, c::Clong)
    z = Interval()
    ccall((:mpfi_mul_si, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Clong), &z, &x, c)
    return z
end
*(c::Clong, x::Interval) = x * c
*(c::Signed, x::Interval) = x * convert(Clong, c)
*(x::Interval, c::Signed) = x * convert(Clong, c)

# Float64 multiplication
function *(x::Interval, c::Float64)
    z = Interval()
    ccall((:mpfi_mul_d, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Float64), &z, &x, c)
    return z
end
*(c::Float64, x::Interval) = x * c
*(c::Float32, x::Interval) = x * convert(Float64, c)
*(x::Interval, c::Float32) = x * convert(Float64, c)

# BigInt multiplication
*(c::Signed, x::Interval) = x * convert(Clong, c)
function *(x::Interval, c::BigInt)
    z = Interval()
    ccall((:mpfi_mul_z, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigInt}), &z, &x, &c)
    return z
end
*(c::BigInt, x::Interval) = x * c

# BigFloat multiplication
function *(x::Interval, c::BigFloat)
    z = Interval()
    ccall((:mpfi_mul_fr, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigFloat}), &z, &x, &c)
    return z
end
*(c::BigFloat, x::Interval) = x * c

# Unsigned division
function /(x::Interval, c::Culong)
    z = Interval()
    ccall((:mpfi_div_ui, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Culong), &z, &x, c)
    return z
end
function /(c::Culong, x::Interval)
    z = Interval()
    ccall((:mpfi_ui_div, :libmpfi), Int32, (Ptr{Interval}, Culong, Ptr{Interval}), &z, c, &x)
    return z
end
/(x::Interval, c::Unsigned) = /(x, convert(Culong, c))
/(c::Unsigned, x::Interval) = /(convert(Culong, c), x)

# Signed division
function /(x::Interval, c::Clong)
    z = Interval()
    ccall((:mpfi_div_si, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Clong), &z, &x, c)
    return z
end
function /(c::Clong, x::Interval)
    z = Interval()
    ccall((:mpfi_si_div, :libmpfi), Int32, (Ptr{Interval}, Clong, Ptr{Interval}), &z, c, &x)
    return z
end
/(x::Interval, c::Signed) = /(x, convert(Clong, c))
/(c::Signed, x::Interval) = /(convert(Clong, c), x)

# Float64 division
function /(x::Interval, c::Float64)
    z = Interval()
    ccall((:mpfi_div_d, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Float64), &z, &x, c)
    return z
end
function /(c::Float64, x::Interval)
    z = Interval()
    ccall((:mpfi_d_div, :libmpfi), Int32, (Ptr{Interval}, Float64, Ptr{Interval}), &z, c, &x)
    return z
end
/(x::Interval, c::Float32) = /(x, convert(Float64, c))
/(c::Float32, x::Interval) = /(convert(Float64, c), x)

# BigInt division
function /(x::Interval, c::BigInt)
    z = Interval()
    ccall((:mpfi_div_z, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigInt}), &z, &x, &c)
    return z
end
function /(c::BigInt, x::Interval)
    z = Interval()
    ccall((:mpfi_z_div, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigInt}, Ptr{Interval}), &z, &c, &x)
    return z
end

# BigFloat division
function /(x::Interval, c::BigFloat)
    z = Interval()
    ccall((:mpfi_div_fr, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{BigFloat}), &z, &x, &c)
    return z
end
function /(c::BigFloat, x::Interval)
    z = Interval()
    ccall((:mpfi_fr_div, :libmpfi), Int32, (Ptr{Interval}, Ptr{BigFloat}, Ptr{Interval}), &z, &c, &x)
    return z
end

function precision(x::Interval)
    return ccall((:mpfi_get_prec, :libmpfi), Clong, (Ptr{Interval},), &x)
end

function -(x::Interval)
    z = Interval()
    ccall((:mpfi_neg, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}), &z, &x)
    return z
end

function square(x::Interval)
    z = Interval()
    ccall((:mpfi_sqr, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}), &z, &x)
    return z
end

function sqrt(x::Interval)
    z = Interval()
    ccall((:mpfi_sqrt, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}), &z, &x)
    if isnan(z)
        throw(DomainError())
    end
    return z
end

for f in (:exp,:exp2,:expm1,:cosh,:sinh,:tanh,:sech,:csch,:coth,:inv,
          :sqrt,:cbrt,:abs,:log,:log2,:log10,:log1p,:sin,:cos,:tan,:sec,
          :csc,:acos,:asin,:atan,:acosh,:asinh,:atanh)
    @eval function $f(x::Interval)
        z = Interval()
        ccall(($(string(:mpfi_,f)), :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}), &z, &x)
        return z
    end
end

# Set-like functions
function in(x::Interval, int::Interval)
    return ccall((:mpfi_is_inside, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}), &x, &int) > 0
end

for (fJ, fC) in ((:si,:Clong), (:ui,:Culong), (:d,:Float64))
    @eval begin
        function in(x::($fC), int::Interval)
            return ccall(($(string(:mpfi_is_inside_,fJ)), :libmpfi), Int32, (($fC), Ptr{Interval}), x, &int) > 0
        end
    end
end

for (fJ, fC) in ((:z,:BigInt), (:fr,:BigFloat))
    @eval begin
        function in(x::($fC), int::Interval)
            return ccall(($(string(:mpfi_is_inside_,fJ)), :libmpfi), Int32, (Ptr{($fC)}, Ptr{Interval}), &x, &int) > 0
        end
    end
end

function intersect(x::Interval, y::Interval)
    z = Interval()
    ccall((:mpfi_intersect, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &x, &y)
    return z
end

function union(x::Interval, y::Interval)
    z = Interval()
    ccall((:mpfi_union, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z, &x, &y)
    return z
end

function bisect(x::Interval)
    z1, z2 = Interval(), Interval()
    ccall((:mpfi_bisect, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Ptr{Interval}), &z1, &z2, &x)
    return z1, z2
end

function blow(x::Interval, y::Float64)
    z = Interval()
    ccall((:mpfi_blow, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Float64), &z, &x, y)
    return z
end

function ldexp(x::Interval, y::Culong)
    z = Interval()
    ccall((:mpfi_mul_2exp, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Culong), &z, &x, y)
    return z
end
function ldexp(x::Interval, y::Clong)
    z = Interval()
    ccall((:mpfi_mul_2si, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}, Clong), &z, &x, y)
    return z
end
ldexp(x::Interval, y::Signed) = ldexp(x, convert(Clong, y))
ldexp(x::Interval, y::Unsigned) = ldexp(x, convert(Culong, y))

function left(x::Interval)
    z = BigFloat()
    ccall((:mpfi_get_left, :libmpfi), Int32, (Ptr{BigFloat}, Ptr{Interval}), &z, &x)
    return z
end

function right(x::Interval)
    z = BigFloat()
    ccall((:mpfi_get_right, :libmpfi), Int32, (Ptr{BigFloat}, Ptr{Interval}), &z, &x)
    return z
end

function isbounded(x::Interval)
    return ccall((:mpfi_bounded_p, :libmpfi), Int32, (Ptr{Interval},), &x) != 0
end

function isempty(x::Interval)
    return ccall((:mpfi_empty_p, :libmpfi), Int32, (Ptr{Interval},), &x) != 0
end

function isnan(x::Interval)
    return ccall((:mpfi_nan_p, :libmpfi), Int32, (Ptr{Interval},), &x) != 0
end

function isinf(x::Interval)
    return ccall((:mpfi_inf_p, :libmpfi), Int32, (Ptr{Interval},), &x) != 0
end

function cmp2(x::Interval, y::Interval)
    return ccall((:mpfi_cmp, :libmpfi), Int32, (Ptr{Interval}, Ptr{Interval}), &x, &y)
end

function rand!(x::Interval, A::Array{BigFloat})
    for i = 1:length(A)
        A[i] = rand(x)
    end
    A
end

function rand(r::BigRNG, x::Interval)
    z = BigFloat()
    ccall((:mpfi_urandom, :libmpfi), Void,
          (Ptr{BigFloat}, Ptr{Interval}, Ptr{BigRNG}),
           &z, &x, &r)
    return z
end
rand(x::Interval) = rand(Base.Random.DEFAULT_BIGRNG, x)
rand(x::Interval, dims::Dims) = rand!(x, Array(BigFloat, dims))
rand(x::Interval, dims::Int...) = rand!(x, Array(BigFloat, dims...))

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
