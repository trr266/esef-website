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


trr_266_colors = ["#1b8a8f", "#ffb43b", "#6ecae2", "#944664"] # petrol, yellow, blue, red

xbrl_esef_index_endpoint = "https://filings.xbrl.org/index.json"
r = HTTP.get(xbrl_esef_index_endpoint)

# Check 200 HTTP status code
@assert(r.status == 200)

raw_data = @chain r.body begin
    String()
    JSON.parse()
end

df = DataFrame()
row_names = (:key, :entity_name, :country_alpha_2, :date, :error_count, :error_codes)

df_error = DataFrame()

# Parse XBRL ESEF Index Object
for (d_key, d_value) in raw_data
    entity_name = d_value["entity"]["name"]
    report_details = first(values(d_value["filings"]))

    error_payload = report_details["errors"]
    error_count = length(error_payload)
    error_codes = [d["code"] for d in error_payload]

    country = report_details["country"]
    date = report_details["date"]

    new_row = NamedTuple{row_names}([d_key, entity_name, country, date, error_count, error_codes])
    push!(df, new_row)

    for error_code in error_codes
        push!(df_error, NamedTuple{(:key, :error_code)}([d_key, error_code]))
    end
end


# Add in country names
country_lookup_url = "https://raw.githubusercontent.com/lukes/ISO-3166-Countries-with-Regional-Codes/master/all/all.csv"
country_lookup = @chain country_lookup_url HTTP.get(_).body CSV.read(DataFrame; normalizenames=true) @select(:country = :name, :country_alpha_2 = :alpha_2, :region)

# Rename "United Kingdom of Great Britain and Northern Ireland" to "United Kingdom" for comprehensibility
country_lookup[country_lookup[!, :country_alpha_2] .== "GB", :country] = ["United Kingdom"]

europe = @chain country_lookup @subset(@m :region == "Europe"; skipmissing=true)

df = @chain df begin
    leftjoin(_, country_lookup, on=:country_alpha_2)
end

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
# , linecolor=parse.(Colorant, trr_266_colors)[1])
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

fg2a = @vlplot(width=500, height=300, title={text="ESEF Report Availability by Country", subtitle="(XBRL Repository)"})

fg2b = @vlplot(width=500, height=300,
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

fg2c = @vlplot(width=500, height=300,
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
save("figs/esef_country_availability_map.svg", fg2)

# Make tweaks for poster
fg2.params["background"] = nothing
fg2.params["layer"][2]["encoding"]["fill"]["legend"] = nothing

save("figs/esef_country_availability_map_poster.svg", fg2)

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
    @vlplot({:bar, color=trr_266_colors[1]}, width=500, height=500, background=nothing,
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
