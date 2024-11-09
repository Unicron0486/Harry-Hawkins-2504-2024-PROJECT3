using Pkg
Pkg.activate(".")
using CSV, DataFrames, HTTP, CSV, Plots, StatsPlots, StatsBase, Dates
path = "./data/Melbourne_housing_FULL.csv"
old_df = CSV.read(path, DataFrame)

names(old_df)
df = copy(old_df)
# unique(df.Suburb) #No missing
# unique(df.Address) #No missing
# unique(df.Rooms) #No missing
# unique(df.Type) #No missing
# unique(df.Method) #No missing
# unique(df.SellerG) #No missing
# unique(df.Date) #No missing

# unique(df.Price) #missing as missing => will need to skip or avg
# df.Price .= coalesce.(df.Price, -1)

# unique(df.Distance) #missin as #N/A
allowmissing!(df, :Distance)
for (i,n) in enumerate(df.Distance)
    if n == "#N/A"
        df.Distance[i] = missing
    end
end
df.Distance .= passmissing(parse).(Float64, df.Distance)

# unique(df.Landsize) #missing as missing => -1
# df.Landsize .= coalesce.(df.Landsize, -1)

# unique(df.BuildingArea) #missing as missing => -1
# df.BuildingArea .= coalesce.(df.BuildingArea, -1)


# unique(df.YearBuilt) #missing as missing => -1
df.YearBuilt .= coalesce.(df.YearBuilt, -1)

# unique(df.Lattitude) #missing as missing => ?
# unique(typeof.(df.Longtitude)) #missing as missing => ?
df.Lattitude .= coalesce.(df.Lattitude, 0.0)
df.Longtitude .= coalesce.(df.Longtitude, 0.0)


# unique(df.Bedroom2) #missing as missing => keep as
# unique(df.Bathroom) #missing as missing => keep as
# unique(df.Car) #missing as missing => keep as

allowmissing!(df, :CouncilArea)
allowmissing!(df,:Postcode)
allowmissing!(df,:Regionname)
allowmissing!(df, :Propertycount)


# unique(df.CouncilArea) #missing as #N/A => changing based on suburb/address or down as missing
function findarea(suburb::String31)
    for (i,n) in enumerate(df.Suburb)
        if n == suburb && df.CouncilArea[i] != "#N/A"
            return df.CouncilArea[i]
        end
    end
    return missing
end


for (i,n) in enumerate(df.CouncilArea)
    if n == "#N/A" && !(df.Suburb[i] isa Nothing)
        df.CouncilArea[i] = findarea(df.Suburb[i])
    end
end


# unique(df.Postcode) #missing as #N/A => changing based on suburb/address
function findcode(suburb::String31)
    for (i,n) in enumerate(df.Suburb)
        if n == suburb && df.Postcode[i] != "#N/A"
            return df.Postcode[i]
        end
    end
    return missing
end

for (i,n) in enumerate(df.Postcode)
    if n == "#N/A"
        df.Postcode[i] = findcode(df.Suburb[i])
    end
end

# unique(df.Regionname) #missing as #N/A => changing based on suburb/address
function findregion(suburb::String31)
    for (i,n) in enumerate(df.Suburb)
        if n == "suburb" && df.Regionname[i] != "#N/A"
            return df.Regionname[i]
        end
    end
    return missing
end
for (i,n) in enumerate(df.Regionname)
    if n == "#N/A"
        df.Regionname[i] = findregion(df.Suburb[i])
    end
end

# unique(df.Propertycount) #missing as #N/A => changing based on suburb/address
function findcount(suburb::String31)
    for (i,n) in enumerate(df.Suburb)
        if n == "suburb" && df.Propertycount[i] != "#N/A"
            return df.Propertycount[i]
        end
    end
    return missing
end

for (i,n) in enumerate(df.Propertycount)
    if n == "#N/A"
        df.Propertycount[i] = findcount(df.Suburb[i])
    end
end

df.Propertycount = passmissing(parse).(Int64, df.Propertycount)
df.Postcode .= passmissing(parse).(Int64, df.Postcode)

# turns Date string into a form that can be turned into a Date type
function parsedate(date)
    result = ""
    for n in date
        if n == '/'
            result *= "-"
        else
            result *= n
        end
    end
    return result
end

#Creates the Date column to be a Date type
insertcols!(df, :newDate => Date("0001-01-01"))
for (i,n) in enumerate(df.Date)
    date = String(parsedate(n))
    df.newDate[i] = Date(date, "d-m-y")
end
df = select!(df, Not(:Date))
rename!(df, :newDate => :Date)

insertcols!(df, :newmeth => "")
for (i,n) in enumerate(df.Method)
    method = String(n)
    df.newmeth[i] = method
end
df = select!(df, Not(:Method))
rename!(df, :newmeth => :Method)


println("Missing values & data types changed")

#########################################################
#########################################################
############# Task 1 ####################################
#########################################################
#########################################################
using SplitApplyCombine


typeof(df.Rooms)
typeof(df.Price)
typeof(df.Method)
typeof(df.Distance)
typeof(df.Landsize)

#Find distributions of each variable
#skip missing data in these plots as then averages medians can be found from the plots
#Price
histogram(skipmissing(df.Price))
density(skipmissing(df.Price), lw=5, norm=true)

#Rooms
grdf = groupcount(df.Rooms)
bar(collect(keys(grdf)), collect(values((grdf))))

#Method
gmdf = groupcount(df.Method)
bar(collect(keys(gmdf)), collect(values((gmdf))))

#Distance 
histogram(skipmissing(df.Distance))
density!(skipmissing(df.Distance), lw=5, norm=true)

#Landsize
histogram(skipmissing(df.Landsize))
density!(skipmissing(df.Landsize), lw=5, norm=true)

for (i,n) in enumerate(df.Landsize)
if typeof(n) != Missing && n > (9*10^4)
    # @show n
end
end


#########################################################
#########################################################
############# Task 2 ####################################
#########################################################
#########################################################

#skip missing for price, distance, building area

#Price vs Distance
#price vs house size
# - land
# - room
# - car
# - Bathroom
# - building area

#combine distance, area, land - each are normally distributed contiuous data so ANOVa will work
#sum of rooms


# prices = Vector{}(zeros(length(distances)))
prices_vec = Vector{Vector{Number}}(undef, 6)
prices_count = Vector{Vector{Number}}(undef, 6)
unique_vec = []

price = coalesce.(df.Price, -1)

distances = sort(unique(df.Distance))
pop!(distances)
push!(unique_vec, distances)

# dis_counts = zeros(length(distances))

land = sort(unique(df.Landsize))
pop!(land)
push!(unique_vec, land)
# land_counts = zeros(length(land))

room = sort(unique(df.Rooms))
push!(unique_vec, room)
# room_counts = zeros(length(room))

car = sort(unique(df.Car))
pop!(car)
push!(unique_vec, car)
# car_counts = zeros(length(car))

bath = sort(unique(df.Bathroom))
pop!(bath)
push!(unique_vec, bath)
# bath_counts = zeros(length(bath))

area = sort(unique(df.BuildingArea))
pop!(area)
push!(unique_vec, area)
# area_counts = zeros(length(area))

data = select(df, [:Distance, :Landsize, :Rooms, :Car, :Bathroom, :BuildingArea, :Price])
data = coalesce.(data, -1)

global col_count = 0
for data_type in unique_vec
    global col_count += 1
    price_count = 0
    prices_vec[col_count] = zeros(length(data_type))
    prices_count[col_count] = zeros(length(data_type))
    for val in data_type
        price_count += 1
        for (index, data_point) in enumerate(data[:, col_count])
            if val == data_point && data.Price[index] != -1
                prices_vec[col_count][price_count] += price[index]
                prices_count[col_count][price_count] += 1
            end
        end
    end
end

scatter(unique_vec[1], (prices_vec[1]./prices_count[1]))

bar(unique_vec[3], (prices_vec[3]./prices_count[3]))
bar(unique_vec[4], (prices_vec[4]./prices_count[4]))
bar(unique_vec[5], (prices_vec[5]./prices_count[5]))

scatter(unique_vec[2], (prices_vec[2]./prices_count[2]))
scatter(unique_vec[6], (prices_vec[6]./prices_count[6]))

# println("basic done")
# heat_land = unique(floor.((skipmissing((unique_vec[2])))))
# heat_build = unique(floor.((skipmissing((unique_vec[6])))))

# prices_mat = zeros(length(heat_land), length(heat_build))
# price_count_mat = zeros(length(heat_land), length(heat_build))

# function getposition(land::Int64, build::Float64)
#     land = floor(land)
#     l_index = 0
#     build = floor(build)
#     b_index = 0
#     for (index, val) in enumerate(heat_land)
#         if land == val
#             l_index = index
#         end
#     end
#     for (index, val) in enumerate(heat_build)
#         if build == val
#             b_index = index
#         end
#     end
#     return [l_index, b_index]
# end

# not_neg = 0
# for (index, pric) in enumerate(data.Price)
#     if pric != -1 && data.Landsize[index] != -1 && data.BuildingArea[index] != -1
#         not_neg += 1
#         position = getposition(data.Landsize[index], data.BuildingArea[index])
#         prices_mat[position[1], position[2]] += pric
#         price_count_mat[position[1], position[2]] += 1
#     end
#     if mod(index, 1000) == 0
#         println(".")
#     end
# end

# # for (l_index,land) in enumerate(heat_land)
# #     for (b_index,build) in enumerate(heat_build)
# #         for pric in data.Price
# #             if data.Landsize[l_index] != land && data.BuildingArea[b_index] != build && pric != -1
# #                 prices_mat[l_index, b_index] += pric
# #                 price_count_mat[l_index, b_index] += 1
# #             end
# #         end
# #     end
# # end
# prices_mat
# heat_price = prices_mat ./ price_count_mat

# heatmap(heat_price)