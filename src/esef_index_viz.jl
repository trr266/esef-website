using Chain
using JSON
using HTTP
using DataFrames

xbrl_esef_index_endpoint = "https://filings.xbrl.org/index.json"
r = HTTP.get(xbrl_esef_index_endpoint)

# Check 200 HTTP status code
@assert(r.status == 200)

data = @chain r.body begin
    String()
    JSON.parse()
end

df = DataFrame()
row_names = (:key, :entity_name, :country, :date, :error_count, :error_codes)

# Parse XBRL ESEF Index Object
for (d_key, d_value) in data
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
