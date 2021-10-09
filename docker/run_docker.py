import os

image_tag = "jdposa/legend_t2dm:0.3"
local_folder = "/home/jposada/Documents/github_repos/LegendT2dm/docker"
gcloud_local_folder = "/home/jposada/.config/gcloud"
user = "ohdsi"
password = "ohdsi"
forwarded_port = 9000



bash_string = f"""
sudo docker run -d \
-v {local_folder}:/workdir/workdir \
-v {gcloud_local_folder}:/workdir/gcloud \
--name=rstudio-ohdsi \
-p {forwarded_port}:8787 \
-e ROOT=TRUE \
-e USER={user} \
-e PASSWORD={password} \
{image_tag}
"""

os.system(bash_string)