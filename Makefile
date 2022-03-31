SHELL := /bin/bash 

dev: 
	julia --project=src/

instantiate:
	julia --project=. -e 'using Pkg; Pkg.instantiate()'

build-viz: instantiate
	julia --project=. src/esef_index_viz.jl

oxigraph-db-load: instantiate
	julia --project=. src/oxigraph_server.jl
