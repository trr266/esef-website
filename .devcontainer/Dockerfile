FROM julia:1.9-rc

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

bi
COPY docs/Project.toml docs/Manifest.toml docs
COPY startup_ijulia.jl .julia/config/
COPY setup_julia.jl .

RUN julia --project=docs setup_julia.jl

CMD ["quarto", "render", "docs", "--no-execute-daemon"]
