# This is a quick and dirty port of UTMConversion.xls written by Steve Dutch

function utm2gps(
    east::Vector{Float64},
    north::Vector{Float64},
    zone::Int64,
)
    E = 500000 .- east
    N = north

    b = 6356752.3142
    a = 6378137
    e = 0.081819190928907
    e1sq = 0.006739496756587
    k0 = 0.9996
    z = (zone > 0) ? 6*zone - 183 : 3

    arc = N / k0
    mu = arc / (a*(1-e^2/4-3*e^4/64-5*e^6/256))
    e1 = (1-(1-e*e)^(1/2))/(1+(1-e*e)^(1/2))
    cc1 = 3*e1/2-27*e1^3/32
    cc2 = 21*e1^2/16-55*e1^4/32
    cc3 = 151*e1^3/96
    cc4 = 1097*e1^4/512
    phi1 = mu+cc1*sin.(2*mu)+cc2*sin.(4*mu)+cc3*sin.(6*mu)+cc4*sin.(8*mu)

    c1 = e1sq*cos.(phi1).^2
    t1 = tan.(phi1).^2
    N1 = a ./ sqrt.(1 .- (e*sin.(phi1)).^2)
    R1 = a * (1 .- e.^2) ./ (1 .- (e*sin.(phi1)).^2).^(3/2)
    D = E ./ (N1*k0)
    f1 = N1 .* tan.(phi1) ./ R1
    f2 = D.^2 / 2
    f3 = (5 .+ 3*t1 + 10*c1 - 4*c1.^2 .- 9*e1sq) .* D.^4 / 24
    f4 = (61 .+ 90*t1 + 298*c1 + 45*t1.^2 -3*c1.^2 .- 252*e1sq) .* D.^6 / 720

    lf1 = D
    lf2 = (1 .+ 2*t1 + c1) .*D.^3 / 6
    lf3 = (5 .- 2*c1 + 28*t1 - 3*c1.^2 .+ 8*e1sq + 24*t1.^2) .*D.^5 / 120

    lat = 180 * (phi1 - f1 .* (f2 + f3 + f4)) / pi
    lon = z .- (lf1 - lf2 + lf3) ./ cos.(phi1) * 180/ pi
    return lat, lon
end


function gps2utm(
    latitude::Vector{Float64},
    longitude::Vector{Float64},
    zone::Int64,
)
    lon = longitude * pi / 180
    lat = latitude * pi / 180

    cm = 6*zone - 183
    k0 = 0.9996
    a = 6378137
    b = 6356752
    n = (a - b) / (a + b)

    e = sqrt(1 - b^2/a^2)
    e2 = e^2 / (1 - e^2)
    A0 = a*(1 - n + 5/4*n^2*(1-n) + 81/64*n^4*(1-n))
    B0 = 3*a*n/2 * (1 - n - 7/8*n^2*(1-n) + 55*n^4/64)
    C0 = 15/16*a*n^2 * (1 - n + 3/4*n^2*(1-n))
    D0 = 35/48*a*n^3 * (1 - n + 11/16*n^2)
    E0 = 315/51*a*n^4 * (1 - n)
    S = A0*lat - B0*sin.(2*lat) + C0*sin.(4*lat) + D0*sin.(6*lat) + E0*sin.(8*lat)

    nu = a ./ sqrt.((1 .- e^2*sin.(lat).^2))
    rho = a * (1-e^2) ./ (1 .- e^2*sin.(lat).^2).^(3/2)

    k1 = S * k0
    k2 = nu .* sin.(lat) .* cos.(lat) * k0/2 
    k3 = nu .* sin.(lat) .* cos.(lat).^3 /24 .* (5 .- tan.(lat).^2 + 9*e2*cos.(lat).^2 + 4*e2^2*cos.(lat).^4)*k0
    k4 = nu .* cos.(lat) * k0
    k5 = cos.(lat).^3 .* nu/6 .* (1 .- tan.(lat).^2 + e2 * cos.(lat).^2)*k0

    p = lon .- cm * pi / 180

    north = (k1 + k2 .* p.^2 + k3 .* p.^4)
    east = 500000 .+ (k4 .* p + k5 .* p.^3)
    return east, north
end
