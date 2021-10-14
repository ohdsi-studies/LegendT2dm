FROM rocker/rstudio:4.0.5

# OS dependencies
# JAVA, libsodium
RUN mkdir /workdir \
    && sudo apt-get update -y \
    && sudo apt-get install -y --no-install-recommends \
                            libsodium-dev \
                            openjdk-11-jdk-headless \
                            ant \
                            git \
                            libbz2-dev \
                            liblzma-dev \
                            libcairo2-dev \
                            libcurl4-openssl-dev \
                            libfontconfig1-dev \
                            libpcre3-dev \
                            libssl-dev \
                            libxml2 \
                            libxml2-dev \
                            openjdk-11-jdk-headless \
                            pandoc \
                            zlib1g-dev \
    && sudo apt-get clean;
    
# Fix certificate issues for JAVA
RUN sudo apt-get update && \
    sudo apt-get install ca-certificates-java && \
    sudo apt-get clean && \
    sudo update-ca-certificates -f;

# Setup JAVA_HOME 
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV LD_LIBRARY_PATH=/usr/lib/jvm/java-11-openjdk-amd64/lib/server

# Make R detect the JAVA install
RUN R CMD javareconf

# Copy the lock file
COPY renv.lock /workdir
COPY install_renv_lock.R /workdir
RUN cd /workdir && Rscript install_renv_lock.R

# install aditional packages
RUN cd /workdir && git clone https://github.com/ohdsi-studies/LegendT2dm.git
COPY install_additional_packages.R /workdir
RUN cd /workdir && Rscript install_additional_packages.R

