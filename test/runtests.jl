### runtests.jl --- Test suite for Cuba.jl

# Copyright (C) 2016  Mosè Giordano

# Maintainer: Mosè Giordano <mose AT gnu DOT org>

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.

# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

### Code:

using Cuba
using Base.Test

f1(x,y,z) = sin(x)*cos(y)*exp(z)
f2(x,y,z) = exp(-(x*x + y*y + z*z))
f3(x,y,z) = 1/(1 - x*y*z)

function integrand1(x, f)
    f[1] = f1(x[1], x[2], x[3])
    f[2] = f2(x[1], x[2], x[3])
    f[3] = f3(x[1], x[2], x[3])
end

# Make sure using "addprocs" doesn't make the program segfault.
addprocs(1)
Cuba.cores(0, 10000)
Cuba.accel(0,1000)

# Test results and make sure the estimation of error is exact.
answer = [(e-1)*(1-cos(1))*sin(1), (sqrt(pi)*erf(1)/2)^3, zeta(3)]
ncomp = 3
for (alg, abstol) in ((vegas, 1e-4), (suave, 1e-3),
                      (divonne, 1e-4), (cuhre, 1e-8))
    info("Testing ", ucfirst(string(alg)[6:end]), " algorithm")
    if alg == divonne
        result = alg(integrand1, 3, ncomp, abstol=abstol, reltol=1e-8, flags=0,
                     border = 1e-5)
    else
        result = alg(integrand1, 3, ncomp, abstol=abstol, reltol=1e-8, flags=0)
    end
    for i = 1:ncomp
        println("Component $i: ", result[1][i], " ± ", result[2][i])
        println("Should be:   ", answer[i])
        @test_approx_eq_eps result[1][i] answer[i] result[2][i]
    end
end

# Test 64-bit integer functions.
for (alg, abstol) in ((llvegas, 1e-4), (llsuave, 1e-3),
                      (lldivonne, 1e-4), (llcuhre, 1e-8))
    # Make sure that using maxevals > typemax(Int32) doesn't result into InexactError.
    result = alg((x,f) -> f[1] = f1(x[1], x[2], x[3]), 3, maxevals = 3e9)
    @test_approx_eq_eps result[1][1] answer[1] abstol
end

integrand2(x, f) = f[1], f[2] = reim(cis(x[1]))

# Test Cuhre and Divonne with ndim = 1.
answer = sin(1) + im*(1 - cos(1))
result = cuhre(integrand2, 1, 2)
@test_approx_eq     complex(result[1]...) answer
result = divonne(integrand2, 1, 2, reltol=1e-8, abstol=1e-8)
@test_approx_eq_eps complex(result[1]...) answer 1e-8

# Test taken from one of the examples of integrals over infinite domains.
func(x) = log(1 + x^2)/(1 + x^2)
result = cuhre((x, f) -> f[1] = func(x[1]/(1 - x[1]))/(1 - x[1])^2,
               abstol = 1e-12, reltol = 1e-10)
@test_approx_eq_eps result[1][1] pi*log(2) 3e-12

# Make sure these functions don't crash.
Cuba.init(C_NULL, C_NULL)
Cuba.exit(C_NULL, C_NULL)

# Dummy call just to increase code coverage
Cuba.integrand_ptr(Cuba.generic_integrand!)
