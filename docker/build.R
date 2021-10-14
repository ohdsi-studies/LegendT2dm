# NOTE: before running this script be sure to set the 
# working directory to the location of this file

bashstring <- "sudo docker build -t jdposa/legend_t2dm:0.4 ."
system(bashstring)

# bash_string = """
# sudo docker push jdposa/legend_t2dm:0.4
# """
# os.system(bash_string)
