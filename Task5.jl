using Pkg
Pkg.activate(".")
using CSV, DataFrames, HTTP, CSV, StatsBase, Dates
path = "./data/Melbourne_housing_FULL.csv"
old_df = CSV.read(path, DataFrame)

df = copy(old_df)

allowmissing!(df, :Distance)
for (i,n) in enumerate(df.Distance)
    if n == "#N/A"
        df.Distance[i] = missing
    end
end
df.Distance .= passmissing(parse).(Float64, df.Distance)

count = 0
for (index, val) in enumerate(skipmissing(df.Landsize))
    if val == 0 && (df.Type == "h" || df.Type == "t" || df.Type == "o res")
        count += 1
    end
end

df.YearBuilt .= coalesce.(df.YearBuilt, -1)

# df.Lattitude .= coalesce.(df.Lattitude, 0.0)
# df.Longtitude .= coalesce.(df.Longtitude, 0.0)


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


####################################################################################################################
#Get data to use
data = transform(df, :Date => x -> yearmonth.(x))
data = transform(data, :Date_function => ByRow(x -> "$(x[1])"*", "*"$(x[2])") => :Date)
data_grouped = groupby(sort!(data, :Date_function), [:Date_function, :Postcode])

#CBD location supplied here: https://mapcarta.com/Melbourne/CBD#:~:text=Longitude%20144.963%C2%B0%20or,144%C2%B0%2057%27%2047%22%20east
#Lat =  -37.8136, Long = 144.963

#Find location for each Postcode
locations = []
post_loc = groupby(data, :Postcode)
post_loc = combine(post_loc, :Longtitude => mean ∘ skipmissing => :Longitude_mean, :Lattitude => mean ∘ skipmissing => :Latitude_mean)
transform!(post_loc, [:Longitude_mean, :Latitude_mean] => ByRow((x,y) -> (x, y)) => :Location)
sort!(post_loc, [:Longitude_mean, :Latitude_mean])
pop!(post_loc) # remove missing postcode row
pop!(post_loc) # remove row with non recorded latitude and longitude of postcode 3788


#Get domain and range of plot
# maximum(skipmissing(old_df.Longtitude)) # - 145° 31' 34.86"
# minimum(skipmissing(old_df.Longtitude)) #- 144° 25' 25.64"

# maximum(skipmissing(old_df.Lattitude)) # - -37° 23' 24.72"
# minimum(skipmissing(old_df.Lattitude)) # - -38° 11' 25.55"

#initialise plot
using CairoMakie, FileIO

sales_data = combine(data_grouped, nrow => :Count, 
:Price => mean ∘ skipmissing => :Price_mean,
:Longtitude => mean ∘ skipmissing => :Longitude_mean, 
:Lattitude => mean ∘ skipmissing => :Latitude_mean)

function next_markers(index::Int64)
    return groupby(sales_data, :Date_function)[index]
end

function getsizes(data)::Vector{Float64}
    result = zeros(210)
    # @show length(unique(data.Count))
    vals = sort!(unique(data.Count))
    sizes = 2:(20 - 2)/length(unique(data.Count)):20
    # transform!(data, :Count => ByRow(x -> round((x + 2.5)/5) * 5))
    for (i, code) in enumerate(skipmissing(data.Postcode))
        for (index, post) in enumerate(post_loc.Postcode)
            if code == post
                for (size, val) in enumerate(vals)
                    if val == data.Count[i]
                        result[index] = sizes[size]
                    end
                end
            end
        end
    end
    return result
end

frames = 1:length(unique(price_data.Date_function))
frame_rate = 1

mark_size = Observable(zeros(210))
date_o = Observable("string")

fig = Figure(); display(fig)
img = load("Images/Melbourne_nogrid.png")
land = Axis(fig[1,1], title = date_o, xlabel = "longitude", ylabel="latitude", limits = (144.4, 145.5, -38.2, -37.39))
image!(land,(144.4, 145.5), (-38.2, -37.39), rotr90(img), alpha=0.5)
scatter!(144.963,-37.8136, marker = :star4, color=:red)
Colorbar(fig[1,2], colormap = :thermal, highclip=:cyan , lowclip=:red)
scatter!(land, post_loc.Longitude_mean, post_loc.Latitude_mean, markersize = mark_size)

locations_by_post = post_loc.Postcode
function animstep!(mark_size, index::Int64)
    new_data = next_markers(index)
    mark_size[] = getsizes(new_data)
    date_o[] = "Number of properties sold. Date: " * unique(data.Date)[index]
end

# index = 25
# for i in 1:1
#     index += 1
#     @show index
#     animstep!(mark_size, index)
#     display(fig)
#     sleep(0.001)
    
# end

if true
index = 0
count = 0
frames = 1:250
record(fig, "task5.mp4", frames; frame_rate = 1) do i
    global count += 1
    if mod(count, 10) == 0
        global index += 1
        # @show index
        animstep!(mark_size, index)
        sleep(0.01)
    end
end
end

# range(HSV(0,1,1), stop=HSV(-90,1,1))