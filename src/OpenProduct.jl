module OpenProduct

import DBInterface, JSON, TOML, LibPQ, URIs, HTTP
using Dates
using Memoize

global const SIMULMODE::Bool = false
global const DEBUG::Bool = false

if ! (typeof(DEBUG) <: Bool)
	println("ERROR : Missing DEBUG constant (Bool)")
	exit(1)
end
if ismissing(SIMULMODE) || ! (typeof(SIMULMODE) <: Bool)
	println("ERROR : Missing SIMULMODE constant (Bool)")
	exit(1)
end

include("utils.jl")
include("tag.jl")
include("product.jl")
include("mysql.jl")
include("gogocarto.jl")
include("logs.jl")


export op_start
export op_stop
export getAddressFromXY
export getXYFromAddress
export getXYFromAddress2
export OpenProductProducer
export insertOnDuplicateUpdate
export complete
export search

end # module OpenProduct
