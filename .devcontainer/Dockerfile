FROM jupyter/datascience-notebook:notebook-6.4.12

USER root

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && wget --no-verbose -O quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v0.9.583/quarto-0.9.583-linux-amd64.deb \
    && dpkg -i quarto.deb \
    && rm quarto.deb \
    && apt-get install --no-install-recommends -y lmodern rsync

COPY Project.toml Manifest.toml ./ 
COPY startup_ijulia.jl .julia/config/

RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate();'

CMD ["quarto", "render", "esef"]
