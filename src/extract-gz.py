# script created to extract txt files that were not historically relevant to existing 2 tableau workbooks that show data at an annual level
# files need to be downloaded and added to yearly folders before running the script
import gzip
import shutil
import os
from time import sleep
from tqdm import tqdm
# define files to be unzipped. Change as needed
years = ['2023']
months = [ '01']
fileloc = 'M:Data\\Traffic\\PeMS'

#loop through relevant year folders to extract the text files located in the 'original zipped' folder, then saving them in the year's folder
for year in tqdm(years):
    sleep(3)
    for month in months:
        readpath = os.path.join(fileloc, year, 'original zipped')
        savepath = os.path.join(fileloc, year)
        with gzip.open(readpath + '\\d04_text_station_hour_' + year + '_' + month + '.txt.gz', 'rb') as f_in:
            with open(savepath + '\\d04_text_station_hour_' + year + '_' + month + '.txt', 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)