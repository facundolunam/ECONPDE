using EconPDEs, Distributions

mutable struct DiTellaModel
  # Utility Function
  γ::Float64 
  ψ::Float64
  ρ::Float64
  τ::Float64

  # Technology
  A::Float64
  σ::Float64

  # MoralHazard
  ϕ::Float64

  # Idiosyncratic
  νbar::Float64
  κν::Float64
  σνbar::Float64
end

function DiTellaModel(;γ = 5.0, ψ = 1.5, ρ = 0.05, τ = 0.4, A = 200.0, σ = 0.03, ϕ = 0.2, νbar = 0.24, κν = 0.22, σνbar = -0.13)
  DiTellaModel(γ, ψ, ρ, τ, A, σ, ϕ, νbar, κν, σνbar)
end

function initialize_stategrid(m::DiTellaModel; xn = 80, νn = 10)
  γ = m.γ ; ψ = m.ψ ; ρ = m.ρ ; τ = m.τ ; A = m.A ; σ = m.σ ; ϕ = m.ϕ ; νbar = m.νbar ; κν = m.κν ; σνbar = m.σνbar
  distribution = Gamma(2 * κν * νbar / σνbar^2, σνbar^2 / (2 * κν))
  νmin = quantile(distribution, 0.001)
  νmax = quantile(distribution, 0.999)
  OrderedDict(:x => range(0.01, stop = 0.99, length = xn), :ν => range(νmin, stop = νmax, length = νn))
end

function initialize_y(m::DiTellaModel, stategrid::OrderedDict)
  x = fill(1.0, length(stategrid[:x]), length(stategrid[:ν]))
  OrderedDict(:pA => x, :pB => x, :p => x)
end

function (m::DiTellaModel)(state::NamedTuple, y::NamedTuple)
  (; γ, ψ, ρ, τ, A, σ, ϕ, νbar, κν, σνbar) = m  
  (; x, ν) = state
  (; pA, pAx, pAν, pAxx, pAxν, pAνν, pB, pBx, pBν, pBxx, pBxν, pBνν, p, px, pν, pxx, pxν, pνν) = y

  # drift and volatility of state variable ν
  g = p / (2 * A)
  i = A * g^2
  μν = κν * (νbar - ν)
  σν = σνbar * sqrt(ν)

  # Market price of risk κ
  σX = x * (1 - x) * (1 - γ) / (γ * (ψ - 1)) * (pAν / pA - pBν / pB) * σν / (1 - x * (1 - x) * (1 - γ) / (γ * (ψ - 1)) * (pAx / pA - pBx / pB))
  σpA = pAx / pA * σX + pAν / pA * σν
  σpB = pBx / pB * σX + pBν / pB * σν
  σp = px / p * σX + pν / p * σν
  κ = (σp + σ - (1 - γ) / (γ * (ψ - 1)) * (x * σpA + (1 - x) * σpB)) / (1 / γ)
  κν = γ * ϕ * ν / x
  σA = κ / γ + (1 - γ) / (γ * (ψ - 1)) * σpA
  νA = κν / γ
  σB = κ / γ + (1 - γ) / (γ * (ψ - 1)) * σpB

  # Interest rate r
  μX = x * (1 - x) * ((σA * κ + νA * κν - 1 / pA - τ) - (σB * κ -  1 / pB + τ * x / (1 - x)) - (σA - σB) * (σ + σp))
  μpA = pAx / pA * μX + pAν / pA * μν + 0.5 * pAxx / pA * σX^2 + 0.5 * pAνν / pA * σν^2 + pAxν / pA * σX * σν
  μpB = pBx / pB * μX + pBν / pB * μν + 0.5 * pBxx / pB * σX^2 + 0.5 * pBνν / pB * σν^2 + pBxν / pB * σX * σν
  μp = px / p * μX + pν / p * μν + 0.5 * pxx / p * σX^2 + 0.5 * pνν / p * σν^2 + pxν / p * σX * σν
  r = (1 - i) / p + g + μp + σ * σp - κ * (σ + σp) - γ / x * (ϕ * ν)^2

  # Market Pricing
  pAt = pA * (1 / pA  + (ψ - 1) * τ / (1 - γ) * ((pA / pB)^((1 - γ) / (1 - ψ)) - 1) - ψ * ρ + (ψ - 1) * (r + κ * σA + κν * νA) + μpA - (ψ - 1) * γ / 2 * (σA^2 + νA^2) + (2 - ψ - γ) / (2 * (ψ - 1)) * σpA^2 + (1 - γ) * σpA * σA)
  pBt = pB * (1 / pB - ψ * ρ + (ψ - 1) * (r + κ * σB) + μpB - (ψ - 1) * γ / 2 * σB^2 + (2 - ψ - γ) / (2 * (ψ - 1)) * σpB^2 + (1 - γ) * σpB * σB)
  # algebraic constraint
  pt = p * ((1 - i) / p - x / pA - (1 - x) / pB)

  return (pAt, pBt, pt), (μX, μν)
end

m = DiTellaModel()
stategrid = initialize_stategrid(m)
y0 = initialize_y(m, stategrid)
y, result, distance = pdesolve(m, stategrid, y0)
y, result, distance = pdesolve(m, stategrid, y0; is_algebraic = OrderedDict(:pA => false, :pB => false, :p => true))