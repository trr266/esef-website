try
    @eval using Revise
  catch e
    @warn "Revise init" exception=(e, catch_backtrace())
  end
  