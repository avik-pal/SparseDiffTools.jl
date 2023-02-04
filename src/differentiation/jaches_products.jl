struct DeivVecTag end

get_tag(::Array{Dual{T, V, N}}) where {T, V, N} = T
get_tag(::Dual{T, V, N}) where {T, V, N} = T

# J(f(x))*v
function auto_jacvec!(dy,
                      f,
                      x,
                      v,
                      cache1 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(), eltype(x))),
                                    eltype(x), 1
                                    }.(x,
                                       ForwardDiff.Partials.(tuple.(reshape(v, size(x))))),
                      cache2 = similar(cache1))
    cache1 .= Dual{get_tag(cache1), eltype(x), 1
                   }.(x, ForwardDiff.Partials.(tuple.(reshape(v, size(x)))))
    f(cache2, cache1)
    vecdy = _vec(dy)
    vecdy .= partials.(_vec(cache2), 1)
end

_vec(v) = vec(v)
_vec(v::AbstractVector) = v

function auto_jacvec(f, x, v)
    vv = reshape(v, axes(x))
    y = ForwardDiff.Dual{typeof(ForwardDiff.Tag(DeivVecTag(), eltype(x))), eltype(x), 1
                         }.(x, ForwardDiff.Partials.(tuple.(vv)))
    vec(partials.(vec(f(y)), 1))
end

function num_jacvec!(dy,
                     f,
                     x,
                     v,
                     cache1 = similar(v),
                     cache2 = similar(v);
                     compute_f0 = true)
    vv = reshape(v, axes(x))
    compute_f0 && (f(cache1, x))
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(norm(x)))
    @. x += ϵ * vv
    f(cache2, x)
    @. x -= ϵ * vv
    vecdy = _vec(dy)
    veccache1 = _vec(cache1)
    veccache2 = _vec(cache2)
    @. vecdy = (veccache2 - veccache1) / ϵ
end

function num_jacvec(f, x, v, f0 = nothing)
    vv = reshape(v, axes(x))
    f0 === nothing ? _f0 = f(x) : _f0 = f0
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(minimum(x)))
    vec((f(x .+ ϵ .* vv) .- _f0) ./ ϵ)
end

function num_hesvec!(dy,
                     f,
                     x,
                     v,
                     cache1 = similar(v),
                     cache2 = similar(v),
                     cache3 = similar(v))
    cache = FiniteDiff.GradientCache(v[1], cache1, Val{:central})
    g = let f = f, cache = cache
        (dx, x) -> FiniteDiff.finite_difference_gradient!(dx, f, x, cache)
    end
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(norm(x)))
    @. x += ϵ * v
    g(cache2, x)
    @. x -= 2ϵ * v
    g(cache3, x)
    @. dy = (cache2 - cache3) / (2ϵ)
end

function num_hesvec(f, x, v)
    g = (x) -> FiniteDiff.finite_difference_gradient(f, x)
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(norm(x)))
    x += ϵ * v
    gxp = g(x)
    x -= 2ϵ * v
    gxm = g(x)
    (gxp - gxm) / (2ϵ)
end

function numauto_hesvec!(dy,
                         f,
                         x,
                         v,
                         cache = ForwardDiff.GradientConfig(f, v),
                         cache1 = similar(v),
                         cache2 = similar(v))
    g = let f = f, x = x, cache = cache
        g = (dx, x) -> ForwardDiff.gradient!(dx, f, x, cache)
    end
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(norm(x)))
    @. x += ϵ * v
    g(cache1, x)
    @. x -= 2ϵ * v
    g(cache2, x)
    @. dy = (cache1 - cache2) / (2ϵ)
end

function numauto_hesvec(f, x, v)
    g = (x) -> ForwardDiff.gradient(f, x)
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(norm(x)))
    x += ϵ * v
    gxp = g(x)
    x -= 2ϵ * v
    gxm = g(x)
    (gxp - gxm) / (2ϵ)
end

function autonum_hesvec!(dy,
                         f,
                         x,
                         v,
                         cache1 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(), eltype(x))),
                                       eltype(x), 1
                                       }.(x,
                                          ForwardDiff.Partials.(tuple.(reshape(v, size(x))))),
                         cache2 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(), eltype(x))),
                                       eltype(x), 1
                                       }.(x,
                                          ForwardDiff.Partials.(tuple.(reshape(v, size(x))))))
    cache = FiniteDiff.GradientCache(v[1], cache1, Val{:central})
    g = (dx, x) -> FiniteDiff.finite_difference_gradient!(dx, f, x, cache)
    cache1 .= Dual{get_tag(cache1), eltype(x), 1
                   }.(x, ForwardDiff.Partials.(tuple.(reshape(v, size(x)))))
    g(cache2, cache1)
    dy .= partials.(cache2, 1)
end

function autonum_hesvec(f, x, v)
    g = (x) -> FiniteDiff.finite_difference_gradient(f, x)
    partials.(g(Dual{DeivVecTag}.(x, v)), 1)
end

function num_hesvecgrad!(dy, g, x, v, cache2 = similar(v), cache3 = similar(v))
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(norm(x)))
    @. x += ϵ * v
    g(cache2, x)
    @. x -= 2ϵ * v
    g(cache3, x)
    @. dy = (cache2 - cache3) / (2ϵ)
end

function num_hesvecgrad(g, x, v)
    T = eltype(x)
    # Should it be min? max? mean?
    ϵ = sqrt(eps(real(T))) * max(one(real(T)), abs(norm(x)))
    x += ϵ * v
    gxp = g(x)
    x -= 2ϵ * v
    gxm = g(x)
    (gxp - gxm) / (2ϵ)
end

function auto_hesvecgrad!(dy,
                          g,
                          x,
                          v,
                          cache2 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(), eltype(x))),
                                        eltype(x), 1
                                        }.(x,
                                           ForwardDiff.Partials.(tuple.(reshape(v, size(x))))),
                          cache3 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(), eltype(x))),
                                        eltype(x), 1
                                        }.(x,
                                           ForwardDiff.Partials.(tuple.(reshape(v, size(x))))))
    cache2 .= Dual{get_tag(cache2), eltype(x), 1
                   }.(x, ForwardDiff.Partials.(tuple.(reshape(v, size(x)))))
    g(cache3, cache2)
    dy .= partials.(cache3, 1)
end

function auto_hesvecgrad(g, x, v)
    y = Dual{typeof(ForwardDiff.Tag(DeivVecTag(), eltype(x))), eltype(x), 1
             }.(x, ForwardDiff.Partials.(tuple.(reshape(v, size(x)))))
    partials.(g(y), 1)
end

### Operator Forms

# replace this with FunctionOperator

islinear(::AutomaticDerivativeOperator) = true
isconstant(::AutomaticDerivativeOperator) = false

#has_ldiv(::AutomaticDerivativeOperator)
#has_ldiv!(::AutomaticDerivativeOperator)

update_coefficients(A::AutomaticDerivativeOperator,u,p,t) = typeof(A)(FWrapper(A.f,p,t),A.cache1,A.cache2,u,A.autodiff)
update_coefficients!(A::AutomaticDerivativeOperator,u,p,t) = (A.u .= u, A.f.p = p; A.f.t = t; A)

mutable struct FWrapper{iip,F,pType,tType}
    f::F
    p::pType
    t::tType
    FWrapper(f,p,t) = new{true,typeof(f),typeof(p),typeof(t)}(f,p,t)
end

(f::FWrapper{true})(du,u) = f.f(du,u,f.p,f.t)
(f::FWrapper{false})(du,u) = du .= f.f(u,f.p,f.t)
(f::FWrapper{true})(u) = (du = similar(u); f.f(du,u,f.p,f.t); du)
(f::FWrapper{false})(u) = f.f(u,f.p,f.t)

struct WrapOut{F,T}
    f::F
    out::T
end
(f::WrapOut)(u) = (f.f(f.out,u); f.out)

########

mutable struct ForwardDiffVecProd{T,
                                  iip,
                                  ad,
                                 } <: AutomaticDerivativeOperator{T, iip}
    func::F
    vecprod::V
    vecprod!::V!
    cache_ad::Ca
    cache_out::Co
    u::U
    p::P
    t::TT
end

function Base.:*(L::ForwardDiffVecProd{T,false}, v) where{T}
    out = similar(v)
    L.vecprod(WrapOut(L.f,out), L.u, v)
end

function Base.:*(L::ForwardDiffVecProd{T,true}, v) where{T}
    L.vecprod(L.f, L.u, v)
end
#Base.:\(L::ForwardDiffVecProd, v)

function LinearAlgebra.mul!(du::AbstractVecOrMat,
                            L::ForwardDiffVecProd,
                            v::AvstractVecOrMat,
                           )
    L.vecprod!(du, L.f, L.u, v, L.cache...)
end

function LinearAlgebra.mul!(du::AbstractVecOrMat,
                            L::ForwardDiffVecProd,
                            v::AvstractVecOrMat,
                            α, β,
                           )
    L.vecprod!(du, L.f, L.u, v, L.cache...)
end

function JacVec(f, stuff; autodiff = true,)
    if autodiff
        cache1 = Dual{
                      typeof(ForwardDiff.Tag(DeivVecTag(),eltype(u))),
                      eltype(u),
                      1
                     }.(
                        u, ForwardDiff.Partials.(tuple.(u))
                       )

        cache2 = deepcopy(cache1)
    else
        cache1 = similar(u)
        cache2 = similar(u)
    end

    cache = (cache1, cache2,)

    ForwardDiffVecProd(f, stuff;
                       vecprod  = autodiff ? auto_jacvec  : num_jacvec,
                       vecprod! = autodiff ? auto_jacvec! : num_jacvec!,
                       cache = cache,
                      )
end

function HesVec(f, stuff; autodiff = true,)
    _f = FWrapper(f,p,t)
    if autodiff
        cache1 = ForwardDiff.GradientConfig(_f, u)
        cache2 = similar(u)
        cache3 = similar(u)
    else
        cache1 = similar(u)
        cache2 = similar(u)
        cache3 = similar(u)
    end

    cache = (cache1, cache2, cache3,)


    ForwardDiffVecProd(f, stuff;
                       vecprod  = autodiff ? numauto_hesvec  : num_hesvec,
                       vecprod! = autodiff ? numauto_hesvec! : num_hesvec!,
                       cache = cache,
                      )
end

function HesVecGrad(f, stuff; autodiff = true,)
    if autodiff
        cache1 = Dual{
                      typeof(ForwardDiff.Tag(DeivVecTag(), eltype(u))),
                      eltype(u),
                      1
                     }.(
                        u, ForwardDiff.Partials.(tuple.(u))
                       )

        cache2 = deepcopy(cache1)
    else
        cache1 = similar(u)
        cache2 = similar(u)
    end

    cache = (cache1, cache2,)

    ForwardDiffVecProd(f, stuff;
                       vecprod  = autodiff ? numauto_hesvecgrad  : num_hesvecgrad,
                       vecprod! = autodiff ? numauto_hesvecgrad! : num_hesvecgrad!,
                       cache = cache,
                      )
end

Base.size(L::ForwardDiffVecProd) = (length(L.cache[1]), length(L.cache[2]),)

## JacVec - Jacobian-vector product

struct JacVec{T,iip,F,T1,T2,uType,pType,tType} <: AutomaticDerivativeOperator{T, iip}
    f::FWrapper{iip,F,pType,tType}
    cache1::T1
    cache2::T2
    u::uType
    autodiff::Bool
end

function JacVec(f, u::AbstractArray, p=nothing, t=nothing; autodiff = true)
    if autodiff
        cache1 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(),eltype(u))),eltype(u),1}.(u, ForwardDiff.Partials.(tuple.(u)))
        cache2 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(),eltype(u))),eltype(u),1}.(u, ForwardDiff.Partials.(tuple.(u)))
    else
        cache1 = similar(u)
        cache2 = similar(u)
    end
    JacVec(FWrapper(f,p,t), cache1, cache2, u, p, t, autodiff)
end

Base.size(L::JacVec) = (length(L.cache1), length(L.cache1))

function Base.:*(L::JacVec{true}, v::AbstractVector)
    out = similar(v)
    if L.autodiff 
        auto_jacvec(WrapOut(L.f,out), L.u, v)
    else
        num_jacvec(WrapOut(L.f,out), L.u, v)
    end
    out
end

function Base.:*(L::JacVec{false}, v::AbstractVector)
    if L.autodiff
        auto_jacvec(L.f, L.u, v)
    else
        num_jacvec(L.f, L.u, v)
    end
end

function LinearAlgebra.mul!(du::AbstractVector, L::JacVec, v::AbstractVector)
    if L.autodiff
        auto_jacvec!(du, L.f, L.u, v, L.cache1, L.cache2)
    else
        num_jacvec!(du, L.f, L.u, v, L.cache1, L.cache2)
    end
end

## HesVec - Hessian-vector product

mutable struct HesVec{iip,F,T1,T2,uType,pType,tType} <: AutomaticDerivativeOperator{iip}
    f::FWrapper{iip,F,pType,tType}
    cache1::T1
    cache2::T2
    cache3::T2
    u::uType
    autodiff::Bool
end

function HesVec(f, u::AbstractArray, p = nothing, t = nothing; autodiff = true)
    _f = FWrapper(f,p,t)
    if autodiff
        cache1 = ForwardDiff.GradientConfig(_f, u)
        cache2 = similar(u)
        cache3 = similar(u)
    else
        cache1 = similar(u)
        cache2 = similar(u)
        cache3 = similar(u)
    end
    HesVec(_f, cache1, cache2, cache3, u, autodiff)
end

Base.size(L::HesVec) = (length(L.cache2), length(L.cache2))

function Base.:*(L::HesVec{true}, v::AbstractVector)
    out = similar(v)
    if L.autodiff 
        numauto_hesvec(WrapOut(L.f,out), L.u, v) 
    else
        num_hesvec(WrapOut(L.f,out), L.u, v)
    end
end

function Base.:*(L::HesVec{true}, v::AbstractVector)
    if L.autodiff 
        numauto_hesvec(L.f, L.u, v) 
    else
        num_hesvec(L.f, L.u, v)
    end
end

function LinearAlgebra.mul!(du::AbstractVector, L::HesVec, v::AbstractVector)
    if L.autodiff
        numauto_hesvec!(du, L.f, L.u, v, L.cache1, L.cache2, L.cache3)
    else
        num_hesvec!(du, L.f, L.u, v, L.cache1, L.cache2, L.cache3)
    end
end

### HesVecGrad - Hessian- gradient vector product

struct HesVecGrad{iip,G,T1,T2,uType,pType,tType} <: AutomaticDerivativeOperator{T}
    g::FWrapper{iip,G,pType,tType}
    cache1::T1
    cache2::T2
    u::uType
    autodiff::Bool
end

function HesVecGrad(g, u::AbstractArray, p = nothing, t = nothing; autodiff = false)
    if autodiff
        cache1 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(),eltype(u))),eltype(u),1}.(u, ForwardDiff.Partials.(tuple.(u)))
        cache2 = Dual{typeof(ForwardDiff.Tag(DeivVecTag(),eltype(u))),eltype(u),1}.(u, ForwardDiff.Partials.(tuple.(u)))
    else
        cache1 = similar(u)
        cache2 = similar(u)
    end
    HesVecGrad(FWrapper(g,p,t), cache1, cache2, u, autodiff)
end

Base.size(L::HesVecGrad) = (length(L.cache2), length(L.cache2))

function Base.:*(L::HesVecGrad{true}, v::AbstractVector)
    out = similar(v)
    if L.autodiff 
        auto_hesvecgrad(WrapOut(L.g,out), L.u, v) 
    else 
        num_hesvecgrad(WrapOut(L.g,out), L.u, v)
    end
end

function Base.:*(L::HesVecGrad{false}, v::AbstractVector)
    if L.autodiff 
        auto_hesvecgrad(L.g, L.u, v) 
    else 
        num_hesvecgrad(L.g, L.u, v)
    end
end

function LinearAlgebra.mul!(du::AbstractVector,L::HesVecGrad,v::AbstractVector)
    if L.autodiff
        auto_hesvecgrad!(du, L.g, L.u, v, L.cache1, L.cache2)
    else
        num_hesvecgrad!(du, L.g, L.u, v, L.cache1, L.cache2)
    end
end
