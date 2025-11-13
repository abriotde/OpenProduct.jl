
mutable struct OpenProductProducer
	lat::AbstractFloat
	lon::AbstractFloat
	score::AbstractFloat
	name::String
	firstname::Union{Missing, String}
	lastname::Union{Missing, String}
	city::String
	postCode::Union{Missing, Int32}
	address::Union{Missing, String}
	phoneNumber::Union{Missing, String}
	phoneNumber2::Union{Missing, String}
	siret::Union{Missing, String}
	email::Union{Missing, String}
	website::Vector{String}
	shortDescription::String
	text::String
	sourcekey::Union{Missing, String}
	imageurl::Union{Missing, String}
	openingHours::Union{Missing, String}
	categories::String
	startdate::String
	enddate::Union{Missing, String}
	lastUpdateDate::DateTime
end
OpenProductProducer() = OpenProductProducer(
	0.0,0.0,0.0,
	"","","",
	"",0,"",
	"","", # PhoneNumbers
	"",
	"", # email
	[], # website
	"","",
	"", # openingHours
	""
	,"", # startdate
	"",
	now()
)
mutable struct OpenProductProducer2
	latitude::AbstractFloat
	longitude::AbstractFloat
	company_name::String
	firstname::Union{Missing, String}
	lastname::Union{Missing, String}
	city::String
	post_code::Union{Missing, Int32}
	address::Union{Missing, String}
	phone_number_1::Union{Missing, String}
	phone_number_2::Union{Missing, String}
	siret_number::Union{Missing, String}
	email::Union{Missing, String}
	website::Vector{String}
	short_description::String
	description::String
	sourcekey::Union{Missing, String}
	imageurl::Union{Missing, String}
	opening_hours::Union{Missing, String}
	category::String
	startdate::String
	closed_at::Union{Missing, String}
	lastUpdateDate::DateTime
end

OpenProductProducer2(p::OpenProductProducer) = OpenProductProducer2(
	p.lat, p.lon,
	p.name, p.firstname, p.lastname, p.city, p.postCode, p.address,
	p.phoneNumber, p.phoneNumber2,
	p.siret, p.email, p.website, p.shortDescription, p.text, p.sourcekey, p.imageurl,
	p.openingHours, p.categories,
	p.startdate, p.enddate,p.lastUpdateDate
)

PRODUCER_UPDATE_FIELDS = [
	"company_name", "firstname", "lastname", 
	"city", "post_code", "address", 
	"phone_number_1", "phone_number_2", "siret_number", "email", "website_1", "website_2", "website_3", 
	"short_description", "description", "opening_hours", "category"
]
PRODUCER_UPDATE_FIELDS_KEY = [
	:company_name, :firstname, :lastname, 
	:city, :post_code, :address, 
	:phone_number_1, :phone_number_2, :siret_number, :email, :website_1, :website_2, :website_3,
	:short_description, :description, :opening_hours, :category
]
# function get_connection()
# 	println("GetConnection => nothing")
# 	nothing
# end

DATEFORMAT_MYSQL = nothing
function mysql_get_dateformat()
	if isnothing(DATEFORMAT_MYSQL)
		global DATEFORMAT_MYSQL = DateFormat("yyyy-mm-dd H:M:S")
	end
	DATEFORMAT_MYSQL
end
sqlSelectTag = nothing
sqlInsertTagLink = nothing
function mysql_get_sqlSelectTag(dbConnection)
	if isnothing(sqlSelectTag)
		sql = "SELECT * FROM produce WHERE fr like ?"
		global sqlSelectTag = DBInterface.prepare(dbConnection, sql)
	end
	sqlSelectTag
end
function mysql_get_sqlInsertTag(dbConnection)
	if isnothing(sqlInsertTag)
		sql = "INSERT INTO produce(fr) VALUES (?)"
		global sqlInsertTag = DBInterface.prepare(dbConnection, sql)
	end
	sqlInsertTag
end
function mysql_get_sqlInsertTagLink(dbConnection)
	if isnothing(sqlInsertTagLink)
		sql = "INSERT IGNORE INTO product_link(producer, produce) VALUES (?,?)"
		global sqlInsertTagLink = DBInterface.prepare(dbConnection, sql)
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
	else
		producer.city = strip(producer.city)
		producer.address = strip(producer.address)
		if producer.postCode>100000 || producer.postCode<1000
			throw("complete() : producer.postCode is invalid : "*string(producer.postCode))
		end
	end
	s = size(producer.website, 1)
	if s>3
		# Keep most intersting ones (remove missing, then Status ok)
		producer.website = producer.website[1:3]
	elseif s<3
		for _ in [s+1:3]
			push!(producer.website, "")
		end
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
function chooseTheBest(producers)
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
sqlSearchXY = nothing
function mysql_get_sqlSearchXY(dbConnection)
	if isnothing(sqlSearchXY)
		sql ="SELECT * FROM producers
			WHERE (latitude between \$1-0.001 AND \$1+0.001
				AND longitude between \$2-0.001 AND \$2+0.001
			)"
		global sqlSearchXY = DBInterface.prepare(dbConnection, sql)
	end
	sqlSearchXY
end
sqlSearchAdress = nothing
function mysql_get_sqlSearchAdress(dbConnection)
	if isnothing(sqlSearchAdress)
		sql ="SELECT * FROM producers
			WHERE lower(address)=\$1 AND post_code=\$2 and lower(city)=\$3"
		global sqlSearchAdress = DBInterface.prepare(dbConnection, sql)
	end
	sqlSearchAdress
end
sqlSearchCompanyName = nothing
function mysql_get_sqlSearchCompanyName(dbConnection)
	if isnothing(sqlSearchCompanyName)
		sql ="SELECT * FROM producers WHERE lower(company_name) = \$1"
		global sqlSearchCompanyName = DBInterface.prepare(dbConnection, sql)
	end
	sqlSearchCompanyName
end
sqlSearchSiretNumber = nothing
function mysql_get_sqlSearchSiretNumber(dbConnection)
	if isnothing(sqlSearchSiretNumber)
		sql ="SELECT * FROM producers WHERE siret_number=\$1"
		global sqlSearchSiretNumber = DBInterface.prepare(dbConnection, sql)
	end
	sqlSearchSiretNumber
end
#=
	Search if the producer exists in DB
	@return DBresult
=#
function search(dbConnection::DBInterface.Connection, producer::OpenProductProducer) # ::Union{Nothing, }
	# println("search(",producer,")")

	# Search by company_name
	producers = []
	res = DBInterface.execute(mysql_get_sqlSearchCompanyName(dbConnection), [lowercase(producer.name)])
	for producerDB in res
		prod = Dict(propertynames(producerDB) .=> values(producerDB))
		push!(producers, prod)
	end
	len = length(producers)
	if len==1
		return producers[1]
	elseif len>1
		throw("Many producers found with name = "*producer.name)
	end

	# Search by Address
	res = DBInterface.execute(mysql_get_sqlSearchAdress(dbConnection), [
		lowercase(producer.address), producer.postCode, lowercase(producer.city)
	])
	for producerDB in res
		prod = Dict(propertynames(producerDB) .=> values(producerDB))
		push!(producers, prod)
	end
	len = length(producers)
	if len==1
		return producers[1]
	elseif len>1
		throw("Many producers found with address = "*
			producer.address*" "*string(producer.postCode)*" "*producer.city)
	end

	# Search by Siret Number
	res = DBInterface.execute(mysql_get_sqlSearchSiretNumber(dbConnection), [producer.siret])
	for producerDB in res
		prod = Dict(propertynames(producerDB) .=> values(producerDB))
		push!(producers, prod)
	end
	len = length(producers)
	if len==1
		return producers[1]
	elseif len>1
		throw("Many producers found with siret number = "*producer.siret)
	end


	# Search by lat/lon
	if producer.lat==0 || producer.lon==0
		complete(producer)
	end
	name = producer.name
	if name == ""
		name = "XXXXXXXXXX"
	end
	lat = producer.lat
	lon = producer.lon
	res = DBInterface.execute(mysql_get_sqlSearchXY(dbConnection), [lat, lon])
	producers = []
	numrows = 0
	for producerDB in res
		numrows += 1
		# TODO : avoid use Dict() when just one row.
		prod = Dict(propertynames(producerDB) .=> values(producerDB))
		push!(producers, prod)
	end
	len = length(producers)
	if len==1
		return producers[1]
	elseif len>1
		# println("\nsearch() => ",len," choice :")
		# return chooseTheBest(producers)
		throw("Many producers found with similar location = "*lat*","*lon)
	end
	nothing
end

@memoize function mysql_get_sqlInsert(dbConnection)
	sql::String = "Insert into producers (latitude, longitude"
	for field in PRODUCER_UPDATE_FIELDS
		sql *= ",\""*field*"\""
	end
	sql *= ") values (\$1,\$2"
	i=3
	for field in PRODUCER_UPDATE_FIELDS
		sql *= ",\$"*string(i)
		i+=1
	end
	sql *= ")"
	println("SQL:",sql)
	sqlInsert = DBInterface.prepare(dbConnection, sql)
end
function insert(dbConnection::DBInterface.Connection,
		producer::OpenProductProducer)::Int32
	complete(producer)
	values = [
		producer.lat, producer.lon, producer.name, producer.firstname, producer.lastname, producer.city, producer.postCode,
		producer.address, producer.phoneNumber, producer.phoneNumber2, producer.siret, producer.email]
	for website in producer.website
		push!(values, website)
	end
	values = vcat(values, [producer.shortDescription, producer.text, producer.openingHours, producer.categories])
	println("Insert producer : ", values)
	if !SIMULMODE
		results = DBInterface.execute(mysql_get_sqlInsert(dbConnection), values)
		# v = DBInterface.lastrowid(results)
		# if isnothing(v)
		# 	0
		# else
		# 	1
		# end
		1
	else
		1
	end
end

regexWebsiteField = r"^website_([1-3])$"

function update(dbConnection::DBInterface.Connection,producerDB, producer; force=false)
	# complete(producer)
	# if(DEBUG); println("update(",producerDB,", ",producer,")"); end
	sql::String = ""
	sep = "";
	producer2 = OpenProductProducer2(producer)
	for field in PRODUCER_UPDATE_FIELDS_KEY
		dbVal = producerDB[field]
		val = missing
		field_str = string(field)
		m = match(regexWebsiteField, field_str)
		if m!=nothing
			val = get(producer2.website, parse(Int, m[1]), missing)
		else
			val = getfield(producer2, field)
		end
		ok, postSQL = getUpdateVal(producerDB, field, dbVal, val, force)
		if ok
			# println("DBval1:'",dbVal,"'(",typeof(dbVal),"); val:'",val,"'(",typeof(val),")")
			sql *= sep*"\""*field_str*"\"='"*MySQL.escape(dbConnection, val)*"'"*postSQL
			sep = ", "
		end
	end
	if sql!=""
		sql = "UPDATE producer SET "*sql*" WHERE id=" * string(producerDB[:id])
		println("SQL:",sql,";")
		if !SIMULMODE
			res = DBInterface.execute(dbConnection, sql)
		end
	else
		println("Nothing to update for ", producer.name)
	end
	producerDB[:id]
end

function getUpdateVal(producerDB, field, dbVal::Integer, val::Union{Missing, Integer}, force::Bool)
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
function insertOnDuplicateUpdate(
		dbConnection::DBInterface.Connection,
		producer::OpenProductProducer;
		forceInsert=false, forceUpdate=false)::Int32
	producerDB = search(dbConnection, producer)
	if producerDB==nothing
		if producer.text==""
			producer.text = producer.shortDescription
		end
		if (forceInsert || producer.email!="" || producer.phoneNumber!="" || producer.website!="" || producer.siret!="") && 
				producer.text!="" && producer.name!="" && producer.categories!=""
			insert(dbConnection, producer)
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
		update(dbConnection, producerDB, producer, force=force)
		producerDB[:id]
	end
end

function getTagIdDefaultInsert(tagname::AbstractString)::Int32
	results = DBInterface.execute(mysql_get_sqlSelectTag(dbConnection), [tagname])
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
	DBInterface.execute(mysql_get_sqlInsertTagLink(dbConnection), [producerId, tagId])
end

function getAllAreas()
	areas::Vector{Int} = []
	sql = "SELECT distinct if(postCode>200, cast(postCode/1000 as int), postCode) as area
		from producer
		WHERE postCode IS NOT NULL
		ORDER BY area"
	areasRes = DBInterface.execute(get_connection(),sql)
	for area in areasRes
		if area[1] === missing
			println("Error : null postCode in producer")
			exit()
		end
		push!(areas, area[1])
	end
	areas
end