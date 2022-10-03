# script created to extract txt files that were not historically relevant to existing 2 tableau workbooks that show data at an annual level
# files need to be downloaded and added to yearly folders before running the script
import gzip
import shutil
import os
# define files to be unzipped. Change as needed
years = ['2019', '2020', '2021']
months = ['01', '02', '06', '07', '08', '12']
fileloc = 'M:Data\\Traffic\\PeMS'

#loop through relevant year folders to extract the text files located in the 'original zipped' folder, then saving them in the year's folder
for year in years:
    for month in months:
        readpath = os.path.join(fileloc, year, 'original zipped')
        savepath = os.path.join(fileloc, year)
        with gzip.open(readpath + '\\d04_text_station_hour_' + year + '_' + month + '.txt.gz', 'rb') as f_in:
            with open(savepath + '\\d04_text_station_hour_' + year + '_' + month + '.txt', 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)