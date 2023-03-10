using EconPDEs

Base.@kwdef mutable struct WangWangYangModel
    μ::Float64 = 0.015
    σ::Float64 = 0.1
    r::Float64 = 0.035
    ρ::Float64 = 0.04
    γ::Float64 = 3.0
    ψ::Float64 = 1.1
    wmax::Float64 = 5000.0
end

    
function (m::WangWangYangModel)(state::NamedTuple, y::NamedTuple)
    (; μ, σ, r, ρ, γ, ψ, wmax) = m
    (; w) = state
    (; p, pw_up, pw_down, pww) = y
    pw = pw_up
    iter = 0
    @label start
    c = (r + ψ * (ρ - r)) * p * pw^(-ψ)
    μw = (r - μ + σ^2) * w + 1 - c
    if (iter == 0) & (μw <= 0)
        iter += 1
        pw = pw_down
        @goto start
    end

   #  One only needs a ghost node if μw <= 0 (since w^2p_ww = 0). In this case, we obtain a formula for pw so that c <= 1
    if w ≈ 0.0 && μw <= 0.0
       pw = ((r + ψ * (ρ - r)) * p)^(1 / ψ)
       c = 1.0
       μw = 0.0
    end
    # At the top, I use the solution of the unconstrainted, i.e. pw = 1 (I could also do reflecting boundary but less elegant)
    pt = - ((((r + ψ * (ρ - r)) * pw^(1 - ψ) - ψ * ρ) / (ψ - 1) + μ - γ * σ^2 / 2) * p + ((r - μ + γ * σ^2) * w + 1) * pw + σ^2 * w^2 / 2  * (pww - γ * pw^2 / p))
    return (; pt)
end

m = WangWangYangModel()
stategrid = OrderedDict(:w => range(0.0, m.wmax, length = 100))
yend = OrderedDict(:p => 1 .+ stategrid[:w])
result = pdesolve(m, stategrid, yend, bc = OrderedDict(:pw => (1.0, 1.0)))
@assert result.residual_norm <= 1e-5
