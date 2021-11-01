FROM julia:1.7

RUN apt-get update && apt-get install --no-install-recommends -y git && rm -rf /var/lib/apt/lists/*

COPY Project.toml Manifest.toml /

RUN julia -e 'using Pkg; Pkg.activate(); Pkg.instantiate(); Pkg.precompile();'
