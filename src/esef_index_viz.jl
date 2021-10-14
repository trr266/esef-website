using Chain
using JSON
using HTTP
using DataFrames
using AlgebraOfGraphics
using CairoMakie

xbrl_esef_index_endpoint = "https://filings.xbrl.org/index.json"
r = HTTP.get(xbrl_esef_index_endpoint)

# Check 200 HTTP status code
@assert(r.status == 200)

raw_data = @chain r.body begin
    String()
    JSON.parse()
end

df = DataFrame()
row_names = (:key, :entity_name, :country, :date, :error_count, :error_codes)

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

axis = (width = 500, height = 250, xlabel="Error Count", ylabel="Filing Count", title="ESEF Filings by Error Count")
plt = data(df) * mapping(:error_count) * histogram(bins=range(0, 500, length=100))
fg = draw(plt; axis)
save("figs/esef_error_hist.png", fg, px_per_unit = 3)
