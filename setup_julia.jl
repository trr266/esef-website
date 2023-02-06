using Pkg
Pkg.instantiate()

using Conda

Conda.add("jupyter")
Conda.add("jupyter-cache")
