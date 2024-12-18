FROM pandoc/latex:latest-ubuntu

WORKDIR /app

ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia

RUN QUARTO_VERSION=1.7.5 \
    && apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -qq install -y build-essential git clang wget rsync \
    && ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then \
        wget -O quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb; \
    elif [ "$ARCH" = "arm64" ]; then \
        wget -O quarto.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-arm64.deb; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi \
    && dpkg -i quarto.deb \
    && rm quarto.deb \
    && apt-get -qq install -y lmodern

ENV JULIA_DEPOT_PATH=/opt/julia_depot
ENV JULIAUP_DEPOT_PATH=/opt/juliaup

RUN apt-get install curl && \
    curl -fsSL https://install.julialang.org | sh -s -- -y --default-channel release --path /opt/juliaup
    
ENV PATH=/opt/juliaup/bin:$PATH    

COPY . /app

RUN julia -e 'using Pkg; Pkg.add("IJulia");' && \
    julia --project=docs -e 'using Pkg; Pkg.instantiate();'

CMD ["quarto", "render", "docs", "--no-execute-daemon"]
