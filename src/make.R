
# Overhead
packages_vector <- c("tidyverse",
                     "chron")

need_to_install <- packages_vector[!(packages_vector %in% installed.packages()[,"Package"])]

if (length(need_to_install)) install.packages(need_to_install)

for (package in packages_vector){
  library(package, character.only = TRUE)
}

# Remote I/O
external_dir <- "../data/external/"
interim_dir <- "../data/interim/"
processed_dir <- "../data/processed/"

# use "" for none
existing_hour_to_bind_with_filename <- paste0(interim_dir, "mtc_pems_hour.RDS")
existing_period_to_bind_with_filename <- paste0(interim_dir, "mtc_pems_period.RDS")

output_hour_filename <- paste0(processed_dir, "pems_hour.RDS")
output_period_filename <- paste0(processed_dir, "pems_period.RDS")

# Parameters
year_array <- c(2018, 2019)
district_array <- c(3, 5, 10)
month_array <- c(3, 4, 5, 9, 10, 11)

# Share of sensor data that must be observed to be included
MIN_PCT_OBS = 100

# Default speed for locations with zero flow
DEFAULT_SPEED = 65.0

# Maximum flow for which a zero flow could be plausibly observed
MAX_FLOW_ZERO_PLAUSIBLE = 150.0

# Minimum number of days observed for estimates to be retained
MIN_DAYS_OBSERVED = 15

HOUR_COLUMN_NAMES <- c("time_stamp_string",
                       "station",
                       "district",
                       "route",
                       "direction",
                       "type",
                       "length",
                       "samples",
                       "pct_obs",
                       "flow",
                       "occupancy",
                       "speed",
                       "delay_35",
                       "delay_40",
                       "delay_45",
                       "delay_50",
                       "delay_55",
                       "delay_60",
                       "flow_1",
                       "occ_1",
                       "speed_1",
                       "flow_2",
                       "occ_2",
                       "speed_2",
                       "flow_3",
                       "occ_3",
                       "speed_3",
                       "flow_4",
                       "occ_4",
                       "speed_4",
                       "flow_5",
                       "occ_5",
                       "speed_5",
                       "flow_6",
                       "occ_6",
                       "speed_6",
                       "flow_7",
                       "occ_7",
                       "speed_7",
                       "flow_8",
                       "occ_8",
                       "speed_8")

HOUR_COLUMN_TYPES <- paste0("c",
                            "i",
                            "i",
                            "i",
                            "c",
                            "c",
                            "d",
                            "i",
                            "i",
                            rep("d", 33))

# Make Time Periods Map
time_per_df <- tibble(hour = c(seq(0, 23)), 
                      time_period = c(rep("EV", 3),
                                      rep("EA", 3),
                                      rep("AM", 4),
                                      rep("MD", 5),
                                      rep("PM", 4),
                                      rep("EV", 5)))

time_per_counts_df <- select(as.data.frame(table(time_per_df$time_period)), 
                             time_period = Var1, 
                             time_period_count = Freq)

# Methods
consume_meta <- function(data_dir, district, year) {
  
  district_string <- sprintf("%02d", district)
  meta_file_vector <- list.files(path = data_dir, 
                                 pattern = paste0(district_string, "_text_meta_", year))
  stopifnot(length(meta_file_vector) > 0)
  meta_filename <- paste0(data_dir, meta_file_vector[1])
  df <- read_delim(meta_filename, delim = "\t", col_types = cols(.default = col_character()))
  
  return(df)
}

consume_raw <- function(data_dir, district, year, month){
  
  district_string <- sprintf("%02d", district)
  month_string <- sprintf("%02d", month)
  
  filename <- paste0(data_dir, "d", district_string, "_text_station_hour_", year, "_", month_string, ".txt")
  df <- read_csv(filename, col_names = HOUR_COLUMN_NAMES, col_types = HOUR_COLUMN_TYPES)
  
  return(df)
  
}

clean_raw <- function(input_df){
  
  df <- input_df %>%
    filter(pct_obs >= MIN_PCT_OBS) %>%
    mutate(date = as.Date(time_stamp_string, format = "%m/%d/%Y %H:%M:%S")) %>%
    mutate(hour = as.numeric(str_sub(as.character(time_stamp_string), 12, 13))) %>%
    mutate(day_of_week = weekdays(date)) %>%
    filter(day_of_week == "Tuesday" | day_of_week == "Wednesday" | day_of_week == "Thursday") %>%
    filter(!is.holiday(date)) %>%
    mutate(lanes = 8) %>%
    mutate(lanes = ifelse(is.na(flow_8), 7, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_7), 6, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_6), 5, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_5), 4, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_4), 3, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_3), 2, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_2), 1, lanes)) %>%
    select(date, day_of_week, station, district, route, direction, type, hour, 
           pct_obs, length, flow, speed, lanes, occupancy)
  
  return(df)
  
  
}

remove_suspect <- function(input_df, time_period_df){
  
  df <- left_join(input_df, time_per_df, by = c("hour"))
  
  sum_hour_df <- df %>%
    group_by(station, district, route, direction, type, hour, lanes) %>%
    summarise(median_flow = median(flow),      
              avg_flow = mean(flow),      
              sd_flow = sd(flow), 
              max_flow = max(flow), 
              min_flow = min(flow), 
              median_speed = median(speed),     
              avg_speed = mean(speed),     
              sd_speed = sd(speed),
              median_occup = median(occupancy), 
              avg_occup = mean(occupancy), 
              sd_occupancy = sd(occupancy),
              .groups = "drop")
  
  suspect_stations_df <- sum_hour_df %>%
    mutate(suspect_station = ifelse(max_flow > MAX_FLOW_ZERO_PLAUSIBLE & min_flow == 0L, TRUE, FALSE)) %>%
    select(station, district, route, direction, type, hour, lanes, suspect_station)
  
  return_df <- left_join(df, 
                         suspect_stations_df, 
                         by = c("station", "district", "route", "direction", "type", "hour", "lanes")) %>%
    filter(!(suspect_station & flow < 1))
  
  return(return_df)
  
}

sum_for_hours <- function(input_df) {
  
  df <- input_df %>%
    group_by(station, district, route, direction, type, hour, lanes) %>%
    summarise(median_flow = median(flow),      
              avg_flow = mean(flow),      
              sd_flow = sd(flow), 
              median_speed = median(speed),     
              avg_speed = mean(speed),     
              sd_speed = sd(speed),
              median_occup = median(occupancy), 
              avg_occup = mean(occupancy), 
              sd_occupancy = sd(occupancy),
              days_observed = n(),
              .groups = "drop") %>%
    filter(days_observed > MIN_DAYS_OBSERVED)
  
  return(df)

}

sum_for_periods <- function(input_df) {
  
  df <- input_df %>%
    mutate(speed_flow = speed * flow) %>%
    mutate(occup_flow = occupancy * flow) %>%
    group_by(date, station, district, route, direction, type, time_period, lanes) %>%
    summarise(flow = sum(flow), 
              speed_flow = sum(speed_flow), 
              occup_flow = sum(occup_flow), 
              hours_observed = n(),
              .groups = "drop") %>%
    left_join(., time_per_counts_df, by = c("time_period")) %>%
    filter(hours_observed == time_period_count) %>%
    mutate(speed = ifelse(flow > 0, speed_flow / flow, DEFAULT_SPEED)) %>%
    mutate(occupancy = ifelse(flow > 0, occup_flow / flow, 0.0)) %>%
    group_by(station, district, route, direction, type, time_period, lanes) %>%
    summarise(median_flow = median(flow),      
              avg_flow = mean(flow),      
              sd_flow = sd(flow), 
              median_speed = median(speed),     
              avg_speed = mean(speed),     
              sd_speed = sd(speed),
              median_occup = median(occupancy), 
              avg_occup = mean(occupancy), 
              sd_occupancy = sd(occupancy),
              days_observed = n(),
              .groups = "drop") %>%
    filter(days_observed > MIN_DAYS_OBSERVED)
  
  return(df)
  
}

write_annual_to_disk <- function(out_dir, input_hour_df, input_period_df, input_meta_df, input_year_int){
  
  join_meta_df <- input_meta_df %>%
    select(station = ID, 
           district = District, 
           route = Fwy, 
           direction = Dir, 
           type = Type,
           state_pm = State_PM, 
           abs_pm = Abs_PM, 
           latitude = Latitude, 
           longitude = Longitude) %>%
    mutate(station = as.integer(station),
           route = as.integer(route),
           district = as.integer(station),
           latitude = as.double(latitude),
           longitude = as.double(longitude))
  
  write_hour_df <- left_join(input_hour_df, 
                             join_meta_df,
                             by = c("station","district","route","direction","type")) %>%
    mutate(year = input_year_int)
  
  write_period_df <- left_join(input_period_df, 
                               join_meta_df,
                               by = c("station","district","route","direction","type")) %>%
    mutate(year = input_year_int)
  
  output_hour_filename <- paste0(out_dir, "pems_hour_", year, ".RDS")
  output_period_filename <- paste0(out_dir, "pems_period_", year, ".RDS")
  
  saveRDS(write_hour_df, file = output_hour_filename)
  saveRDS(write_period_df, file = output_period_filename)
  
  
}

# Reductions
across_years_hour_df <- tibble()
across_years_period_df <- tibble()

for (year in year_array) {
  
  across_districts_hour_df <- tibble()
  across_districts_period_df <- tibble()
  
  for (district in district_array){
    
    # read meta data
    meta_df <- consume_meta(external_dir, district, year)
    
    across_months_df <- tibble()
    
    for (month in month_array){
      
      print(paste0("Consuming Month ", month, ", Year ", year, " for District ", district))
      
      raw_df <- consume_raw(external_dir, district, year, month)
      clean_df <- clean_raw(raw_df)
      across_months_df <- bind_rows(across_months_df, clean_df)
      
      remove(raw_df, clean_df)
      
    } # month
    
    temp_df <- remove_suspect(across_months_df)
    annual_hourly_sum_df <- sum_for_hours(temp_df)
    annual_period_sum_df <- sum_for_periods(temp_df)
    
    remove(temp_df)
    
    across_districts_hour_df <- bind_rows(annual_hourly_sum_df, across_districts_hour_df)
    across_districts_period_df <- bind_rows(annual_period_sum_df, across_districts_period_df)
    
  } # district
  
  write_annual_to_disk(processed_dir, across_districts_hour_df, across_districts_period_df, meta_df, year)
  
  across_years_hour_df <- bind_rows(across_districts_hour_df, across_years_hour_df)
  across_years_period_df <- bind_rows(across_districts_period_df, across_years_period_df)
  
} # year


# Write to Disk
output_hour_df <- across_years_hour_df
output_period_df <- across_years_period_df

if (str_length(existing_hour_to_bind_with_filename) > 1){
  exist_df <- readRDS(existing_hour_to_bind_with_filename)
  output_hour_df <- bind_rows(exist_df, output_hour_df)
}

if (str_length(existing_period_to_bind_with_filename) > 1){
  exist_df <- readRDS(existing_period_to_bind_with_filename)
  output_period_df <- bind_rows(exist_df, output_period_df)
}

saveRDS(output_hour_df, output_hour_filename)
saveRDS(output_period_df, output_period_filename)
