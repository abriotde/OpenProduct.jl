
regexPhone = nothing
function getRegexPhone()
	if isnothing(regexPhone)
		global regexPhone = Regex("^[0-9]{10}\$")
	end
	regexPhone
end
regexPhoneLarge = nothing
function getRegexPhoneLarge()
	if isnothing(regexPhoneLarge)
		global regexPhoneLarge = Regex("^\\+?[0-9 ]{10,20}\$")
	end
	regexPhoneLarge
end
regexEmail = nothing
function getRegexEmail()
	if isnothing(regexEmail)
		global regexEmail = Regex("^[a-z._-]+@[a-z._-]+.[a-z]{2,3}\$")
	end
	regexEmail
end
regexHttpSchema = nothing
function getRegexHttpSchema()
	if isnothing(regexHttpSchema)
		global regexHttpSchema = Regex("^https?://.*")
	end
	regexHttpSchema
end
#=
	@return [latitude, longitude, score, postcode, city, adressName]; if nothing found, return latitude = 0
=#
function getAddressFromXY(latitude, longitude)
	try
		if DEBUG; println("getAddressFromXY(",latitude, ", ", longitude,")"); end
		ADRESS_API_URL = "https://api-adresse.data.gouv.fr/reverse/"
		url = ADRESS_API_URL * "?lon="*string(longitude)*"&lat="*string(latitude)
		response = HTTP.get(url)
		jsonDatas = response.body |> String |> JSON.parse
		addr = jsonDatas["features"][1]
		# println(place)
		props = addr["properties"]
		coordinates = addr["geometry"]["coordinates"]
		[coordinates[2], coordinates[1], props["score"], props["postcode"], props["city"], props["name"]]
    catch err
        println("ERROR : fail getAddressFromXY() : ",err)
        [0, 0, 0, 0, "", 0]
    end
end
function getXYFromAddress(address)
	try
		println("getXYFromAddress(",address,")")
		ADRESS_API_URL = "https://api-adresse.data.gouv.fr/search/"
		address = replace(strip(address), "\""=>"")
		url = ADRESS_API_URL * "?q=" * URIs.escapeuri(address)
		# println("CALL: ",url)
		response = HTTP.get(url)
		jsonDatas = response.body |> String |> JSON.parse
		addr = jsonDatas["features"][1]
		coordinates = addr["geometry"]["coordinates"]
		props = addr["properties"]
		m=match(Regex("(.*)\\s*"*props["postcode"]*"\\s*"*props["city"]), address)
		if m!=nothing
			address = m[1]
		end
		[coordinates[2], coordinates[1], props["score"], props["postcode"], props["city"], address]
    catch err
        println("ERROR : fail getXYFromAddress() : ",err)
        [0, 0, 0, 0, "", address]
    end
end

function getPhoneNumber(phoneString::AbstractString)
	phoneNumber = ""
	for c in phoneString
		if c>='0' && c<='9'
			phoneNumber *= c
		end
	end
	phoneNumber
end
function getPhoneNumber(phoneString::Integer)
	"0"*string(phoneString)
end

function getKey(array::Dict, keys, defaultValue)
	for key in keys
		if haskey(array, key) && array[key]!==nothing
			return array[key]
		end
	end
	defaultValue
end

function getWebSiteStatus(url)
	# println("getWebSiteStatus(",url,")")
	websiteStatus = "unknown"
	try
		r = HTTP.get(url, timeout=30, status_exception=false)
		# println("Response:",r)
		if r.status==200
			websiteStatus = "ok"
		elseif r.status==404
			println("=> ",r.status, "; URL:",url)
		elseif r.status>=400 && r.status<500
			websiteStatus = "400"
		elseif r.status==500 || r.status==503
			websiteStatus = "ko"
		else
			println(" =>",r.status, "; URL:",url)
		end
	catch  err
		if isa(err, HTTP.ConnectError)
			websiteStatus = "ConnectionError"
		elseif isa(err, ArgumentError)
			m = match(getRegexHttpSchema(), url)
			if m==nothing
				newUrl = "https://"*url
				ok = getWebSiteStatus(newUrl)
				if ok=="ok"
					println("Change URL : ",url," => ",newUrl)
					sql2 = "UPDATE producer
						SET website='"*newUrl*"'
						WHERE website='"*url*"'"
					DBInterface.execute(dbConnection, sql2)
				end
				return ok
			end
			println("ERROR:",err)
			exit(1);
		elseif isa(err, HTTP.Exceptions.StatusError)
			websiteStatus = "400"
			println("Status: for ", err)
			exit(1)
		else
			println("ERROR:",err)
			exit(1);
		end
	end
	# print("getWebSiteStatus(",url,") => ", websiteStatus)
	websiteStatus
end