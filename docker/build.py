import os 

local_path = "/home/jposada/Documents/github_repos/legendtdm_stanford"
os.chdir(local_path)

bashstring = """
sudo docker build -t jdposa/legend_t2dm:0.3 ."""
os.system(bashstring)

# bash_string = """
# sudo docker push jdposa/legend_t2dm:0.3
# """
# os.system(bash_string)
