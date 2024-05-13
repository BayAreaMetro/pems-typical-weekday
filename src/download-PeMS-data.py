USAGE = """
This script enables the user to programmatically download files from the PeMS Clearinghouse.
It will prompt the user at the command line for their PeMS username and password, as well as
what type of data to download, and the district / years for which to download.

It operates in several modes:
- station_day
- station_hour
- tmg_trucks_hour

Requires python package selenium to interact with a web browser (https://selenium-python.readthedocs.io/)
Requires chromedriver.exe (from https://chromedriver.chromium.org/downloads) to be in location included in PATH

Tested with python-3.10.6
"""

import calendar, getpass, gzip, os, pathlib, shutil, sys, time
from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support.ui import Select
from selenium.webdriver.common.by import By

# data files are saved here, in subfolder '[yyyy]\original zipped'
DESTINATION_DIR = pathlib.Path('M:\\Data\\Traffic\\PeMS')
# data files are downloaded here but then moved into the DESTINATION_DIR
DOWNLOADS_DIR   = pathlib.Path(f'C:\\Users\\{os.getenv("USERNAME")}\\Downloads')

# query user for PeMS username and password
pems_username = input('To login to PeMS, please enter your PeMS username: ')
pems_password = getpass.getpass(prompt='To login to PeMS, please enter your PeMS password: ')
print('PeMS username={} password={}'.format(pems_username, pems_password))

# 'Chrome driver needed for this script.
# 'download and enter path below
# 'initialize the Chrome driver
driver = webdriver.Chrome()
# load the Clearinghouse page, which will require login
driver.get('https://pems.dot.ca.gov/?dnode=Clearinghouse')

driver.find_element('id', "username").send_keys(pems_username)
driver.find_element('id', "password").send_keys(pems_password)
driver.find_element('name', "login").click()
# wait for login
time.sleep(3)

while True:

    pems_mode = input('What type of clearinghouse data do you want to download?  [station_day, station_hour, tmg_trucks_hour, q=quit]: ')
    print('pems_mode={}'.format(pems_mode))
    if pems_mode == 'q':
        sys.exit()

    if pems_mode not in ['station_day','station_hour','tmg_trucks_hour']:
        print('Pems data type entered option ({}) not understood'.format(pems_mode))
        continue

    district = 'all'

    # choose district for station_day, station_hour
    if pems_mode in ['station_day','station_hour']:

        district = input('Enter a Caltrans district: [3,4,5,6,7,8,10,11,12]: ')
        if district not in ['3','4','5','6','7','8','10','11','12']:
            print('District entered option ({}) not understood'.format(district))
            continue # if i were nice i'd loop on district...

    # load the appropriate Clearinghouse page
    selectType = Select(driver.find_element('id', 'type'))
    selectType.select_by_value(pems_mode)

    selectType = Select(driver.find_element('id', 'district_id'))
    selectType.select_by_value(district)

    driver.find_element('name', "submit").click()
    time.sleep(3)

    # choose years for all
    years_input = input('Enter a comma delimited set of years: ')
    years = years_input.split(',')

    year_tds = driver.find_elements(By.CLASS_NAME, 'widgetYear')

    months = range(1,13)
    # only 'typical months' for trucks since these are daily files
    if pems_mode == 'tmg_trucks_hour':
        months = [3,4,5,9,10,11]

    for year in years:
        try:
            # click on a month in the year table of grey boxes to load year links
            month_tds = driver.find_elements(By.XPATH, "//td[contains(text(),'{:02d}')]/following-sibling::td".format(int(year)%100))
            month_tds[0].click()
            time.sleep(2)
        except Exception as e:
            print('Could not find year/month element for year {}'.format(year))
            continue

        # download file for required months
        for month in months:

            # files are monthly for station_hour, station_day
            mdays = range(1,2)

            # download file for all days for trucks
            if pems_mode == 'tmg_trucks_hour':
                (dummy, total_mdays) = calendar.monthrange(int(year), month)
                mdays = range(1, total_mdays+1)

            for mday in mdays:

                if pems_mode == 'station_hour':
                    element_name = 'd{:02d}_text_station_hour_{:d}_{:02d}.txt.gz'.format(int(district), int(year), month)
                elif pems_mode == 'station_day':
                    element_name = 'd{:02d}_text_station_day_{:d}_{:02d}.txt.gz'.format(int(district), int(year), month)
                elif pems_mode == 'tmg_trucks_hour':
                    element_name = 'all_text_tmg_trucks_hour_{:d}_{:02d}_{:02d}.txt.gz'.format(int(year), month, mday)

                # first check if file is already there
                unzip_dir = DESTINATION_DIR / year
                zip_dir   = unzip_dir / 'original_zipped'
                zip_file = zip_dir / element_name
                if os.path.exists(zip_file):
                    print('File {} exists -- skipping'.format(zip_file))
                    continue

                # mkdir if needed
                if not os.path.exists(zip_dir): os.mkdir(zip_dir)

                print('Looking for element_name: {}'.format(element_name))
                try:
                    driver.find_element('link text', element_name).click()
                except Exception as e:
                    print('')
                    print('Could not find element {}'.format(element_name))
                    continue

                # wait for download
                src_file = os.path.join(DOWNLOADS_DIR, element_name)
                print(f"  Waiting for download {src_file}")

                while (not os.path.exists(src_file)):
                    time.sleep(2)

                # move the file into place
                shutil.move(src_file, zip_file)
                print(f'  Moved to {zip_file}')

                # don't do this for truck; summarize-census-trucks-hour.R uses the gzipped files directly
                if pems_mode == 'tmg_trucks_hour': continue
                
                unzip_file = unzip_dir / element_name.replace(".gz","")
                with gzip.open(zip_file, 'rb') as f_in:
                    with open(unzip_file, 'wb') as f_out:
                        shutil.copyfileobj(f_in, f_out)
                print(f'  Unzipped to {unzip_file}')

        print('Completed year {}'.format(year))
    driver.close()
