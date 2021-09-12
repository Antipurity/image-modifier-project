FROM julia
WORKDIR /
COPY . .
RUN julia -e "using Pkg; Pkg.instantiate(); Pkg.precompile();"
CMD ["julia", "--project", "src/ImageModifierProject.jl", "$PORT"]