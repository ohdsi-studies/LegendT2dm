# enviroment paths
working_directory <- "/workdir"
study_package_directory <- "/workdir/LegendT2dm"
r_env_cache_folder <- "/workdir/renv_cache"
renv_package_version <- '0.13.2'
renv_vesion <- "v5"
r_version <- "R-4.0"
linux_version <- "x86_64-pc-linux-gnu"
renv_final_path <- paste(r_env_cache_folder,
                         renv_vesion,
                         r_version,
                         linux_version,
                         sep="/")

setwd(working_directory)

# Install Renv
install.packages('remotes')
remotes::install_github(paste0('rstudio/renv@',renv_package_version))
# setting paths cache so it can be reused
Sys.setenv("RENV_PATHS_CACHE"=r_env_cache_folder)

# Build the local library
# ,packages=c("yaml", "zip")
renv::restore(rebuild=T,
              prompt=FALSE
              )
                         