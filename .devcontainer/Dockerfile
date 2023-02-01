FROM --platform=linux/amd64 julia:1.8.4

USER root

RUN QUARTO_VERSION=1.3.149 \
    && apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y build-essential git clang wget \
    && wget -O quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb \
    && dpkg -i quarto.deb \
    && rm quarto.deb \
    && apt-get install -y lmodern \
    && apt-get install -y rsync \
    && quarto install tinytex \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y


# COPY Project.toml Manifest.toml ~/.julia/environments/v1.8/
COPY startup_ijulia.jl .julia/config/

RUN julia -e 'using Pkg; Pkg.instantiate(.);' \
    julia -e 'using Conda; Conda.add("jupyter"); Conda.add("jupyter-cache");'

CMD ["quarto", "render", "esef"]


