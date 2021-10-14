# Docker Image for LegendT2DM


## Instructions

- Open a terminal
- Clone `LengedT2DM` by typing `git clone https://github.com/ohdsi-studies/LegendT2dm.git`
- Go into the docker subfolder `cd LengedT2DM/docker`
- Run the container by using the auxiliary script `Rscript run_docker.R`. Please change the variables `local_folder` and `gcloud_local_folder`. **If you are not using gcloud you can safely remove lines 5 and 15**
- Open a tab in your preferred brower and type `localhost:9001`. This will open an Rstudio server instance running locally.
- Type the username and password. By default both are `ohdsi`. you can change that inside the `run_docker.R`
- Once in RStudio change the directory to `/workdir/workdir`
- Source `testRun.R` to confirm everything is working. If you are not using gcloud several paramteres need to be changed in that script to connect to an instance you are authorized to.

## File Description

- **Dockerfile**: This file contains the steps performed to create the docker image on `jdposa/legend_t2dm:0.4`. The image is based on an image created by Odysseus Inc `rocker/rstudio:4.0.5`. This dockerfile contains the installation of libsodium an OS library required to run the R sodium package. 
- **build.R**: Small R script to build the Dockerfile and create the docker image. 
- **install_renv_lock.R**: Small R script to use the renv.lock file to create an R library that contains everything eneded for the study.
- **install_additional_packages.R**: Small R Script to install any additional packages besides what it is inside the `renv.lock` file. As of now includes a small package to ease the creation of teh conneciton string when using bigquery. Also it builds the `LengedT2DM` package programatically. If anyone needs to install any other dependency not covered in renv.lock, this is the space to do so. 
- **renv.lock**: This is a copy of the file found in the main folder of this repo.
- **run_docker.R**: Small R script to download and run the Docker image creating a container named `rstudio-ohdsi`. This small script can be modified in a way that the user could mount a directory of their chosing and specify the forwarded port used to launch RStudio.
- **testRun.R**: This small R Script is meant to test the Docker container by running a small SQL against the Bigquery Public Synpuf dataset formatted as an OMOP-CDM v5.3.1


NOTE: To build the image the `renv.lock` file from the main folder needs to be copied to the `docker` folder.
