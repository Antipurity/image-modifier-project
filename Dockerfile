FROM julia
WORKDIR /
COPY . ./
RUN julia --project=. -e "import Pkg; Pkg.instantiate(); Pkg.precompile()"
RUN cp -r ~/.julia /.julia
RUN rm -rf /.julia/registries
CMD julia --project=. src/ImageModifierProject.jl $PORT