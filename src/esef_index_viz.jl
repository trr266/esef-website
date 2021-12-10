using AlgebraOfGraphics
using CairoMakie
using Chain
using Colors
using CSV
using DataFrameMacros
using DataFrames
using Dates
using HTTP
using JSON
using Statistics
using URIParser
using VegaDatasets
using VegaLite

# Import helper functions
include("wikidata_public_companies.jl")
include("esef_xbrl_filings.jl")

trr_266_colors = ["#1b8a8f", "#ffb43b", "#6ecae2", "#944664"] # petrol, yellow, blue, red

df_wikidata_lei = get_public_companies_wikidata()

# Check only minimal number of firms where country is missing (e.g. EU, CS (old ISO), ersatz XC/XY/XS, or incorrect 00, 23)
# TODO: Clean this up further
@assert((@chain df_wikidata_lei @subset(ismissing(:esef_regulated)) nrow()) < 30) # @select(:isin_alpha_2)

@chain df_wikidata_lei @subset(ismissing(:esef_regulated) & !ismissing(:country)) @transform(:esef_reg_1 = esef_regulated(:isin_region, :region)) @select(:esef_reg_1, :country, :country_alpha_2, :isin_country, :isin_region, :region)
# Drop firms where country is missing
# @chain df_wikidata @subset(:esef_regulated; skipmissing=true) 


# TODO: Look at this group of companies who are subject to regulation, but not available via XBRL
@chain df_wikidata @subset(:country == "Germany"; skipmissing=true) @subset(ismissing(:lei_id))
df_wikidata

df = get_esef_xbrl_filings()

df = @chain df begin
    leftjoin(df_wikidata, on=(:key => :lei_id), matchmissing=:notequal, makeunique=true)
end

df_1 = @chain df begin 
    @subset(ismissing(:company_label))
    @select(:key, :entity_name, :company_label)
end


using JLD2

df_2 = load("company_results.jld2")
df_2 = df_2["company_results"]
df_2 = @chain df_2 @subset(nrow(:company_search_results[1]) == 0) # no results

key_list = df_2[!, :key]

df_1 = @chain df_1 @subset((:key in key_list))
df_1 = @chain df_1 @transform(:company_search_results = (lookup_company_by_name(split(:entity_name, " ")[1])),)

# df_2 = df_2["company_results"]
# df_2 = @chain df_2 @subset(nrow(:company_search_results[1]) > 1)
# df_2[!, :wikidata_uri] = [r[:company_search_results][1][1, :wikidata_uri] for r in    eachrow(df_2)]
# df_2[!, :company_label] = [r[:company_search_results][1][1, :company_label] for r in    eachrow(df_2)]
# df_2[!, :company_description] = [r[:company_search_results][1][1, :company_description] for r in    eachrow(df_2)]

# df_3 = @chain df_2 @select(:wikidata_uri, :key, :entity_name, :company_label, :company_description)
# show(df_3, truncate = 150, allrows=true)
# lookup_company_by_name(company_name)


pct_error_free = @chain df begin
    @transform(:error_free_report = :error_count == 0)
    @combine(:error_free_report_pct = round(mean(:error_free_report) * 100, digits=0))
    _[1, :error_free_report_pct]
end

axis = (width=500, height=250, xticks=[1, 50:50:500...], xlabel="Error Count", ylabel="Filing Count", title="Errored ESEF Filings by Error Count ($(pct_error_free)% error free)")
plt = @chain df begin 
    @subset(:error_count != 0)
    data(_) * mapping(:error_count) * histogram(bins=range(1, 500, length=50)) * visual(color=trr_266_colors[1])
end

fg1 = draw(plt; axis)

save("figs/esef_error_hist.svg", fg1, px_per_unit = 3)


world110m = dataset("world-110m")

world_geojson = @chain "https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json" URI()

country_rollup = @chain df begin
    @groupby(:country)
    @combine(:report_count = length(:country))
    leftjoin(europe, _, on=:country)
    @transform(:report_count = coalesce(:report_count, 0))
end
    
# jscpd:ignore-start

# First is for web, second for poster
map_heights = [("web", 300), ("poster", 270)]

for map_height in map_heights

    map_output = map_height[1]
    map_height = map_height[2]
    fg2a = @vlplot(width=500, height=map_height, title={text="ESEF Report Availability by Country", subtitle="(XBRL Repository)"})

    fg2b = @vlplot(width=500, height=map_height,
        mark={:geoshape, stroke=:white, fill=:lightgray},
        data={
            url=world_geojson,
            format={
                type=:topojson,
                feature=:countries
            }
        },
        projection={
            type=:azimuthalEqualArea,
            scale=525,
            center=[15, 53],
        },
    )

    fg2c = @vlplot(width=500, height=map_height,
        mark={:geoshape, stroke=:white},
        data={
            url=world_geojson,
            format={
                type=:topojson,
                feature=:countries
            }
        },
        transform=[{
            lookup="properties.name",
            from={
                data=(@chain country_rollup @subset(:report_count > 0)),
                key=:country,
                fields=["report_count"]
            }
        }],
        projection={
            type=:azimuthalEqualArea,
            scale=525,
            center=[15, 53],
        },
        fill={"report_count:q", axis={title="Report Count"}, scale={range=["#ffffff", trr_266_colors[2]]}},
    )

    fg2 = (fg2a + fg2b + fg2c)

    if map_output == "web"
        save("figs/esef_country_availability_map.svg", fg2)
    end

    # Make tweaks for poster
    if map_output == "poster"
        # Make tweaks for poster
        fg2.params["background"] = nothing # transparent background
        fg2.params["config"] = ("view" => ("stroke" => "transparent")) # remove grey border
        fg2.params["layer"][2]["encoding"]["fill"]["legend"] = nothing # drop legend
        fg2.params["title"] = nothing
        
        save("figs/esef_country_availability_map_poster.svg", fg2)
    end
end

fg2_bar = (@chain country_rollup @subset(:report_count > 0))  |>
    @vlplot({:bar, color=trr_266_colors[1]}, width=500, height=300,
        x={"country:o", title=nothing, sort="-y"},
        y={:report_count, title="Report Count"},
        title={
            text="ESEF Report Availability by Country",
            subtitle="(XBRL Repository)"
            },
        )
save("figs/esef_country_availability_bar.svg", fg2_bar)

esef_year_url = "https://raw.githubusercontent.com/trr266/esef/main/data/esef_mandate_overview.csv"
esef_year_df = @chain esef_year_url HTTP.get(_).body CSV.read(DataFrame; normalizenames=true)

fg3a = @vlplot(width=500, height=300, title={text="ESEF Mandate by Country", subtitle="(Based on Issuer's Fiscal Year Start Date)"})

fg3b = @vlplot(
    mark={:geoshape, stroke=:white, fill=:lightgray},
    data={
        url=world_geojson,
        format={
            type=:topojson,
            feature=:countries
        }
    },
    projection={
        type=:azimuthalEqualArea,
        scale=525,
        center=[15, 53],
    },
)

fg3c = @vlplot(
    mark={:geoshape, stroke=:white},
    width=500, height=300,
    data={
        url=world_geojson,
        format={
            type=:topojson,
            feature=:countries
        }
    },
    transform=[{
        lookup="properties.name",
        from={
            data=esef_year_df,
            key=:Country,
            fields=["Mandate_Affects_Fiscal_Year_Beginning"]
        }
    },
    {filter="isValid(datum.Mandate_Affects_Fiscal_Year_Beginning)"}
    ],
    projection={
        type=:azimuthalEqualArea,
        scale=525,
        center=[15, 53],
    },
    color={"Mandate_Affects_Fiscal_Year_Beginning:O", axis={title="Mandate Starts"}, scale={range=trr_266_colors}},
)

fg3 = (fg3a + fg3b + fg3c)
save("figs/esef_mandate_overview.svg", fg3)

# jscpd:ignore-end

df_error_wide = @chain df_error begin
    leftjoin(df, on=:key)
end

df_error_count = @chain df_error_wide begin
    @groupby(:error_code)
    @combine(:error_count = length(:error_code))
end

fg_error_freq_bar = df_error_count  |>
    @vlplot({:bar, color=trr_266_colors[1]}, width=500, height=500,
        y={"error_code:o", title="Error Code", sort="-x"},
        x={"error_count", title="Error Count"},
        title={text="ESEF Error Frequency", subtitle="(XBRL Repository)"}
    )
save("figs/esef_error_type_freq_bar.svg", fg_error_freq_bar)


df_error_country = @chain df_error_wide begin
    @groupby(:error_code, :country)
    @combine(:error_count = length(:error_code))
end

fg_error_country_heatmap = df_error_country |>
    @vlplot(:rect, width=500, height=500,
        x={"country:o", title=nothing},
        y={"error_code:o", title="Error Code"},
        color={:error_count, title="Error Count", scale={range=["#ffffff", trr_266_colors[2]]}},
        title="Error Frequency by Country and Type"
    )
save("figs/esef_error_country_heatmap.svg", fg_error_country_heatmap)

df_country_date = @chain df begin
    @groupby(:date, :country)
    @combine(:report_count = length(:country))
end

fg_country_date = df_country_date |>
    @vlplot(:rect, width=500, height=500,
        y={"country:o", title=nothing},
        x={"date:o", title="Date"},
        color={"report_count:q", title="Report Count", scale={range=["#ffffff", trr_266_colors[2]]}},
        title="Report Publication by Country and Date"
    )

fg_date_bar = df_country_date |>
    @vlplot({:bar, color=trr_266_colors[2]}, width=500, height=100,
        y={"sum(report_count)", title="Report Count"},
        x={"date:o", title="Date"},
        title="Report Publication by Date"
    )

fg_date_composite = [fg_date_bar; fg_country_date]
save("figs/esef_publication_date_composite.svg", fg_date_composite)
