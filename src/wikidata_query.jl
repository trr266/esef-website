using HTTP
using JSON


function query_wikidata(sparql_query_file)
    query_string = readlines(sparql_query_file) |> join
    # 
    r = HTTP.request("GET", "https://query.wikidata.org/bigdata/namespace/wdq/sparql", ["Accept" => "application/sparql-results+json"], params=Dict("query"=> query_string, "format"=> "json"))

    d = JSON.parse(String(r.body))

    return d
end


d = query_wikidata("wikidata_regulated_firms.sparql")
