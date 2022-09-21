library(dplyr)
library(R.utils)
library(tidyverse)
library(sf)
library(sp)
library(proj4)
library(tidyr)

# Unzip .gz files
year <- 2015
data_dir <- paste("E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\Hourly Truck Data",
                  as.character(year), sep = "\\")
data_files <- list.files(data_dir)

gz_files <- data_files[grepl(".gz", data_files)]

for (i in  gz_files){
  gunzip(paste(data_dir, i, sep = "\\"))
}

# Open file for a single day
tb <- read.table(paste(data_dir, data_files[1], sep = "\\"), sep = ",", header = F)

colnames(tb) <- c('Timestamp', 'Census.Station.Identifier', 'Census.Substation.Identifier', 'Freeway.Identifier', 'Freeway.Direction', 'City.Identifier', 'County.Identifier', 'District.Identifier', 'Absolute.Postmile', 'Station.Type', 'Census.Station.Set.ID', 'Lane.Number', 'Vehicle.Class', 'Vehicle.Count', 'Average.Speed', 'Violation.Count', 'Violation.Codes', 'Single.Axle.Count', 'Tandem.Axle.Count', 'Tridem.Axle.Count', 'Quad.Axle.Count', 'Aveage.Gross.Weight', 'Gross.Weight.Distribution', 'Average.Single.Weight', 'Average.Tandem.Weight', 'Average.Tridem.Weight', 'Average.Quad.Weight', 'Average.Vehicle.Length', 'Vehicle.Length.Distribution', 'Average.Tandem.Spacing', 'Average.Tridem.Spacing', 'Average.Quad.Spacing', 'Average.Wheelbase', 'Wheelbase.Distribution', 'Total.Flex.ESAL.300', 'Total.Flex.ESAL.285', 'Total.Rigid.ESAL.300', 'Total.Rigid.ESAL.285')


# Hourly Census truck data is provided in single days instead of monthly values
# and includes all districts

# Filter to District 4, aggregate vehicle counts and append to monthly/annual 
# files

tb_count_agg <- data.frame(matrix(ncol = 15, nrow = 0))
colnames(tb_count_agg) <- c('Timestamp', 'date', 'hour', 'day_of_week', 'District.Identifier', 'Census.Station.Identifier', 'Census.Substation.Identifier', 'Freeway.Identifier', 'Freeway.Direction', 'County.Identifier', 'District.Identifier', 'Absolute.Postmile', 'Station.Type', 'Census.Station.Set.ID', 'Vehicle.Count')

for (i in 1:length(data_files)){
  tb <- read.table(paste(data_dir, data_files[i], sep = "\\"), sep = ",", header = F)
  
  colnames(tb) <- c('Timestamp', 'Census.Station.Identifier', 'Census.Substation.Identifier', 'Freeway.Identifier', 'Freeway.Direction', 'City.Identifier', 'County.Identifier', 'District.Identifier', 'Absolute.Postmile', 'Station.Type', 'Census.Station.Set.ID', 'Lane.Number', 'Vehicle.Class', 'Vehicle.Count', 'Average.Speed', 'Violation.Count', 'Violation.Codes', 'Single.Axle.Count', 'Tandem.Axle.Count', 'Tridem.Axle.Count', 'Quad.Axle.Count', 'Aveage.Gross.Weight', 'Gross.Weight.Distribution', 'Average.Single.Weight', 'Average.Tandem.Weight', 'Average.Tridem.Weight', 'Average.Quad.Weight', 'Average.Vehicle.Length', 'Vehicle.Length.Distribution', 'Average.Tandem.Spacing', 'Average.Tridem.Spacing', 'Average.Quad.Spacing', 'Average.Wheelbase', 'Wheelbase.Distribution', 'Total.Flex.ESAL.300', 'Total.Flex.ESAL.285', 'Total.Rigid.ESAL.300', 'Total.Rigid.ESAL.285')
  
  tb_d4 <- subset(tb, District.Identifier == 4)
  tb_clean <- tb_d4 %>%
  mutate(date = as.Date(Timestamp, format = "%m/%d/%Y %H:%M:%S")) %>%
  mutate(hour = as.numeric(str_sub(as.character(Timestamp), 12, 13))) %>%
  mutate(year = as.numeric(str_sub(as.character(Timestamp), 7, 10))) %>%
  mutate(day_of_week = weekdays(date)) %>%
  select(Timestamp, date, year, hour, day_of_week, District.Identifier, Census.Station.Identifier, Census.Substation.Identifier, Freeway.Identifier, Freeway.Direction, County.Identifier, District.Identifier, Absolute.Postmile, Station.Type, Census.Station.Set.ID, Vehicle.Count) 
  
  tb_clean_agg <- aggregate(Vehicle.Count~., tb_clean, FUN=sum)
  tb_count_agg <- rbind(tb_count_agg, tb_clean_agg)
}
tb_count_agg

write.csv(tb_count_agg, "E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\pems_truck_hour.csv")

# Use State postmile instead of lat/longs

postmile <- st_read(dsn = "E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\Postmile Data\\ds1901.gdb", layer = "ds1901")
postmile <- as.data.frame(postmile)
postmile$Direction <- gsub("B", "", postmile$Direction)

# Create a table of D4 sensors, their Census Identifiers, and the PM point

station_id_tb <- tb_count_agg %>% select(Census.Station.Identifier, 
                                  Census.Substation.Identifier, 
                                  Freeway.Identifier, 
                                  Freeway.Direction, 
                                  District.Identifier, 
                                  Absolute.Postmile)

station_id_tb <- station_id_tb[!duplicated(station_id_tb),]

shapes <- c()

for (i in 1:nrow(station_id_tb)){
  #station_red <- station_id_tb[i,]
  pm_red <- subset(postmile, Route == station_id_tb$Freeway.Identifier[i] & 
                     Direction == station_id_tb$Freeway.Direction[i])
  pm_red$PM_diff <- abs(pm_red$Odometer - station_id_tb$Absolute.Postmile[i])
  min_index <- which.min(pm_red$PM_diff)
  shapes <- append(shapes, pm_red$Shape[min_index])
}

shapes <- as.data.frame(st_coordinates(shapes))

station_id_tb <- cbind(station_id_tb, shapes)

# WRITE NAD 83 X,Y COORDS TO CSV AND CALCULATE LAT/LONG IN ARCGIS
#write.csv(station_id_tb, "E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\pems_truck_xy_lookup.csv")

# Pull in lat/long table and join to counts

latlong_lookup <- read.csv("E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\pems_truck_lat_long_lookup.csv")

latlong_lookup <- latlong_lookup %>% select(Census_Substation_Identifier, Lat, Long)
tb_count_agg <- left_join(tb_count_agg, latlong_lookup, by=c('Census.Substation.Identifier'='Census_Substation_Identifier'))
tb_count_agg

# Summarize by period

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

time_per_df_counts

tb_count_agg <- left_join(tb_count_agg, time_per_df, by=c('hour'))

tb_sum_period <- tb_count_agg %>%
  group_by(Census.Substation.Identifier, District.Identifier, Freeway.Identifier,
           Freeway.Direction, Absolute.Postmile, Station.Type,
           Lat, Long, time_period, year) %>%
  summarise(median_count = median(Vehicle.Count), avg_count = mean(Vehicle.Count))

# Change variable names to be runable by crosswalk_pems_to_TM.R
# station, district, route, direction, type, abs_pm, latitude, longitude, year

colnames(tb_sum_period) <- c('station', 'district', 'route', 'direction', 'abs_pm',
                             'type', 'latitude', 'longitude', 'time_period',
                             'year', 'median_count', 'avg_count')

tb_sum_period

#write.csv(tb_sum_period, "E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\pems_truck_period.csv")

# Pull in the results of crosswalk_pems_to_TM.R and join to the summary aggregate
# tables.
# Then join to the freight counts from 2015_TM152_NGF_04

model_data <- read.csv("L:\\Application\\Model_One\\NextGenFwys\\2015_TM152_NGF_04\\OUTPUT\\avgload5period_vehclasses.csv")
model_data$AB <- paste(model_data$a, model_data$b, sep = ", ")

hv_fields <- colnames(model_data)[grep("hv", colnames(model_data))]
sm_fields <- colnames(model_data)[grep("sm", colnames(model_data))]
sm_fields <- sm_fields[sm_fields != "smtropc"]

model_data <- model_data %>% select(AB, hv_fields, sm_fields)

pems_crosswalk <- read.csv("M:\\Crosswalks\\PeMSStations_TM1network\\crosswalk_truck_2015.csv")
pems_crosswalk$AB <- paste(pems_crosswalk$A, pems_crosswalk$B, sep = ", ")

# convert to long to break up period and vehicle class
model_data <- subset(model_data, AB %in% pems_crosswalk$AB)
model_data <- model_data %>% gather(period_class, model_vol, c(-AB))
model_data$time_period <- str_sub(model_data$period_class, 4, 5)
model_data$veh_class <- sub(".*_", "", model_data$period_class)
model_data <- model_data %>% select(-period_class)

# convert back to wide 
model_data <- model_data %>% spread(key = veh_class, value = model_vol)
model_data$vol_tot <- model_data$hv + model_data$hvt + model_data$sm + model_data$smt

model_data <- left_join(model_data, pems_crosswalk, by=c("AB"))
model_data <- model_data %>% select(-c(A, B, distlink, A_B, stationsonlink, district, route, type, abs_pm, latitude, longitude, direction))

#join to observed data
model_obs <- tb_sum_period %>% left_join(model_data, by = c("station"="station","time_period"="time_period"))
model_obs$abs_diff <- model_obs$avg_count - model_obs$vol_tot
model_obs$p_diff <- (model_obs$avg_count - model_obs$vol_tot)/model_obs$vol_tot*100
model_obs

#write.csv(model_obs, "L:\\Application\\Model_One\\NextGenFwys\\2015_TM152_NGF_04\\OUTPUT\\validation\\roadway\\pems_TM152_truck_period.csv")

# Join locations and stations config files to the D4 subset of data

stations_config <- read.table("E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\Hourly Truck Data\\2015\\metadata\\all_text_tmg_stations_2016_11_03.txt", sep = ",")
colnames(stations_config) <- c('Location.ID' , 'unknown', 'TMG.Station.ID' , 'Agency' , 'Primary.Purpose' , 'Sensor.Type' , 'Active' , 'Alias' , 'Created' , 'Creator')
stations_config <- stations_config %>% select(c('Location.ID','TMG.Station.ID'))

locations_config <- read.table("E:\\Box\\Modeling and Surveys\\Share Data\\pems-typical-weekday-trucks\\Hourly Truck Data\\2015\\metadata\\all_text_tmg_locations_2016_11_03.txt", sep = ",")
colnames(locations_config) <- c('Location.ID', 'Segment.ID', 'State.Postmile', 'Absolute.Postmile', 'Latitude', 'Longitude', 'Angle', 'Name', 'Abbrev', 'Freeway.ID', 'Freeway.Direction', 'District.ID', 'County.ID', 'City.ID')
locations_config <- locations_config %>% select(c('Location.ID', 'Segment.ID', 'State.Postmile', 'Absolute.Postmile', 'Latitude', 'Longitude'))

tb_d4 <- subset(tb, District.Identifier==4)
tb_d4 <- left_join(tb_d4, stations_config, by=c('Census.Station.Identifier'='Location.ID'))

left_join(tb_d4, locations_config, by=c('TMG.Station.ID'='Location.ID')) #Should be this one?

sum(tb_d4$TMG.Station.ID %in% locations_config$Location.ID) #None of the District 4 ID's match the locations ID's
