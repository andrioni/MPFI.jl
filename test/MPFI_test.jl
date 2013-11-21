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
@test precision(a) == get_bigfloat_precision()

# Check squaring
a = Interval(-1, 1)
@test (left(square(a)), right(square(a))) == (0, 1)
@test (left(a * a), right(a * a)) == (-1, 1)

# Check -
a = Interval(0, 1)
@test (left(-a), right(-a)) == (-1, 0)
@test signbit(right(-a)) == 1
