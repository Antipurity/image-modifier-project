FROM julia
WORKDIR /
COPY . .
RUN julia -e "import Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.API.precompile();"
RUN julia -e "import Pkg; Pkg.activate(\".\"); println(keys(Pkg.API.project().dependencies))"
CMD julia --project src/ImageModifierProject.jl $PORT