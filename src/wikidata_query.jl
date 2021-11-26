using HTTP
using JSON
using DataFrames
using DataFrameMacros
using Chain

function query_wikidata(sparql_query_file)

    headers = ["Accept" => "application/sparql-results+json", "Content-Type"=>"application/x-www-form-urlencoded"]
    url = "https://query.wikidata.org/bigdata/namespace/wdq/sparql"

    query_string = @chain sparql_query_file readlines() join("\n") HTTP.escapeuri()
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

df = query_wikidata("queries/wikidata_regulated_firms.sparql")

df = @chain df begin
    @transform(:wikidata_uri = :company["value"],
               :company_label = :companyLabel["value"])
    @transform(:isin_id = @m :isin_value["value"])
    @transform(:lei_id = :lei_value["value"])
    @select(:wikidata_uri, :company_label, :isin_id, :lei_id)
end

