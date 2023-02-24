FROM julia:1.9-rc

ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV PATH=/root/.julia/conda/3/bin:$PATH

RUN QUARTO_VERSION=1.3.220 \
    && apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -qq install -y build-essential git clang wget \
    && wget -O quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb \
    && dpkg -i quarto.deb \
    && rm quarto.deb \
    && apt-get -qq install -y lmodern \
    && apt-get -qq install -y rsync \
    && quarto install tinytex --quiet

COPY docs/Project.toml docs/Manifest.toml docs/
COPY startup_ijulia.jl .julia/config/
COPY setup_julia.jl .

RUN julia --project=docs setup_julia.jl

CMD ["quarto", "render", "docs", "--no-execute-daemon"]
