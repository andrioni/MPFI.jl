using Base.Test
using MPFI

# Check conversion and output
for i = 1:10000
    a = {rand(Int8), rand(Int16), rand(Int32), rand(Int64), rand(Int128), 
         rand(Uint8), rand(Uint16), rand(Uint32), rand(Uint64), rand(Uint128),
         rand(Float32), rand(Float64)}
    b = map(string, a)
    for j in a
        if j != 0
            @test "[$(BigFloat(j)), $(BigFloat(j))]" == string(Interval(j))
        else
            @test "[$(BigFloat(j)), -$(BigFloat(j))]" == string(Interval(j))
        end
    end
end

# Check precision
a = Interval(1)
precision(a) == get_bigfloat_precision()