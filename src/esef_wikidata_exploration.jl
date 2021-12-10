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

# df_wikidata_lei = get_lei_companies_wikidata()

df_wikidata_isin = get_non_lei_isin_companies_wikidata()

# Check only minimal number of firms where country is missing (e.g. EU, ersatz XC/XY/XS, or incorrect 00, 23)
@assert((@chain df_wikidata_lei @subset(ismissing(:esef_regulated)) nrow()) < 1e3)
@assert((@chain df_wikidata_isin @subset(ismissing(:esef_regulated)) nrow()) < 10)

# Drop firms where country is missing
df_wikidata_isin = @chain df_wikidata_isin @subset(:esef_regulated; skipmissing=true) 


# TODO: Look at this group of companies who are subject to regulation, but not available via XBRL
@chain df_wikidata_isin @subset(:country == "Germany"; skipmissing=true)

df = get_esef_xbrl_filings()

df = @chain df begin
    leftjoin(df_wikidata_lei, on=(:key => :lei_id), matchmissing=:notequal, makeunique=true)
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
