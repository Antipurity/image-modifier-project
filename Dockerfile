FROM julia
WORKDIR /app
COPY . .
RUN julia -e "using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.precompile()"
CMD julia --project src/ImageModifierProject.jl $PORT