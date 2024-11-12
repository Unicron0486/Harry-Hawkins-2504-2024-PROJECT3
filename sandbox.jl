using Pkg
Pkg.activate(".")
using CSV, DataFrames, HTTP, CSV, Plots, StatsPlots, StatsBase, Dates
path = "./data/Melbourne_housing_FULL.csv"
old_df = CSV.read(path, DataFrame)

df = copy(old_df)
# unique(df.Suburb) #No missing
# unique(df.Address) #No missing
# unique(df.Rooms) #No missing
# unique(df.Type) #No missing
# unique(df.Method) #No missing
# unique(df.SellerG) #No missing
# unique(df.Date) #No missing

# unique(df.Price) #missing as missing => will need to skip or avg

# unique(df.Distance) #missin as #N/A
allowmissing!(df, :Distance)
for (i,n) in enumerate(df.Distance)
    if n == "#N/A"
        df.Distance[i] = missing
    end
end
df.Distance .= passmissing(parse).(Float64, df.Distance)

# unique(df.Landsize) #missing as missing there is also a zero values (for units?)
count = 0
for (index, val) in enumerate(skipmissing(df.Landsize))
    if val == 0 && (df.Type == "h" || df.Type == "t" || df.Type == "o res")
        count += 1
    end
end
println(count)
#Hence the only times the landsize is zero is for units


# unique(df.BuildingArea) #missing as missing => -1

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

typeof(df.Rooms) # Int64
typeof(df.Price) # Int64
typeof(df.Method) #String
typeof(df.Distance) # Float64
typeof(df.Landsize) # Int64

#Find distributions of each variable
#skip missing data in these plots as then averages medians can be found from the plots

histogram(skipmissing(df.Price)./10^5, normalize=:pdf,
title = "Pdf of price",
xlabel = "Price (x100,000)",
ylabel = "Normalised frequency",
label = "Normalised frequency of prices",
foreground_color=:grey
)
density!(skipmissing(df.Price)./10^5, lw=5, label = "Probability Density")

#Rooms
grdf = groupcount(df.Rooms)
#From observing the DataFrame the number of rooms 7,8,9,10,12,16 are so small they do not appear on the plot. they correspond to counts of 32,19,4,6,3,1 respectivly.
bar(collect(keys(grdf)), collect(values((grdf))),
title = "Number of bedrooms",
xlabel = "Number of bedrooms",
ylabel = "Count",
legend = false,
xticks = 0:1:15)

#Method
gmdf = groupcount(df.Method)
#SS has count 36
bar(collect(keys(gmdf)), collect(values((gmdf))),
title = "Number of each building type",
xlabel = "Building type",
ylabel = "Count",
legend = false)

gmdf["SN"]

#Distance 
histogram(skipmissing(df.Distance),normalize=:pdf,
title = "Pdf of distance from city",
xlabel = "Distance from city (km)",
ylabel = "Normalised frequency",
label = "Normalised frequency of\n distance from city")
density!(skipmissing(df.Distance), lw=5, norm=true, label="Probability density")

#Landsize
data = select(df, [:Landsize, :Type])

histogram(skipmissing(data.Landsize), normalize=:pdf, xlims=[-10, 3*10^3],
title = "Pdf of landsize",
xlabel = "Landsize (m²)",
ylabel = "Normalised frequency",
label = "Normalised frequency of landsize")
density!(skipmissing(data.Landsize), lw=5, norm = true, label="Probability density")

#Landsize without units
data = transform(data, :Type => x -> (x != "u"), :Landsize => y -> coalesce.(y,-1))
data[!, :Landsize_function] = convert.(Int64, data[!, :Landsize_function])
landsizes = data.Landsize_function[data.Type_function .== true .&& data.Landsize_function .> 0 .&& data.Landsize_function .< 3000]

histogram(landsizes, normalize=:pdf,
title = "Pdf of landsize without 'unit' property types\n and limited to 3000m²",
xlabel = "Landsize (m²)",
ylabel = "Normalised frequency",
label = "Normalised frequency of Landsize")
density!(landsizes, lw=5, norm = true, xlims=[-10, 3*10^3], label="Probability density")



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

# data = select(df, [:Distance, :Landsize, :Rooms, :Car, :Bathroom, :BuildingArea, :Price, :Bedroom2])
# sort!(data)
# data = coalesce.(data, -1)
# disallowmissing!(data)

#prices = Vector{}(zeros(length(distances)))
prices_vec = Vector{Vector{Number}}(undef, 6)
prices_count = Vector{Vector{Number}}(undef, 6)
unique_vec = []

price = coalesce.(df.Price, -1)

distances = sort(unique(df.Distance))
pop!(distances)
push!(unique_vec, disallowmissing(distances))

# dis_counts = zeros(length(distances))

land = sort(unique(df.Landsize))
pop!(land)
push!(unique_vec, disallowmissing(land))
# land_counts = zeros(length(land))

room = sort(unique(df.Rooms))
push!(unique_vec, disallowmissing(room))
# room_counts = zeros(length(room))

car = sort(unique(df.Car))
pop!(car)
push!(unique_vec, disallowmissing(car))
# car_counts = zeros(length(car))

bath = sort(unique(df.Bathroom))
pop!(bath)
push!(unique_vec, disallowmissing(bath))
# bath_counts = zeros(length(bath))

area = sort(unique(df.BuildingArea))
pop!(area)
push!(unique_vec, disallowmissing(area))
# area_counts = zeros(length(area))

data = select(df, [:Distance, :Landsize, :Rooms, :Car, :Bathroom, :BuildingArea, :Price, :Bedroom2])
sort!(data)
data = coalesce.(data, -1)
disallowmissing!(data)

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

#price vs Distance
data = select(df, [:Price, :Distance])
data = groupby(data, :Distance)
data = combine(data, :Price => mean ∘ skipmissing => :Price)
scatter(data.Distance, data.Price./10^5,
title = "Average price for each distance",
xlabel = "Distance (km)",
ylabel = "Average price (x100,000)",
legend = false)

#room
data = select(df, [:Price, :Rooms])
data = groupby(data, :Rooms)
data = combine(data, :Price => mean ∘ skipmissing => :Price)
plot(data.Rooms, data.Price./10^5,
title = "Average price according to number of bedrooms",
xlabel = "Number of bedrooms",
ylabel = "Average price (x100,000)")

#car
data = select(df, [:Price, :Rooms])
data = groupby(data, :Rooms)
data = combine(data, :Price => mean ∘ skipmissing => :Price)
bar(data.Rooms, data.Price./10^5,
title = "Average price according to number of car parks",
xlabel = "Number of car parks",
ylabel = "Average price (x100,000)",
xticks = 0:1:20)

#bathroom
data = select(df, [:Price, :Bathroom])
data = groupby(data, :Bathroom)
data = combine(data, :Price => mean ∘ skipmissing => :Price)
bar(data.Bathroom, data.Price./10^5,
title = "Average price according to number of bathrooms",
xlabel = "Number of Bathrooms",
ylabel = "Average price (x100,000)",
xticks = 0:1:12)

#landsize
data = select(df, [:Price, :Landsize])
data = groupby(data, :Landsize)
data = combine(data, :Price => mean ∘ skipmissing => :Price)
scatter(data.Landsize, data.Price./10^5,
title = "Average price for each landsize",
xlabel = "Landsize (m²)",
ylabel = "Average price (x100,000)")

# zoom_data = filter((x) -> x.< 3000, unique_vec[2])
data = select(df, [:Price, :Landsize])
data = subset(data, :Landsize => ByRow(<=(3000)); skipmissing=true)
data = groupby(data, :Landsize)
data = combine(data, :Price => mean ∘ skipmissing => :Price, :Landsize => x -> x .< 3000)
scatter(data.Landsize, data.Price./10^5,
title = "Average price for each Landsize (zoomed)",
xlabel = "Landsize (m²)",
ylabel = "Average price (x100,000)")

#building size
data = select(df, [:Price, :BuildingArea])
data = groupby(data, :BuildingArea)
data = combine(data, :Price => mean ∘ skipmissing => :Price)
scatter(data.BuildingArea, data.Price./10^5,
title = "Average price for each building area",
xlabel = "Building area (m²)",
ylabel = "Average price (x100,000)")


data = select(df, [:Price, :BuildingArea])
data = subset(data, :BuildingArea => ByRow(<=(1000)); skipmissing=true)
data = groupby(data, :BuildingArea)
data = combine(data, :Price => mean ∘ skipmissing => :Price)
scatter(data.BuildingArea, data.Price./10^5,
title = "Average price for each building area (zoomed)",
xlabel = "Building area (m²)",
ylabel = "Average price (x100,000)",
xlims = 0:3*10^3)
#

sum_rooms = []
using BenchmarkTools
for (i,n) in enumerate(price)
    room_count = (data.Rooms[i] != -1 ? data.Bedroom2[i] : data.Rooms[i])
    if n != -1 && room_count != -1 && data.Bathroom[i] != -1 && data.Car[i] != -1
        rooms = room_count + data.Bathroom[i] + data.Car[i]
        append!(sum_rooms, rooms)
    end
end

sum_rooms_prices = zeros(length(unique(sum_rooms)))
count_vec = zeros(length(unique(sum_rooms)))

for (j, val) in enumerate(unique(sum_rooms))
    for (i, n) in enumerate(price)
        room_count = (data.Rooms[i] != -1 ? data.Bedroom2[i] : data.Rooms[i])
        if (n != -1 && room_count != -1 && data.Bathroom[i] != -1 && data.Car[i] != -1) && val == room_count + data.Bathroom[i] + data.Car[i]
            sum_rooms_prices[j] += n
            count_vec[j] += 1
        end
    end
end


groupcount(sum_rooms)
scatter(unique(sum_rooms), (sum_rooms_prices ./ count_vec)./10^5,
title = "Average price for the sum of rooms",
xlabel = "Total number of rooms (Car, Bedroom, Bathroom)",
ylabel = "Average price (x100,000)")
#


#land, build
data = select(df, [:Price, :BuildingArea, :Landsize])
data = coalesce.(data, -1)
disallowmissing!(data)

heat_land = collect(data.Landsize)
for (i, n) in enumerate(heat_land)
    if n == -1
        continue
    else
        heat_land[i] = round((n + 50) / 100) * 100
    end
end


heat_build = collect(skipmissing(data.BuildingArea))
for (i, n) in enumerate(heat_build)
    if n == -1
        continue
    else
        heat_build[i] = round((n + 25) / 50) * 50
    end
end

heat_land = sort(unique(heat_land))
heat_build = sort(unique(heat_build))

heat_price = zeros(length(heat_land), length(heat_build))
prices_mat = zeros(length(heat_land), length(heat_build))
price_count_mat = 2 .* ones(length(heat_land), length(heat_build))

function getposition(land::Int64, build::Float64)
    land = round((land + 50) / 100) * 100
    l_index = 0
    build = round((build + 25) / 50) * 50
    b_index = 0
    for (index, val) in enumerate(heat_land)
        if land == val
            l_index = index
        end
    end
    for (index, val) in enumerate(heat_build)
        if build == val
            b_index = index
        end
    end
    return [l_index, b_index]
end

# not_neg = 0
for (index, pric) in enumerate(data.Price)
    if pric != -1 && data.Landsize[index] != -1 && data.BuildingArea[index] != -1
        # not_neg += 1
        position = getposition(data.Landsize[index], data.BuildingArea[index])
        if data.Landsize[index] <= 0 ||  data.BuildingArea[index] <= 0
            continue
        else
            prices_mat[position[1], position[2]] += pric
            price_count_mat[position[1], position[2]] += 1
        end
    end
    if mod(index, 1000) == 0
        println(".")
    end
end

heat_price = (prices_mat ./ (price_count_mat .- 1)) ./ 10^5
heat_price = Int64.(round.(heat_price))
heatmap(heat_price,
title = "Average price of properties by build area and landsize",
xlabel = "Building area (m²)",
ylabel = "Landsize (m²)",
xticks = (2:2:5, heat_build[2:end]))
#



#land, distance
heat_land = collect(skipmissing(unique_vec[2]))
for (i, n) in enumerate(heat_land)
    heat_land[i] = round((n + 50) / 100) * 100
end

heat_dis = collect(skipmissing(unique_vec[1]))
# for (i, n) in enumerate(heat_dis)
#     heat_dis[i] = round((n + 25) / 50) * 50
# end

heat_land = unique(heat_land)
heat_dis = unique(heat_dis)

heat_price = zeros(length(heat_land), length(heat_dis))
prices_mat = zeros(length(heat_land), length(heat_dis))
price_count_mat = 2 .* ones(length(heat_land), length(heat_dis))

function getposition(land::Int64, distance::Float64)
    land = round((land + 50) / 100) * 100
    l_index = 0
    # distance = round((distance + 50) / 100) * 100
    d_index = 0
    for (index, val) in enumerate(heat_land)
        if land == val
            l_index = index
        end
    end
    for (index, val) in enumerate(heat_dis)
        if distance == val
            d_index = index
        end
    end
    return [l_index, d_index]
end

# not_neg = 0
for (index, pric) in enumerate(data.Price)
    if pric != -1 && data.Landsize[index] != -1 && data.Distance[index] != -1
        # not_neg += 1
        position = getposition(data.Landsize[index], data.Distance[index])
        prices_mat[position[1], position[2]] += pric
        price_count_mat[position[1], position[2]] += 1
    end
    if mod(index, 1000) == 0
        println(".")
    end
end

prices_mat

heat_price = (prices_mat ./ (price_count_mat .- 1)) ./ 10^5

heatmap(heat_price,
title = "Average price of properties by landsize and distance from city",
xlabel = "Distance from city (km)",
ylabel = "Landsize (m²)")
heatmap(heat_price[1:30, :],
title = "Average price of properties by landsize and distance from city",
xlabel = "Distance from city (km)",
ylabel = "Landsize (m²)")
#

#build, distance
heat_distance = collect(skipmissing(unique_vec[1]))

heat_build = collect(skipmissing(unique_vec[6]))
for (i, n) in enumerate(heat_build)
    heat_build[i] = round((n + 25) / 50) * 50
end

heat_distance = unique(heat_distance)
heat_build = unique(heat_build)

heat_price = zeros(length(heat_build), length(heat_distance))
prices_mat = zeros(length(heat_build), length(heat_distance))
price_count_mat = 2 .* ones(length(heat_build), length(heat_distance))

function getposition(build::Float64, distance::Float64)
    d_index = 0
    build = round((build + 25) / 50) * 50
    b_index = 0
    for (index, val) in enumerate(heat_distance)
        if distance == val
            d_index = index
        end
    end
    for (index, val) in enumerate(heat_build)
        if build == val
            b_index = index
        end
    end
    return [b_index, d_index]
end

# not_neg = 0
for (index, pric) in enumerate(data.Price)
    if pric != -1 && data.Distance[index] != -1 && data.BuildingArea[index] != -1
        # not_neg += 1
        position = getposition(data.BuildingArea[index], data.Distance[index])
        prices_mat[position[1], position[2]] += pric
        price_count_mat[position[1], position[2]] += 1
    end
    if mod(index, 1000) == 0
        println(".")
    end
end

heat_price = (prices_mat ./ (price_count_mat .- 1)) ./ 10^5

heatmap(heat_price,
title = "Average price of properties by Build area and distance from city",
xlabel = "Distance from city (km)",
ylabel = "Building area (m²)")

heatmap(heat_price[1:15, :],
title = "Average price of properties by Build area and distance from city",
xlabel = "Distance from city (km)",
ylabel = "Building area (m²)")
#




#########################################################
#########################################################
############# Task 3 ####################################
#########################################################
#########################################################
volume_data = select(df, [:Date, :Price, :Type])

equal_times(date1::Date, date2::Date) = Dates.yearmonth(date1) == Dates.yearmonth(date2)

transform!(volume_data, :Date => x -> yearmonth.(x))

volume_data = groupby(volume_data, :Date_function)

#num of sales
data = combine(volume_data, nrow => :count)
sort!(data)
data = transform(data, :Date_function => ByRow(x -> "$(x[1])"*", "*"$(x[2])") => :Date)

bar(data.Date, data.count, 
xticks=(0.5:24.5, data.Date),
xrotation = 45,
bar_width = 0.6,
widen = true,
legend = false,
title = "Number of properties sold per month",
xlabel = "Date (year, month)",
ylabel = "Count")
# size=(1000, 500))
#

#price of sales
# passmissing(select(df, [:Date, :Price]))
data = combine(volume_data, :Price => mean ∘ skipmissing => :Price)
sort!(data)
data = transform(data, :Date_function => ByRow(x -> "$(x[1])"*", "*"$(x[2])") => :Date)
plot(data.Date, data.Price./10^5, ylims = [0,12],
xticks=(0.5:24.5, data.Date),
xrotation = 45,
bar_width = 0.6,
widen = true,
legend = false,
title = "Average price of properties sold per month",
xlabel = "Date (year, month)",
ylabel = "Average price (x100,000)")

#type count
volume_data = select(df, [:Date, :Type])
transform!(volume_data, :Date => x -> yearmonth.(x))

volume_data = groupby(volume_data, [:Date_function, :Type])

# for each year, count groups plot the se for each year
data = combine(volume_data, nrow => :count)
# sort!(data, :Date_function)
data = transform(data, :Date_function => ByRow(x -> "$(x[1])"*", "*"$(x[2])") => :Date)

sort!(data, [:Date_function, :Type])
prop_data = groupby(data, :Date)

proportions = []
for i in 1:length(prop_data)
    frame = prop_data[i]
    append!(proportions, frame.count[1] / sum(frame.count))
end



p1 = plot(data.Date, data.count, group = data.Type, ylims = [0, 2300],
xticks=(0.5:24.5, unique(data.Date)),
xrotation = 45,
bar_width = 0.6,
widen = true,
legend = false,
title = "Number of Types of properties sold per month",
xlabel = "Date (year, month)",
ylabel = "Count")

p2 = plot(unique(data.Date), proportions,
xticks=(0.5:24.5, unique(data.Date)),
xrotation = 45,
bar_width = 0.6,
widen = true,
legend = false,
title = "Proportion of houses sold per month",
xlabel = "Date (year, month)",
ylabel = "Proportion")

plot(p1, p2, layout=grid(1,2), size = (1100,500))



#########################################################
#########################################################
############# Task 4 ####################################
#########################################################
#########################################################
# df_train = df[1:(Int64(round(length(df.Price)/2))),:]
using Random, GLM

n, _ = size(df)
Random.seed!(0)
p_validate = 0.3
n_validate = floor(Int, p_validate*n)
validate_index_set = sample(1:n, n_validate, replace = false)
train_index_set = setdiff(1:n, validate_index_set);
n_validate = length(validate_index_set)
n_train = length(train_index_set)
n_train, n_validate
df_train = df[train_index_set,:]
df_validate = df[validate_index_set,:];

mse(y,ŷ) = sqrt(sum(skipmissing(y-ŷ).^2))

model1 = glm(@formula(log(Price) ~ Distance), df_train, Normal(), IdentityLink())
mse_1 = mse(predict(model1, df_validate), log.(df_validate.Price))
# min_x = minimum(1 ./ (df_validate.Price))
# max_x = maximum(1 ./ (df_validate.Price))
# scatter(predict(model1, df_validate), (df_validate.Price), 
# label = "model1", ms=3, msw=0, 
# xlims = (minimum(skipmissing((df_validate.Price))), maximum(skipmissing((df_validate.Price)))), 
# aspect_ratio = :equal)


model2 = glm(@formula(log(Price) ~ Rooms), df_train, Normal(), IdentityLink())
mse_2 = mse(predict(model2, df_validate), log.(df_validate.Price))
# scatter(predict(model2, df_validate),df_validate.Price, ms=3, msw=0)


# using CategoricalArrays
# car_data = collect(df_train.Car)
# ddf_train = DataFrame(Price = df_train.Price, Car = categorical(car_data))
# ddf_validate = DataFrame(Price = df_validate.Price, Car = categorical(collect(df_validate.Car)))

model3 = glm(@formula(log(Price) ~ Car), df_train, Normal(), IdentityLink()) #log one
mse_3 = mse(predict(model3, df_validate), log.(df_validate.Price))
# scatter(predict(model3, df_validate),df_validate.Price, ms=3, msw=0)

model4 = glm(@formula(log(Price) ~ Bathroom), df_train, Normal(), IdentityLink()) #log one
mse_4 = mse(predict(model4, df_validate), log.(df_validate.Price))
# scatter(predict(model4, df_validate),df_validate.Price, ms=3, msw=0)

model5 = glm(@formula(log(Price) ~ Landsize), df_train, Normal(), IdentityLink())
mse_5 = mse(predict(model5, df_validate), log.(df_validate.Price))
# scatter(predict(model5, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)

model6 = glm(@formula(log(Price) ~ BuildingArea), df_train, Normal(), IdentityLink())
mse_6 = mse(predict(model6, df_validate), log.(df_validate.Price))
# scatter(predict(model6, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)

#dis, land
model7 = glm(@formula(log(Price) ~ Distance + Landsize), df_train, Normal(), IdentityLink())
mse_7 = mse(predict(model7, df_validate), log.(df_validate.Price))
# scatter(predict(model6, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)

#dis, area
model8 = glm(@formula(log(Price) ~ Distance + BuildingArea), df_train, Normal(), IdentityLink())
mse_8 = mse(predict(model8, df_validate), log.(df_validate.Price))
# scatter(predict(model6, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)

#land area
model9 = glm(@formula(log(Price) ~ Landsize + BuildingArea), df_train, Normal(), IdentityLink())
mse_9 = mse(predict(model9, df_validate), log.(df_validate.Price))
# scatter(predict(model6, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)

#sum rooms
model10 = glm(@formula(log(Price) ~ Car + Rooms + Bathroom), df_train, Normal(), IdentityLink())
mse_10 = mse(predict(model10, df_validate), log.(df_validate.Price))
# scatter(predict(model6, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)


#dis, area, land
model11 = glm(@formula(log(Price) ~ Distance + Landsize + BuildingArea), df_train, Normal(), IdentityLink())
mse_11 = mse(predict(model11, df_validate), log.(df_validate.Price))
# scatter(predict(model6, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)


#best dis + sum or indi rooms
model12 = glm(@formula(log(Price) ~ BuildingArea / (Car + Rooms + Bathroom)), df_train, Normal(), IdentityLink())
mse_12 = mse(predict(model12, df_validate), log.(df_validate.Price))
# scatter(predict(model6, df_validate),df_validate.Price, label = "model1", ms=3, msw=0)



model13 = glm(@formula(log(Price) ~ (BuildingArea + Landsize)/ (Car + Rooms + Bathroom)), df_train, Normal(), IdentityLink())
mse_13 = mse(predict(model13, df_validate), log.(df_validate.Price))

model14 = glm(@formula(log(Price) ~ Distance  + (BuildingArea / (Car + Rooms + Bathroom))), df_train, Normal(), IdentityLink())
mse_14 = mse(predict(model14, df_validate), log.(df_validate.Price))

model15 = glm(@formula(log(Price) ~ BuildingArea + Car + Rooms + Bathroom), df_train, Normal(), IdentityLink())
mse_15 = mse(predict(model15, df_validate), log.(df_validate.Price))

model16 = glm(@formula(log(Price) ~ Distance  + (BuildingArea + Car + Rooms + Bathroom)), df_train, Normal(), IdentityLink())
mse_16 = mse(predict(model16, df_validate), log.(df_validate.Price))

model17 = glm(@formula(log(Price) ~ Landsize + Distance  + BuildingArea + Car + Rooms + Bathroom), df_train, Normal(), IdentityLink())
mse_17 = mse(predict(model17, df_validate), log.(df_validate.Price))

model18 = glm(@formula(log(Price) ~ Landsize + Distance + BuildingArea^2 + (sqrt(Car) + sqrt(Rooms) + sqrt(Bathroom))), df_train, Normal(), IdentityLink())
mse_18 = mse(predict(model18, df_validate), log.(df_validate.Price))


models = [model1, model2, model3, model4, model5, model6, model7, model8, model9, model10, model11, model12, model13, model14, model15, model16, model17, model18]
mses = [mse_1, mse_2, mse_3, mse_4, mse_5, mse_6, mse_7, mse_8, mse_9, mse_10, mse_11, mse_12, mse_13, mse_14, mse_15, mse_16, mse_17, mse_18]
p_vals = [coeftable(model).cols[4] for model in models]
model_nums = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18"]
accuracy = DataFrame(Model = model_nums, P = p_vals, MSE = mses)

sort!(accuracy, :MSE)

@show accuracy

transform!(accuracy, :MSE => ByRow(x -> sqrt(x)) => :RMSE)
transform!(accuracy, :RMSE => ByRow(x -> x/(maximum(skipmissing(log.(df_validate.Price))) - minimum(skipmissing(log.(df_validate.Price))))) => :Norm_RMSE)
transform!(accuracy, :MSE => ByRow(x -> x/(maximum(skipmissing(log.(df_validate.Price))) - minimum(skipmissing(log.(df_validate.Price))))) => :Norm_MSE)

scatter(predict(model18, df_validate), log.(df_validate.Price), xlims = [10,20], ylims = [10,20], aspect_ratio = :equal)
plot!([10,20], [10,20])