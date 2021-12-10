SHELL := /bin/bash 

# Add local path for julia...
PATH=$PATH:/Applications/Julia-1.7 2.app/Contents/Resources/julia/bin/:bin

dev: 
	julia --project=src/

instantiate:
	julia --project=. -e 'using Pkg; Pkg.instantiate()'

build-viz: instantiate
	julia --project=. src/esef_index_viz.jl
