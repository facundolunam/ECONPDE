using EconPDEs

struct GarleanuPanageasModel

  # utility function
  γA::Float64 
  ψA::Float64
  γB::Float64 
  ψB::Float64 
  ρ::Float64
  δ::Float64

  # proportion a
  νA::Float64

  # consumption
  μ::Float64
  σ::Float64

  # earning function
  B1::Float64
  δ1::Float64
  B2::Float64
  δ2::Float64
  ω::Float64
end

function GarleanuPanageasModel(;γA  = 1.5, ψA = 0.7, γB = 10.0, ψB = 0.05, ρ = 0.001, δ = 0.02, νA = 0.01, μ = 0.02, σ = 0.041, B1 = 30.72, δ1 = 0.0525, B2 = -30.29, δ2 = 0.0611, ω = 0.92)
  scale = δ / (δ + δ1) * B1 + δ / (δ + δ2) * B2
  B1 = B1 / scale
  B2 = B2 / scale
  GarleanuPanageasModel(γA , ψA, γB, ψB, ρ, δ, νA, μ, σ, B1, δ1, B2, δ2, ω)
end

function initialize_stategrid(m::GarleanuPanageasModel; n = 200)
  OrderedDict(:x => range(0.0, stop = 1.0, length = n))
end

function initialize_y(m::GarleanuPanageasModel, stategrid::OrderedDict)
    x = ones(length(stategrid[:x]))
    OrderedDict(:pA => x, :pB => x, :ϕ1 => x, :ϕ2 => x)
end

function (m::GarleanuPanageasModel)(state::NamedTuple, y::NamedTuple)
  (; γA, ψA, γB, ψB, ρ, δ, νA, μ, σ, B1, δ1, B2, δ2, ω) = m  
  (; x) = state
  (; pA, pAx, pAxx, pB, pBx, pBxx, ϕ1, ϕ1x, ϕ1xx, ϕ2, ϕ2x, ϕ2xx) = y
  # pA is wealth / consumption ratio of agent A
  # pB is wealth / consumption ratio of agent B
  # ϕ1 is value of claim that promises B_1ωexp(-(δ+δ1)(s-t))C_s/C_t for s ≥ t
  # ϕ2 is value of claim that promises B_2ωexp(-(δ+δ2)(s-t))C_s/C_t for s ≥ t
  # Market price of risk κ
  Γ = 1 / (x / γA + (1 - x) / γB)
  p = x * pA + (1 - x) * pB
  σx = σ * x * (Γ / γA - 1) / (1 + Γ * x * (1 - x) / (γA * γB) * ((1 - γB * ψB) / (ψB - 1) * (pBx / pB) - (1 - γA * ψA) / (ψA - 1) * (pAx / pA)))
  σpA = pAx / pA * σx
  σpB = pBx / pB * σx 
  σϕ1 = ϕ1x / ϕ1 * σx
  σϕ2 = ϕ2x / ϕ2 * σx
  κ = Γ * (σ - x * (1 - γA * ψA) / (γA * (ψA - 1)) * σpA - (1 - x) * (1 - γB * ψB) / (γB * (ψB - 1)) * σpB)
  σCA = κ / γA + (1 - γA * ψA) / (γA * (ψA - 1)) * σpA
  σCB = κ / γB + (1 - γB * ψB) / (γB * (ψB - 1)) * σpB

  # Interest rate r
  # A.16 Equation in Garleanu Panageas has a typo
  mcA = κ^2 * (1 + ψA) / (2 * γA) + (1 - ψA * γA) / (γA * (ψA - 1)) * κ * σpA - (1 - γA * ψA) / (2 * γA * (ψA - 1)) * σpA^2
  mcB = κ^2 * (1 + ψB) / (2 * γB) + (1 - ψB * γB) / (γB * (ψB - 1)) * κ * σpB - (1 - γB * ψB) / (2 * γB * (ψB - 1)) * σpB^2
  r =  ρ + 1 / (ψA * x  + ψB * (1 - x))  * (μ - x * mcA - (1 - x) * mcB - δ * ((νA / pA + (1 - νA) / pB) * (ϕ1 + ϕ2) - 1))
  μCA = ψA * (r - ρ) + mcA
  μCB = ψB * (r - ρ) + mcB
  μx = x * (μCA - δ - μ) + δ * νA / pA * (ϕ1 + ϕ2) - σ * σx  
  μpA = pAx / pA * μx + 0.5 * pAxx / pA * σx^2
  μpB = pBx / pB * μx + 0.5 * pBxx / pB * σx^2
  μϕ1 = ϕ1x / ϕ1 * μx + 0.5 * ϕ1xx / ϕ1 * σx^2
  μϕ2 = ϕ2x / ϕ2 * μx + 0.5 * ϕ2xx / ϕ2 * σx^2
  
  # Market Pricing
  pAt = pA * (1 / pA + (μCA - δ) + μpA + σCA * σpA - r - κ * (σpA + σCA))
  pBt = pB * (1 / pB + (μCB - δ) + μpB + σCB * σpB - r - κ * (σpB + σCB))
  ϕ1t = ϕ1 * (B1 * ω / ϕ1 + (μ - δ - δ1) + μϕ1 + σ * σϕ1 - r - κ * (σϕ1 + σ))
  ϕ2t = ϕ2 * (B2 * ω / ϕ2 + (μ - δ - δ2) + μϕ2 + σ * σϕ2 - r - κ * (σϕ2 + σ))

  return (pAt, pBt, ϕ1t, ϕ2t), (μx, ), (μx = μx, p = p, pA = pA, pB = pB, κ = κ, r = r, σx = σx)
end

m = GarleanuPanageasModel()
stategrid = initialize_stategrid(m)
y0 = initialize_y(m, stategrid)
y, result, distance = pdesolve(m, stategrid, y0)