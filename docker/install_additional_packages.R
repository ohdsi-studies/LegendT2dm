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

# required for Bigquery
install.packages('devtools')

.libPaths(renv_final_path)
devtools::install_github("jdposada/BQJdbcConnectionStringR", 
                         lib=renv_final_path, 
                         upgrade="never")

# Installing the Study Package
setwd(study_package_directory)
devtools::install(quiet=TRUE, upgrade="never", dependencies=F)

# Load the package to test is correctly installed
library(LegendT2dm)