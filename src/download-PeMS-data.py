# pip install selenium

# 'enter new month desired in format below
# 'ex: month = '07'
month = '06'

from selenium import webdriver
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support.ui import Select
import time

# 'Chrome driver needed for this script.
# 'download and enter path below
# 'initialize the Chrome driver
driver = webdriver.Chrome(executable_path='../chromedriver.exe')

driver.get('https://pems.dot.ca.gov/?dnode=Clearinghouse&type=station_day&district_id=4&submit=Submit')

# 'enter username and password below
username = ""
password = ""
driver.find_element('id', "username").send_keys(username)
driver.find_element('id', "password").send_keys(password)
driver.find_element('name', "login").click()

# 'download station_hour file
time.sleep(3)

selectType = Select(driver.find_element('id', 'type'))
selectType.select_by_value('station_hour')

selectType = Select(driver.find_element('id', 'district_id'))
selectType.select_by_value('4')

driver.find_element('name', "submit").click()

time.sleep(3)

driver.find_element('link text', "d04_text_station_hour_2022_" + month + ".txt.gz").click()

time.sleep(15)
driver.close()