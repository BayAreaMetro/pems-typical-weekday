# run this script after downloading new bridge data to specified path below. Rename new_bridge_traffic to match the name of the file. 
# afterwards, you can copy and paste the values into excel to graph the data

import pandas as pd
from datetime import datetime
import calendar
import os

# enter name of new bridge traffic file below
new_bridge_traffic = 'Thru 09-19-2022.xlsx'

path = 'C:\\Users\\jalatorre\\Box\\NextGen Freeways Study\\08 Analysis\Existing Conditions Analysis\\202202 Freeway Volumes\\'
path_to_new_bridge_traffic = path + new_bridge_traffic
path_to_old_bridge_traffic = path + 'bridge_traffic_032019_022920.csv'
# Read excel file with sheet name
dict_df = pd.read_excel(path_to_new_bridge_traffic, 
                   sheet_name=None)
old_bridge_traffic = pd.read_csv(path_to_old_bridge_traffic)
old_bridge_traffic['Bridge'] = old_bridge_traffic['Bridge'].replace('SFOBB', 'Sfobb')
old_bridge_traffic['Bridge'] = old_bridge_traffic['Bridge'].replace('SM-Hayward', 'SMHay')

# function to get week number of month
def week_of_month(tgtdate): #contributor: lifeisstillgood, stack overflow
    days_this_month = calendar.mdays[tgtdate.month]
    for i in range(1, days_this_month):
        d = datetime(tgtdate.year, tgtdate.month, i)
        if d.day - d.weekday() > 0:
            startdate = d
            break
    # now we canuse the modulo 7 appraoch
    return (tgtdate - startdate).days //7 + 1

Bridges = ['Ant', 'Ben', 'Carq', 'Dumb', 'Rich', 'Sfobb', 'SMHay']

# make one large table to pivot from

df = pd.DataFrame()
for bridge in Bridges:
    temp_df = dict_df.get(bridge)
    temp_df.drop(index=temp_df.index[0], axis=0, inplace=True)    
    temp_df['Bridge'] = bridge
#     temp_df['Traffic_Date']= pd.to_datetime(temp_df['Traffic_Date'])
    temp_df['Year'] = pd.DatetimeIndex(temp_df['Traffic_Date']).year.values
    temp_df['Month'] = pd.DatetimeIndex(temp_df['Traffic_Date']).month.values
    temp_df['Day'] = pd.DatetimeIndex(temp_df['Traffic_Date']).day.values
    temp_df['Week'] = temp_df['Traffic_Date'].apply(week_of_month)

    df = df.append(temp_df)

df = df.append(old_bridge_traffic)

# filter out data for typical weekday, filter for available historic (2019) data

df = df[df.Week == 2]
df = df[df.Week_Day == 'Wednesday']
df = df[df.Month != 1]
df = df[df.Month != 2]

# pivot table

pivot = df.pivot_table(values='Total_Count', index = 'Bridge', columns= ['Year', 'Month'], aggfunc= 'sum')

df_out = pd.DataFrame()

# get percentages based on 2019 values

for year in [2020, 2021, 2022]:
    temp = pivot.loc[:,year] / pivot.loc[:,2019]
    df_out = pd.concat([df_out, temp], axis=1)

# clean df to get desired structure, then export csv
    
df_out = df_out.dropna(axis='columns').reset_index()
filename = 'graph percentages - ' + new_bridge_traffic.split(".")[0] + '.csv'
df_out.to_csv(os.path.join(path,filename), header=True, index=False)