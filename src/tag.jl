
mutable struct Tag
	id::Integer
	name::String
	label::String
	description::String
	producers::Array{Integer}
end

producers_tag = Dict{Int, Tag}(
	0 => Tag(0, "PME", "Petites et Moyennes Entreprises", "Entreprises de petite et moyenne taille", []),
	1 => Tag(1, "AB", "Agriculture Biologique", "Producteurs certifiés agriculture biologique ou assimilés", []),
	2 => Tag(2, "OpenProduct", "Membre OpenProduct", "Producteur membre de l'asssociation OpenProduct", [])
)
function Tag(tag::Integer)::Tag
	get(producers_tag, tag, missing)
end
function Tag(tag::AbstractString)::Tag
	for t in producers_tag
		if t.name==tag || t.label==Tag
			return t
		end
	end
	return missing
end
#=
	Convert an int encoding all tags to an explicite list of Tag
=#
function convert_tag_to_list(tag::Integer)::Vector{Tag}
	tag_lst = []
	if tag>0
		tag_int = 0
		while tag>0
			t = tag % 2
			if t==1
				push!(tag_lst, producers_tag[tag_int])
			end
			tag = (tag-t)/2
			tag_int += 1
		end
	end
	tag_lst
end
#=
	Convert an explicite list of Tag to an int encoding it
=#
function convert_list_to_tag(list::Vector{Tag})::Integer
	tag_lst = []
	for t in list
		if tag & (2^t.id)>0
			push!(tag_lst, t)
		end
	end
	tag_lst
end
