## MPFI.jl

#### Multiple Precision Floating-point Interval library for Julia

This is a work-in-progress Julia package that wraps [MPFI](http://perso.ens-lyon.fr/nathalie.revol/software.html) 
for Julia. All functions should be available, except `mpfi_put_*` and `mpfi_urandom`.

##### Documentation

The documentation is available at http://mpfijl.readthedocs.org/en/latest/

##### Some examples

```julia
# MPFI uses BigFloats in its internal representation
# For convenience, let's just use 53 bits (as a Float64)
julia> set_bigfloat_precision(53)
53

# The following creates an interval centered on 1.1.
# Since 1.1 isn't exactly representable as a floating-point number,
# the shortest interval that includes it is returned.
julia> x = Interval("1.1")
[1.0999999999999999e+00, 1.1000000000000001e+00] with 53 bits of precision

# It is also possible to create an interval through its endpoints.
julia> y = Interval(1, 2)
[1e+00, 2e+00] with 53 bits of precision

julia> Interval("[1, 2]")
[1e+00, 2e+00] with 53 bits of precision

julia> x + y
[2.0999999999999996e+00, 3.1000000000000001e+00] with 53 bits of precision
```

Warning: currently the return values and the error handling from MPFI are ignored.
