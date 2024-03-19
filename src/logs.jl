
@enum ScriptStatus start ok ko
SCRIPT_UNIQ = ""
function op_start(dbCnx = nothing, comment::String = "")
	if isnothing(dbCnx)
		dbCnx = dbConnection
	end
	global SCRIPT_UNIQ = string(round(Int, datetime2unix(now())*1000), base = 35)
	if ismissing(SCRIPT_NAME)
		println("ERROR : Missing SCRIPT_NAME constant")
		exit(1)
	end
	sql = "INSERT INTO script_history (script, time, state ,uniq ,comment)
		VALUES ('"*SCRIPT_NAME*"', now(), 'start', '"*SCRIPT_UNIQ*"', '"*MySQL.escape(dbCnx, comment)*"')"
	DBInterface.execute(dbCnx,sql)
end
function op_stop(returnValue::ScriptStatus; dbCnx = nothing, comment::String = "")
	println("op_stop("*SCRIPT_NAME*", "*SCRIPT_UNIQ*")")
	if isnothing(dbCnx)
		dbCnx = dbConnection
	end
	if ismissing(SCRIPT_NAME)
		println("ERROR : Missing SCRIPT_NAME constant")
		exit(1)
	end
	sql = "INSERT INTO script_history (script, time, state ,uniq ,comment)
		VALUES ('"*SCRIPT_NAME*"', now(), '"*string(returnValue)*"', '"*SCRIPT_UNIQ*"', '"*MySQL.escape(dbCnx, comment)*"')"
	DBInterface.execute(dbCnx,sql)
	DBInterface.close!(dbCnx)
end
function op_getPreviousScriptTime(returnValue::ScriptStatus; dbCnx=nothing)
	if isnothing(dbCnx)
		dbCnx = dbConnection
	end
	sql = "SELECT max(t) FROM (
			SELECT min(`time`) t, GROUP_CONCAT(state) s 
			FROM script_history
			WHERE script='"*SCRIPT_NAME*"'
			GROUP BY uniq HAVING count(*)>=2 AND s='start,ok'
		) a"
	if DEBUG
		println("SQL:",sql)
	end
	res = DBInterface.execute(dbCnx,sql)
	for row in res
		return row[1]
	end
end