using HTTP
using JSON
using DataFrames
using DataFrameMacros
using Chain
using Mustache

include("iso_country_codes.jl")

function query_wikidata(sparql_query_file; params=Dict())

    headers = ["Accept" => "application/sparql-results+json", "Content-Type"=>"application/x-www-form-urlencoded"]
    url = "https://query.wikidata.org/bigdata/namespace/wdq/sparql"

    query_string = @chain sparql_query_file read(String) render(params) HTTP.escapeuri()

    body = "query=$query_string"
    r = HTTP.post(url, headers, body)

    d = JSON.parse(String(r.body))

    df = DataFrame()

    for r in d["results"]["bindings"]
        df1 = DataFrame(r)
        append!(df, df1; cols=:union)
    end

    return df
end


function get_public_companies_wikidata()
    df = query_wikidata("src/queries/wikidata_lei_entities.sparql")

    df = @chain df begin
        @transform(:wikidata_uri = :entity["value"])
        @transform(:company_label = @m :entityLabel["value"])
        @transform(:isin_id = @m :isin_value["value"])
        @transform(:lei_id = @m :lei_value["value"])
        @transform(:country_uri = @m :country["value"])
        @transform(:country = @m :countryLabel["value"])
        @transform(:country_alpha_2 = @m :country_alpha_2["value"])
        @transform(:isin_alpha_2 = @m first(:isin_id, 2))
        @select(:wikidata_uri, :company_label, :country, :country_uri, :country_alpha_2, :isin_id, :isin_alpha_2, :lei_id)
    end

    # Add in country names
    country_lookup = get_country_codes()
    
    df = @chain df begin
        leftjoin(_, (@chain country_lookup @select(:region, :country_alpha_2)), on=:country_alpha_2, matchmissing=:notequal)
        leftjoin(_, (@chain country_lookup @select(:isin_alpha_2 = :country_alpha_2, :isin_country = :country, :isin_region = :region)), on=:isin_alpha_2, matchmissing=:notequal)
    end
    
    df = @chain df @transform(:esef_regulated = esef_regulated(:isin_region, :region))
    
    return df
end

function esef_regulated(isin_region, country_region)
    if ismissing(isin_region) && ismissing(country_region)
        return missing
    elseif ismissing(isin_region)
        return country_region == "Europe"
    elseif ismissing(country_region)
        return isin_region == "Europe"
    else
        return (country_region == "Europe") || (isin_region == "Europe")
    end
end

function lookup_company_by_name(company_name)
    try
        df = query_wikidata("src/queries/wikidata_company_search.sparql", params=Dict("company_name" => company_name))
        if nrow(df) == 0
            return DataFrame()
        end
    
        df = @chain df begin
            @transform(:wikidata_uri = :company["value"],
            :company_label = :companyLabel["value"],
            :company_description = :companyDescrip["value"])
            @groupby(:wikidata_uri)
            @combine(:company_label = :company_label[1], :company_description = :company_description[1])
            @select(:wikidata_uri, :company_label, :company_description)
        end
    
        return df        
    catch e
        return DataFrame()
    end
end



