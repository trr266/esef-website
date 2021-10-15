using Chain
using JSON
using HTTP
using DataFrames
using AlgebraOfGraphics
using CairoMakie
using DataFrameMacros
using Statistics
using VegaLite
using VegaDatasets
using URIParser
using CSV

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
    data(_) * mapping(:error_count) * histogram(bins=range(1, 500, length=50))
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

fg2a = @vlplot(width=500, height=300, title={text="ESEF Report Availability by Country", subtitle="(XBRL Repository)"})

fg2b = @vlplot(
    mark={:geoshape, stroke=:white, fill=:lightgray},
    data={
        url=world_geojson,
        format={
            type=:topojson,
            feature=:countries
        }
    },
    projection={
        type=:mercator,
        scale=350,
        center=[20, 50],
    },
)

fg2c = @vlplot(
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
        type=:mercator,
        scale=350,
        center=[20, 50],
    },
    fill={"report_count:q", axis={title="Report Count"}},
    title={text="ESEF Report Availability by Country", subtitle="(XBRL Repository)"},
)

fg2 = (fg2a + fg2b + fg2c)
save("figs/esef_country_availability.svg", fg2)

fg2a = @vlplot(width=500, height=300, title={text="ESEF Mandate Year by Country", subtitle="(XBRL Repository)"})

fg2b = @vlplot(
    mark={:geoshape, stroke=:white, fill=:lightgray},
    data={
        url=world_geojson,
        format={
            type=:topojson,
            feature=:countries
        }
    },
    projection={
        type=:mercator,
        scale=350,
        center=[20, 50],
    },
)

fg2c = @vlplot(
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
        type=:mercator,
        scale=350,
        center=[20, 50],
    },
    fill={"report_count:q", axis={title="Report Count"}},
    title={text="ESEF Report Availability by Country", subtitle="(XBRL Repository)"},
)

fg2 = (fg2a + fg2b + fg2c)
fg2 |> save("myfigure.vegalite")
save("figs/esef_country_availability.svg", fg2)
