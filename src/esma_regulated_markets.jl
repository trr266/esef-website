using Chain
using DataFrames
using JSON
using DataFrameMacros
using HTTP
using YAML
using OrderedCollections

reg_market_query = "https://registers.esma.europa.eu/solr/esma_registers_upreg/select?q=%7B!join+from%3Did+to%3D_root_%7Dae_entityTypeCode%3AMIR&fq=(type_s%3Aparent)&rows=1000&wt=json&indent=true"

r = HTTP.get(reg_market_query)

# Check 200 HTTP status code
@assert(r.status == 200)

raw_data = @chain r.body begin
    String()
    JSON.parse()
end

@assert(raw_data["response"]["numFound"] < 1000) # Check that everything fit in one page

df = DataFrame()
for d in raw_data["response"]["docs"]
    append!(df, DataFrame(d))
end

# Strip out excess columns
df = @chain df begin
    @select(:id, :ae_entityName, :ae_competentAuthority)
    @transform(:url = "TODO", :time_estimate = "TODO", :scraping_type = "TODO", :secondary = false)
    @sort(:ae_entityName)
end

# Write to YAML
@chain [OrderedDict(names(d) .=> values(d)) for d in eachrow(df)] YAML.write_file("regulated_markets.yml", _)


d1 = YAML.load_file("data/regulated_markets.yml")

d2 = [OrderedDict(d..., "license_terms" => "TODO", "license_url" => "TODO") for d in d1]

YAML.write_file("regulated_markets.yml", d2)
