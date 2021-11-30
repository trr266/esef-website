using HTTP
using Chain
using DataFrames
using DataFrameMacros
using CSV

function get_country_codes()
    country_lookup_url = "https://raw.githubusercontent.com/lukes/ISO-3166-Countries-with-Regional-Codes/master/all/all.csv"
    country_lookup = @chain country_lookup_url HTTP.get(_).body CSV.read(DataFrame; normalizenames=true) @select(:country = :name, :country_alpha_2 = :alpha_2, :region)

    # Rename "United Kingdom of Great Britain and Northern Ireland" to "United Kingdom" for comprehensibility
    country_lookup[country_lookup.country_alpha_2 .== "GB", :country] .= "United Kingdom"

    europe = @chain country_lookup @subset(@m :region == "Europe"; skipmissing=true)
end

function get_esef_xbrl_filings()
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
    country_lookup = get_country_codes()
    
    df = @chain df begin
        leftjoin(_, country_lookup, on=:country_alpha_2)
    end

    return df
end
