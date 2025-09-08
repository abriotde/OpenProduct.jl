
mutable struct OpenProductProducer
	lat::AbstractFloat
	lon::AbstractFloat
	score::AbstractFloat
	name::String
	firstname::String
	lastname::String
	city::String
	postCode::Union{Missing, Int32}
	address::String
	phoneNumber::String
	phoneNumber2::String
	siret::String
	email::String
	website::String
	shortDescription::String
	text::String
	openingHours::String
	categories::String
	startdate::String
	enddate::String
	lastUpdateDate::DateTime
end
OpenProductProducer() = OpenProductProducer(
	0.0,0.0,0.0,"","","","",missing,"","","","","","","","","","","","",now()
)

PRODUCER_UPDATE_FIELDS = [
	"name", "firstname", "lastname", 
	"city", "postCode", "address", 
	"phoneNumber", "phoneNumber2", "siret", "email", "website", 
	"shortDescription", "text", "openingHours", "categories"
]
PRODUCER_UPDATE_FIELDS_KEY = [
	:name, :firstname, :lastname, 
	:city, :postCode, :address, 
	:phoneNumber, :phoneNumber2, :siret, :email, :website, 
	:shortDescription, :text, :openingHours, :categories
]
@memoize function GetConnection()
	nothing
end

function dbConnect(dbConfFilepath)::DBInterface.Connection
	# DB_CONFIGURATION_FILE = "../../openproduct-web/db/connection.yml"
	dbconfiguration = YAML.load_file(dbConfFilepath)
	dbconf = dbconfiguration["dev"]
	DBInterface.connect(MySQL.Connection, 
		dbconf["host"], dbconf["username"], dbconf["password"], 
		db=dbconf["database"],
		opts=Dict("found_rows"=>true)
	)
end
DATEFORMAT_MYSQL = nothing
function mysql_get_dateformat()
	if isnothing(DATEFORMAT_MYSQL)
		global DATEFORMAT_MYSQL = DateFormat("yyyy-mm-dd H:M:S")
	end
	DATEFORMAT_MYSQL
end
sqlSelectTag = nothing
sqlInsertTagLink = nothing
function mysql_get_sqlSelectTag()
	if isnothing(sqlSelectTag)
		sql = "SELECT * FROM produce WHERE fr like ?"
		global sqlSelectTag = DBInterface.prepare(GetConnection(), sql)
	end
	sqlSelectTag
end
function mysql_get_sqlInsertTag()
	if isnothing(sqlInsertTag)
		sql = "INSERT INTO produce(fr) VALUES (?)"
		global sqlInsertTag = DBInterface.prepare(GetConnection(), sql)
	end
	sqlInsertTag
end
function mysql_get_sqlInsertTagLink()
	if isnothing(sqlInsertTagLink)
		sql = "INSERT IGNORE INTO product_link(producer, produce) VALUES (?,?)"
		global sqlInsertTagLink = DBInterface.prepare(GetConnection(), sql)
	end
	sqlInsertTagLink
end


function complete(producer::OpenProductProducer)
	if (strip(producer.address)=="" || producer.city=="" || producer.postCode=="") && 
			producer.lat>0 && producer.lon>0
		lat, lon, score, postCode, city, address = getAddressFromXY(producer.lat, producer.lon)
		if lat==0
			println("ERROR : insertProducer(",producer,") : No coordinates found from getAddressFromXY().")
			return false
		end
		producer.lat = lat
		producer.lon = lon
		producer.score = score
		producer.postCode = parse(Int32, postCode)
		producer.city = city
		producer.address = address
	elseif (producer.city!="" && producer.postCode!="") && 
			(producer.lat==0 || producer.lon==0)
		lat, lon, score, postCode, city, address = getXYFromAddress(producer.address*" "*producer.postCode*" "*producer.city)
		if lat==0
			println("ERROR : insertProducer(",producer,") : No coordinates found from getAddressFromXY().")
			return false
		end
		producer.lat = lat
		producer.lon = lon
		producer.score = score
		producer.postCode = parse(Int32, postCode)
		producer.city = city
		producer.address = address
	end
end

function getSimilarityScore(s1::String, s2::String)
	val = lowercase(strip(s1))
	oval = lowercase(strip(s2))
	if val!="" && oval!=""
		dist = StringDistances.Levenshtein()(oval, val)
		s = 10 ^ (dist/max(length(oval), length(val)))
		return 1/s
	end
	0
end
function getSimilarityScore(p::Dict, producer::OpenProductProducer)
	score = 0
	score += 10*getSimilarityScore(p[:name], producer.name)
	dist = ((p[:longitude]-producer.lon)^2) + ((p[:latitude]-(producer.lat))^2)
	score += 10*(1/(100 ^ (dist*100)))
	return score
end
sqlSearchXY = nothing
function mysql_get_sqlSearchXY()
	if isnothing(sqlSearchXY)
		sql ="SELECT * FROM openproduct.producer
			WHERE (latitude between ?-0.001 AND ?+0.001
				AND longitude between ?-0.001 AND ?+0.001
			) OR name like ?"
		global sqlSearchXY = DBInterface.prepare(GetConnection(), sql)
	end
	sqlSearchXY
end
#=
	Search if the producer exists in DB
	@return DBresult
=#
function search(producer::OpenProductProducer) # ::Union{Nothing, }
	# println("search(",producer,")")
	name = producer.name
	if name == ""
		name = "XXXXXXXXXX"
	end
	if producer.lat==0 || producer.lon==0
		complete(producer)
	end
	lat = producer.lat
	lon = producer.lon
	res = DBInterface.execute(mysql_get_sqlSearchXY(), [lat, lat, lon, lon, name])
	producers = []
	numrows = 0
	for producerDB in res
		numrows += 1
		# TODO : avoid use Dict() when just one row.
		prod = Dict(propertynames(producerDB) .=> values(producerDB))
		push!(producers, prod)
	end
	len = length(producers)
	if len==0
		return nothing
	elseif len==1
		return producers[1]
	elseif len>1
		# println("\nsearch() => ",len," choice :")
		bestScore::AbstractFloat = 0.0
		bestId::Int = 0
		for (id, p) in enumerate(producers)
			score = getSimilarityScore(p, producer)
			if score>bestScore
				bestId = id
				bestScore = score
			end
		end
		return producers[bestId]
	end
	nothing
end

@memoize function mysql_get_sqlInsert()
	sql::String = "Insert ignore into producer (latitude, longitude, geoprecision"
	for field in PRODUCER_UPDATE_FIELDS
		sql *= ",`"*field*"`"
	end
	sql *= ") values (?,?,?"
	for field in PRODUCER_UPDATE_FIELDS
		sql *= ",?"
	end
	sql *= ") on duplicate key update "
	sep = ""
	for field in PRODUCER_UPDATE_FIELDS
		sql *= sep*"`"*field*"` = if(length(coalesce(`"*field*"`,''))<length(values(`"*field*"`)), values(`"*field*"`), `"*field*"`)"
		sep = ","
	end
	# println("SQL:",sql)
	sqlInsert = DBInterface.prepare(GetConnection(), sql)
end
function insert(producer::OpenProductProducer)::Int32
	complete(producer)
	values = [
		producer.lat, producer.lon, producer.score, producer.name, producer.firstname, producer.lastname, producer.city, producer.postCode,
		producer.address, producer.phoneNumber, producer.phoneNumber2, producer.siret, producer.email, producer.website,
		producer.shortDescription, producer.text, producer.openingHours, producer.categories
	]
	println("Insert producer : ", values)
	if !SIMULMODE
		results = DBInterface.execute(mysql_get_sqlInsert(), values)
		v = DBInterface.lastrowid(results)
		if isnothing(v)
			0
		else
			convert(Int32, v)
		end
	else
		0
	end
end


function update(producerDB, producer; force=false)
	# complete(producer)
	# if(DEBUG); println("update(",producerDB,", ",producer,")"); end
	sql::String = ""
	sep = "";
	for field in PRODUCER_UPDATE_FIELDS_KEY
		dbVal = producerDB[field]
		val = getfield(producer, field)
		ok, postSQL = getUpdateVal(producerDB, field, dbVal, val, force)
		if ok
			# println("DBval1:'",dbVal,"'(",typeof(dbVal),"); val:'",val,"'(",typeof(val),")")
			sql *= sep*"`"*string(field)*"`='"*MySQL.escape(GetConnection(), val)*"'"*postSQL
			sep = ", "
		end
	end
	if sql!=""
		sql = "UPDATE producer SET "*sql*" WHERE id=" * string(producerDB[:id])
		println("SQL:",sql,";")
		if !SIMULMODE
			res = DBInterface.execute(GetConnection(), sql)
		end
	end
	producerDB[:id]
end

function getUpdateVal(producerDB, field, dbVal::Union{Missing, Integer}, val::Union{Missing, Integer}, force::Bool)
	if ismissing(val) || val=="NULL"
		val = 0
	end
	if ismissing(dbVal)
		dbVal = 0
	end
	ok::Bool = false
	postSQL::String = ""
	if force
		ok = (dbVal!=val) && val!=0
	elseif val!=0 && (dbVal!=val) # Case !force
		if dbVal==0
			ok = true
		end
	end
	[ok, postSQL]
end
function getUpdateVal(producerDB, field, dbVal::Union{Missing, String}, val::Union{Missing, String}, force::Bool)
	if ismissing(val) || val=="NULL"
		val = ""
	end
	if ismissing(dbVal)
		dbVal = ""
	end
	ok::Bool = false
	postSQL::String = ""
	if force
		if field==:categories
			ok = false
		else
			dbVal=strip(replace(dbVal, ","=>" ", "\n"=>" ", "\r"=>"", "\""=>"")) # TODO : For import in gogocarto we had to remove ","
			val=strip(replace(val, ","=>" ", "\n"=>" ", "\r"=>"", "\""=>""))
			ok = ((dbVal!=val) && val!="")
		end
	elseif val!="" && (dbVal!=val) # Case !force
		if dbVal==""
			ok = true
		elseif field==:text
			if length(dbVal)<32 && length(val)>32
				ok = true
			end
		elseif field==:email
			if (!ismissing(producerDB[:sendEmail])) && producerDB[:sendEmail]=="wrongEmail"
				ok = true
				postSQL=",sendEmail=NULL"
			end
		elseif field==:website
			status = producerDB[:websiteStatus]
			if status!="ok" && status!="unknown"
				ok = true
				postSQL=",websiteStatus='unknown'"
			end
		end
		if field==:enddate && val!=""
			postSQL=",status='hs'"
		end
	end
	if false
		println("DBval2:'",dbVal,"'(",typeof(dbVal),"); val:'",val,"'(",typeof(val),")")
	end
	[ok, postSQL]
end

#=
=#
function insertOnDuplicateUpdate(producer::OpenProductProducer; forceInsert=false, forceUpdate=false)::Int32
	producerDB = search(producer)
	if producerDB==nothing
		if producer.text==""
			producer.text = producer.shortDescription
		end
		if (forceInsert || producer.email!="" || producer.phoneNumber!="" || producer.website!="" || producer.siret!="") && 
				producer.text!="" && producer.name!="" && producer.categories!=""
			insert(producer)
		else
			println("SKIP:",producer,"")
			0
		end
	else
		# if DEBUG; println("Found:", producerDB); end
		if forceUpdate && producerDB[:lastUpdateDate]<producer.lastUpdateDate
			force=true
		else
			force=false
		end
		update(producerDB, producer, force=force)
		producerDB[:id]
	end
end

function getTagIdDefaultInsert(tagname::AbstractString)::Int32
	results = DBInterface.execute(mysql_get_sqlSelectTag(), [tagname])
	for res in results
		return res[:id]
	end
	results = DBInterface.execute(sqlInsertTag, [tagname])
	id = DBInterface.lastrowid(results)
	convert(Int32, id)
end
#=
@param : id : id of producer
@param : tag : tag/produce name
=#
function setTagOnProducer(producerId::Int32, tagName::AbstractString)
	tagId = getTagIdDefaultInsert(tagName)
	DBInterface.execute(mysql_get_sqlInsertTagLink(), [producerId, tagId])
end

function getAllAreas()
	areas::Vector{Int} = []
	sql = "SELECT distinct if(postCode>200, cast(postCode/1000 as int), postCode) as area
		from producer
		WHERE postCode IS NOT NULL
		ORDER BY area"
	areasRes = DBInterface.execute(GetConnection(),sql)
	for area in areasRes
		if area[1] === missing
			println("Error : null postCode in producer")
			exit()
		end
		push!(areas, area[1])
	end
	areas
end