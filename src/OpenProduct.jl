module OpenProduct

import MySQL, DBInterface, HTTP, JSON, URIs, StringDistances
using Cascadia, YAML, Dates
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
include("mysql.jl")
include("gogocarto.jl")
include("logs.jl")

export op_start
export op_stop

end # module OpenProduct
