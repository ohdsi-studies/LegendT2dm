FROM odysseusinc/rstudio-ohdsi:1.1.0

# OS dependencies required by R sodium package
RUN mkdir /workdir \
    && sudo apt-get update -y \
    && sudo apt-get install -y libsodium-dev

# Copy a modified version of lock file since Rcpp needs to be the updated version
COPY renv.lock /workdir
COPY install_renv_lock.R /workdir
RUN cd /workdir && Rscript install_renv_lock.R

# install aditional packages
RUN cd /workdir && git clone https://github.com/ohdsi-studies/LegendT2dm.git
COPY install_additional_packages.R /workdir
RUN cd /workdir && Rscript install_additional_packages.R

