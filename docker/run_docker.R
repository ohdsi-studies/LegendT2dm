image_tag <- "jdposa/legend_t2dm:0.4"
local_folder <-  <YOUR LOCAL FOLDER HERE>
gcloud_local_folder <- <YOUR LOCAL GCLOUD FOLDER HERE>
user <- "ohdsi"
password <- "ohdsi"
forwarded_port <- 9001

bash_string <- sprintf("
sudo docker run -d -v %s:/workdir/workdir -v %s:/workdir/gcloud --name=rstudio-ohdsi -p %s:8787 -e ROOT=TRUE -e USER=%s -e PASSWORD=%s %s",
local_folder,
gcloud_local_folder,
forwarded_port,
user,
password,
image_tag)

print(bash_string)
system(bash_string)
