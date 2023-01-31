FROM --platform=linux/amd64 jupyter/datascience-notebook:notebook-6.5.2

USER root

RUN QUARTO_VERSION=1.2.335 \
    && apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y build-essential git clang \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && wget -O quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb \
    && dpkg -i quarto.deb \
    && rm quarto.deb \
    && apt-get install -y lmodern \
    && apt-get install -y rsync \
    && quarto install tinytex \
    && python3 -m pip install jupyter-cache

COPY Project.toml Manifest.toml ./ 
COPY startup_ijulia.jl .julia/config/

ENV QUARTO_PYTHON=/opt/conda/bin/python3

RUN julia -e 'using Pkg; Pkg.add("IJulia"); Pkg.add("Revise");' \
    julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate();'

CMD ["quarto", "render", "esef"]
