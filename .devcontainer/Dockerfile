FROM jupyter/datascience-notebook:notebook-6.5.1

USER root

RUN QUARTO_VERSION=1.2.258 \
    && apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && wget -O quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb \
    && dpkg -i quarto.deb \
    && rm quarto.deb \
    && apt-get install -y lmodern \
    && apt-get install -y rsync \
    && pip install papermill==2.4.0 \
    && quarto install tinytex

COPY Project.toml Manifest.toml ./ 
COPY startup_ijulia.jl .julia/config/

RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate();'

CMD ["quarto", "render", "esef"]
