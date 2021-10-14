FROM julia:1.7

RUN apt-get update && apt-get install -y git

COPY Project.toml Manifest.toml /

# RUN julia -e 'using Pkg; Pkg.activate(); Pkg.instantiate(); Pkg.precompile();'
