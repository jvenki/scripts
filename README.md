# scripts

The script lead-dropoff-analysis.sh analyses the various log files and returns back a consolidated summary. 
To run the script, go to our Logs Server and then invoke
``lead-dropoff-analysis.sh -d 2018-06-28 -s /gluster-logs/mp/ -o out``

Here 
-d stands for the date on which you want to analyze
-s stands for the location of the logs root directory. Generally it is /gluster-logs/mp. However, if you have downloaded the files to your local machine, you can give your own folder name
-o where we create all the artifacts

