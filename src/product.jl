
#==
	Load from DB all OpenProduct.products by id product.
	TODO : move this function appart.
==#
products_by_id = missing
function loadProducts(dbConnection, used::Bool=true)::Dict{Integer, String}
	products = Dict()
	sql="select id, name from products"
	if (used)
		sql2="SELECT update_products_used();"
		pdcts = DBInterface.execute(dbConnection, sql2)

		sql *= " where used =True;"
	end
	pdcts = DBInterface.execute(dbConnection, sql)
	for product in pdcts
		products[product[1]] = product[2]
	end
	# println(products)
	products
end

#==
	convert product id's list in string to Vector{String} by product name.
==#
function convert_product_ids_to_list(production::Union{Missing, String}, dbConnection)::Vector{String}
	if ismissing(products_by_id)
		global products_by_id
		products_by_id = loadProducts(dbConnection, true)
	end
	production_lst = []
	if !ismissing(production)
		for product_id in split(production, ",")
			product = products_by_id[parse(Int, product_id)]
			push!(production_lst, product)
		end
		# println(" - Production: ", production_lst)
	end
	production_lst
end
