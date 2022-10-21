SHELL := /bin/bash 

dev: 
	julia --project=src/

instantiate:
	julia --project=. -e 'using Pkg; Pkg.instantiate()'

build-viz: instantiate
	julia --project=. -e 'using ESEF; ESEF.generate_esef_homepage_viz()'

oxigraph-db-load: instantiate
	julia --project=. -e 'using ESEF; ESEF.serve_oxigraph()'
