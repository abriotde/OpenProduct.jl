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
include("mysql.jl")
include("gogocarto.jl")
include("logs.jl")

OPENPRODUCT_ROOT_PATH = missing
OPENPRODUCT_ENV = missing
OPENPRODUCT_DB_CONNECTION = missing
function get_connection(root_path::Union{String, Missing}=missing)
	if !ismissing(root_path)
		global OPENPRODUCT_ROOT_PATH = root_path
	else
		root_path = OPENPRODUCT_ROOT_PATH
	end
	global OPENPRODUCT_DB_CONNECTION
	if ismissing(OPENPRODUCT_DB_CONNECTION)
		# println("get_connection()", pwd())
		if isfile(root_path*"/.env.local")
			global OPENPRODUCT_ENV = "dev"
			conffile = root_path*"/.env.local"
		else
			global OPENPRODUCT_ENV = "prod"
			conffile = root_path*"/.env.production"
		end
		println("Use configuration file : ", conffile)
		conf = TOML.parsefile(conffile)
		DATABASE_NAME = conf["DATABASE_NAME"]
		DATABASE_USER = conf["DATABASE_USER"]
		DATABASE_PASSWORD = conf["DATABASE_PASSWORD"]
		connstr = "host=localhost port=5432 dbname=$DATABASE_NAME user=$DATABASE_USER password=$DATABASE_PASSWORD";
		# cnx = LibPQ.Connection(connstr)
		DB_CONNECTION = DBInterface.connect(LibPQ.Connection, connstr)
		println("Connected")
	end
	println("GetConnection => DB_CONNECTION")
	return DB_CONNECTION
end

export op_start
export op_stop
export getAddressFromXY
export getXYFromAddress
export OpenProductProducer
export insertOnDuplicateUpdate
export complete
export search

end # module OpenProduct
