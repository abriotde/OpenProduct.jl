
mutable struct OpenProductProducer
	lat::AbstractFloat
	lon::AbstractFloat
	score::AbstractFloat
	name::AbstractString
	firstname::Union{Missing, AbstractString}
	lastname::Union{Missing, AbstractString}
	city::Union{Missing, AbstractString}
	postCode::Union{Missing, Int32}
	address::Union{Missing, AbstractString}
	phoneNumber::Union{Missing, AbstractString}
	phoneNumber2::Union{Missing, AbstractString}
	siret::Union{Missing, AbstractString}
	email::Union{Missing, AbstractString}
	website::Vector{Union{Missing, AbstractString}}
	shortDescription::AbstractString
	text::AbstractString
	sourcekey::Union{Missing, AbstractString}
	imageurl::Union{Missing, AbstractString}
	openingHours::Union{Missing, AbstractString}
	categories::AbstractString
	startdate::AbstractString
	enddate::Union{Missing, AbstractString}
	lastUpdateDate::DateTime
	tag::Int
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
	missing,
	now(),
	0
)
mutable struct OpenProductProducer2
	latitude::AbstractFloat
	longitude::AbstractFloat
	company_name::String
	firstname::Union{Missing, String}
	lastname::Union{Missing, String}
	city::Union{Missing, String}
	post_code::Union{Missing, Int32}
	address::Union{Missing, String}
	phone_number_1::Union{Missing, String}
	phone_number_2::Union{Missing, String}
	siret_number::Union{Missing, String}
	email::Union{Missing, String}
	website::Vector{Union{Missing, String}}
	short_description::String
	description::String
	sourcekey::Union{Missing, String}
	imageurl::Union{Missing, String}
	opening_hours::Union{Missing, String}
	category::String
	startdate::String
	closed_at::Union{Missing, String}
	lastUpdateDate::DateTime
	tag::Int
end

OpenProductProducer2(p::OpenProductProducer) = OpenProductProducer2(
	p.lat, p.lon,
	p.name, p.firstname, p.lastname, p.city, p.postCode, p.address,
	p.phoneNumber, p.phoneNumber2,
	p.siret, p.email, p.website, p.shortDescription, p.text, p.sourcekey, p.imageurl,
	p.openingHours, p.categories,
	p.startdate, p.enddate,p.lastUpdateDate, p.tag
)
