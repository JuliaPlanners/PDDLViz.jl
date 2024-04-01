const MaybeObservable{T} = Union{Observable{T}, T}
maybe_observe(x::Observable) = x
maybe_observe(x) = Observable(x)

Point2fVecObservable() = Observable(Point2f[])
