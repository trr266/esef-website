SHELL := /bin/bash 

dev: 
	julia --project=src/

instantiate:
	julia --project=src -e 'using Pkg; Pkg.instantiate()'

build-viz: instantiate
	julia --project=src esef_index_viz.jl
