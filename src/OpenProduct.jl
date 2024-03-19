#!/bin/env julia

module OpenProduct

import MySQL, DBInterface, HTTP, JSON, URIs, StringDistances
using Cascadia, YAML, Dates

include("utils.jl")
include("mysql.jl")
# include("gogocarto.jl")
include("logs.jl")

export op_start
export op_stop

end # module OpenProduct
