# Build Annual Database
#
## Administration
#
### Purpose
# Extract typical weekday flows and speeds from the Caltrans Performance Monitoring database (PeMS).  To access the raw data, start here:
# 1. http://pems.dot.ca.gov/
# 2. Login (data is free with sign-up)
# 3. Navigate to Tools --> Data Clearinghouse (http://pems.dot.ca.gov/?dnode=Clearinghouse)
# 4. Drop down `Station Hour`, drop down `District 4`
# 5. Select the `.gz` files for March, April, May, September, October, and November (typical months)
# 6. Drop down `Station Metadata`
# 7. Select the `.txt`  files for the typical months
#
# This script summarize hourly and time period specific typical weekday traffic characteristics. 
#
# This script builds `Rdata` annual databases.  See `Run Build Annual for All Years.R` for a controller script that runs this script repeatedly in batch mode. See `Build Database.Rmd` for the consolidation of these database into two databases that span years. 

## Overhead

### Libraries
library(reshape2)
suppressMessages(library(dplyr))
library(stringr)
library(timeDate)
library(chron)

### Command-line argument
# args <- commandArgs(trailingOnly = TRUE)
# YEAR_STRING = args[1]

### Remote file names
YEAR_STRING = "2016"
F_DATA_MAR = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/d04_text_station_hour_",YEAR_STRING,"_03.txt", sep = "")
F_DATA_APR = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/d04_text_station_hour_",YEAR_STRING,"_04.txt", sep = "")
F_DATA_MAY = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/d04_text_station_hour_",YEAR_STRING,"_05.txt", sep = "")
F_DATA_SEP = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/d04_text_station_hour_",YEAR_STRING,"_09.txt", sep = "")
F_DATA_OCT = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/d04_text_station_hour_",YEAR_STRING,"_10.txt", sep = "")
F_DATA_NOV = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/d04_text_station_hour_",YEAR_STRING,"_11.txt", sep = "")

# Representative data file for lats, longs, and post-miles
F_META  = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/d04_text_meta_",YEAR_STRING,".txt", sep = "")

F_OUTPUT_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/pems_hour_",YEAR_STRING,".Rdata", sep = "")
F_OUTPUT_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR_STRING,"/pems_period_",YEAR_STRING,".Rdata", sep = "")


### Parameters

# Share of sensor data that must be observed to be included
MIN_PCT_OBS = 100

# Default speed for locations with zero flow
DEFAULT_SPEED = 65.0

# Maximum flow for which a zero flow could be plausibly observed
MAX_FLOW_ZERO_PLAUSIBLE = 150.0

# Minimum number of days observed for estimates to be retained
MIN_DAYS_OBSERVED = 15

# Data frame of time periods
hour        = c(  0,    1,    2,    3,    4,    5,    6,    7,    8,    9,    
                  10,   11,   12,   13,   14,   15,   16,   17,   18,   19,   
                  20,   21,   22,   23)
time_period = c("EV", "EV", "EV", "EA", "EA", "EA", "AM", "AM", "AM", "AM", 
                "MD", "MD", "MD", "MD", "MD", "PM", "PM", "PM", "PM", "EV", 
                "EV", "EV", "EV", "EV")

time_per_df = data.frame(hour, time_period)

# Use the time period frame to get the number of hours in each time period
time_per_df_counts = as.data.frame(table(time_per_df$time_period))
time_per_df_counts <- select(time_per_df_counts, time_period = Var1, time_period_count = Freq)

# Relevant holidays database
holiday_list  <- c("USLaborDay", "USMemorialDay", "USThanksgivingDay", "USVeteransDay")
holiday_dates <- dates(as.character(holiday(2000:2025, holiday_list)), format = "Y-M-D")

## Methods 

### Extract clean data from raw data
Clean_Raw <- function(input_df){
  
  # give the variables standard names
  data.clean <- input_df %>%
    select(time_stamp_string = V1,
           station = V2,
           district = V3,
           route = V4,
           direction = V5,
           type = V6,
           length = V7,
           samples = V8,
           pct_obs = V9,
           flow = V10,
           occupancy = V11,
           speed = V12,
           delay_35 = V13,
           delay_40 = V14,
           delay_45 = V15,
           delay_50 = V16,
           delay_55 = V17,
           delay_60 = V18,
           flow_1 = V19,
           occ_1 = V20,
           speed_1 = V21,
           flow_2 = V22,
           occ_2 = V23,
           speed_2 = V24,
           flow_3 = V25,
           occ_3 = V26,
           speed_3 = V27,
           flow_4 = V28,
           occ_4 = V29,
           speed_4 = V30,
           flow_5 = V31,
           occ_5 = V32,
           speed_5 = V33,
           flow_6 = V34,
           occ_6 = V35,
           speed_6 = V36,
           flow_7 = V37,
           occ_7 = V38,
           speed_7 = V39,
           flow_8 = V40,
           occ_8 = V41,
           speed_8 = V42)
  
  # Filters and transformations
  data.clean <- data.clean %>%
    filter(pct_obs >= MIN_PCT_OBS) %>%
    mutate(date = as.Date(time_stamp_string, format = "%m/%d/%Y %H:%M:%S")) %>%
    mutate(hour = as.numeric(str_sub(as.character(time_stamp_string), 12, 13))) %>%
    mutate(day_of_week = weekdays(date)) %>%
    filter(day_of_week == "Tuesday" | day_of_week == "Wednesday" | day_of_week == "Thursday") %>%
    filter(!is.holiday(date, holiday_dates)) %>%
    mutate(lanes = 8) %>%
    mutate(lanes = ifelse(is.na(flow_8), 7, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_7), 6, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_6), 5, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_5), 4, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_4), 3, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_3), 2, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_2), 1, lanes)) %>%
    select(date, day_of_week, station, district, route, direction, type, hour, pct_obs, length, flow, speed, lanes, occupancy)
  
  return(data.clean)
  
}



## Data reads
data_mar <- read.csv(F_DATA_MAR, header = FALSE)
data_apr <- read.csv(F_DATA_APR, header = FALSE)
data_may <- read.csv(F_DATA_MAY, header = FALSE)

data_sep <- read.csv(F_DATA_SEP, header = FALSE)
data_oct <- read.csv(F_DATA_OCT, header = FALSE)
data_nov <- read.csv(F_DATA_NOV, header = FALSE)

data_meta <- read.csv(F_META, header = TRUE, sep = "\t")



## Build Database
data_mar_clean <- Clean_Raw(data_mar)
data_apr_clean <- Clean_Raw(data_apr)
data_may_clean <- Clean_Raw(data_may)

data_sep_clean <- Clean_Raw(data_sep)
data_oct_clean <- Clean_Raw(data_oct)
data_nov_clean <- Clean_Raw(data_nov)

data_clean <- rbind(data_mar_clean, data_apr_clean, data_may_clean, data_sep_clean, data_oct_clean, data_nov_clean)


## Data Summaries

# Join with time_periods and time_period_counts
data_clean <- left_join(data_clean, time_per_df, by = c("hour"))

# First summaries by hour
data_sum_hour <- data_clean %>%
  group_by(station, district, route, direction, type, hour, lanes) %>%
  summarise(median_flow  = median(flow),      avg_flow  = mean(flow),      sd_flow      = sd(flow), max_flow = max(flow), min_flow = min(flow), 
            median_speed = median(speed),     avg_speed = mean(speed),     sd_speed     = sd(speed),
            median_occup = median(occupancy), avg_occup = mean(occupancy), sd_occupancy = sd(occupancy))

# Use max and min to locate suspect data 
suspect_stations_df <- data_sum_hour %>%
  mutate(suspect_station = ifelse(max_flow > MAX_FLOW_ZERO_PLAUSIBLE & min_flow == 0L, TRUE, FALSE)) %>%
  select(station, district, route, direction, type, hour, lanes, suspect_station)

data_clean_suspect <- left_join(data_clean, suspect_stations_df, by = c("station", "district", "route", "direction", "type", "hour", "lanes"))
data_clean_suspect <- data_clean_suspect %>%
  filter(!(suspect_station & flow < 1))

# Second summaries by hour
data_sum_hour <- data_clean_suspect %>%
  group_by(station, district, route, direction, type, hour, lanes) %>%
  summarise(median_flow  = median(flow),      avg_flow  = mean(flow),      sd_flow      = sd(flow), 
            median_speed = median(speed),     avg_speed = mean(speed),     sd_speed     = sd(speed),
            median_occup = median(occupancy), avg_occup = mean(occupancy), sd_occupancy = sd(occupancy),
            days_observed = n()) %>%
  filter(days_observed > MIN_DAYS_OBSERVED)

# Summaries by time-period 
data_sum_period <- data_clean_suspect %>%
  mutate(speed_flow = speed * flow) %>%
  mutate(occup_flow = occupancy * flow) %>%
  group_by(date, station, district, route, direction, type, time_period, lanes) %>%
  summarise(flow = sum(flow), speed_flow = sum(speed_flow), occup_flow = sum(occup_flow), hours_observed = n())

data_sum_period <- left_join(data_sum_period, time_per_df_counts, by = c("time_period"))

data_sum_period <- data_sum_period %>%
  filter(hours_observed == time_period_count) %>%
  mutate(speed = ifelse(flow > 0, speed_flow / flow, DEFAULT_SPEED)) %>%
  mutate(occupancy = ifelse(flow > 0, occup_flow / flow, 0.0)) %>%
  group_by(station, district, route, direction, type, time_period, lanes) %>%
  summarise(median_flow  = median(flow),      avg_flow  = mean(flow),      sd_flow      = sd(flow), 
            median_speed = median(speed),     avg_speed = mean(speed),     sd_speed     = sd(speed),
            median_occup = median(occupancy), avg_occup = mean(occupancy), sd_occupancy = sd(occupancy),
            days_observed = n()) %>%
  filter(days_observed > MIN_DAYS_OBSERVED)



## Write to disk

# Join the meta-data
data_meta <- data_meta %>%
  select(station = ID, district = District, route = Fwy, direction = Dir, type = Type,
         state_pm = State_PM, abs_pm = Abs_PM, latitude = Latitude, longitude = Longitude)

data_sum_hour_write   <- left_join(data_sum_hour, data_meta,   by = c("station","district","route","direction","type"))
data_sum_period_write <- left_join(data_sum_period, data_meta, by = c("station","district","route","direction","type"))

data_sum_hour_write <- data_sum_hour_write %>%
  mutate(year = as.numeric(YEAR_STRING))

data_sum_period_write <- data_sum_period_write %>%
  mutate(year = as.numeric(YEAR_STRING))

save(data_sum_hour_write, file = F_OUTPUT_HOUR_R)
save(data_sum_period_write, file = F_OUTPUT_PERIOD_R)


