USAGE <- "
 Pass -h for help on usage.

 Aggregates PeMS downloaded data files into monthly and annual summaries.
 Given a year (or multiple years) and Caltrans district (or multiple districts),
 this script does the following: 
  1) Reads the meta data for the district/year
  2) For all months, reads the station_hour data 
     from M:/Data/Traffic/PeMS/[year]/d[district]_text_station_hour_[year]_[month].txt or
          M:/Data/Traffic/PeMS/[year]/original_zipped/d[district]_text_station_hour_[year]_[month].txt.gz
  3) Filters to only rows with pct_obs >= MIN_PCT_OBS
     Filters to only typical weekdays (Tuesday, Wednesay and Thursday),
     Filters out holidays
  4) Flags/filters some rows as suspect if min_flow==0 and max_flow > MAX_FLOW_ZERO_PLAUSIBLE

  Writes the following output files:
  1) ../data/pems_hour_d[district]_[year].RDS
  2) ../data/pems_period_d[district]_[year].RDS
  3) ../data/pems_hour_month_d[district]_[year].RDS
  4) M:/Data/Traffic/PeMS/suspect_stations_debug/suspect_stations_[year]_[district]_[allmonths,typicalmonths].csv

  All three files have columns:
     station, district, route, direction, type, 
     [hour|time_period|hour,month,hour] -- these columns are present for output files 1-4) respectively
     lanes,
     [median,avg,sd]_flow
     [median,avg,sd]_speed
     [median,avg,sd]_occup
     days_observed
     state_pm, abs_pm, latitutde, longitude
     year
"

# Overhead
packages_vector <- c(
  "argparser",
  "tidyverse",
  "chron",
  "timeDate")

need_to_install <- packages_vector[!(packages_vector %in% installed.packages()[,"Package"])]

if (length(need_to_install)) install.packages(need_to_install)

for (package in packages_vector){
  suppressMessages(library(package, character.only = TRUE))
}

# I/O
SOURCE_DATA_DIR <- "M:/Data/Traffic/PeMS"  # raw data files are in here, in sub directories by year
OUTPUT_DATA_DIR <- "../data"     # hourly and period summaries (by district, year) written here

# Parameters
# year(s) and district(s) are now command-line arguments
argparser <- arg_parser(USAGE)
argparser <- add_argument(argparser, "--year",     help="Years to process",     type="numeric", nargs=Inf)
argparser <- add_argument(argparser, "--district", help="Districts to process", type="numeric", nargs=Inf)

# parse the command line arguments
argv <- parse_args(argparser)

typical_travel_month_array <- c(3, 4, 5, 9, 10, 11)
all_months <- c(1,2,3,4,5,6,7,8,9,10,11,12)

# Share of sensor data that must be observed to be included
MIN_PCT_OBS = 100

# Default speed for locations with zero flow
DEFAULT_SPEED = 65.0

# Maximum flow for which a zero flow could be plausibly observed
MAX_FLOW_ZERO_PLAUSIBLE = 150.0

# Minimum number of days observed for estimates to be retained
MIN_DAYS_OBSERVED = 15
MIN_DAYS_OBSERVED_ONE_MONTH = 4

# Relevant holidays database
all_holidays_list  <- c('USNewYearsDay', 'USInaugurationDay', 'USMLKingsBirthday', 'USLincolnsBirthday', 'USWashingtonsBirthday', 'USMemorialDay', 'USIndependenceDay', 'USLaborDay', 'USColumbusDay', 'USElectionDay', 'USVeteransDay', 'USThanksgivingDay', 'USChristmasDay', 'USCPulaskisBirthday', 'USGoodFriday')
all_holidays_dates <- dates(as.character(holiday(2000:2025, all_holidays_list)), format = "Y-M-D")

# Make Time Periods Map
HOUR_TO_TIMEPERIOD_DF <- 
  tibble(hour = c(seq(0, 23)), 
  time_period = c(rep("EV", 3),
                  rep("EA", 3),
                  rep("AM", 4),
                  rep("MD", 5),
                  rep("PM", 4),
                  rep("EV", 5)))

TIMEPERIOD_COUNTS_DF <- select(as.data.frame(table(HOUR_TO_TIMEPERIOD_DF$time_period)), 
                             time_period = Var1, 
                             time_period_count = Freq)

HOUR_COLUMN_NAMES <- c(
  "time_stamp_string",
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
  "flow_1", "occ_1",  "speed_1",  
  "flow_2", "occ_2",  "speed_2",
  "flow_3", "occ_3",  "speed_3",
  "flow_4", "occ_4",  "speed_4",
  "flow_5", "occ_5",  "speed_5",
  "flow_6", "occ_6",  "speed_6",
  "flow_7", "occ_7",  "speed_7",
  "flow_8", "occ_8",  "speed_8"
)
  
HOUR_COLUMN_TYPES <- paste0(
  "c", # time_stamp_string
  "i", # station
  "i", # district
  "i", # route
  "c", # direction
  "c", # type
  "d", # length
  "i", # samples
  "i", # pct_obs
  paste0(replicate(33,"d"),collapse="")
)

# create named vector with name:class for read.table
HOUR_COLUMN_CLASSES <- strsplit(HOUR_COLUMN_TYPES,split="")[[1]]
HOUR_COLUMN_CLASSES <- setNames(HOUR_COLUMN_CLASSES, HOUR_COLUMN_NAMES)
HOUR_COLUMN_CLASSES <- replace(HOUR_COLUMN_CLASSES, HOUR_COLUMN_CLASSES=="c", "character")
HOUR_COLUMN_CLASSES <- replace(HOUR_COLUMN_CLASSES, HOUR_COLUMN_CLASSES=="i", "integer")
HOUR_COLUMN_CLASSES <- replace(HOUR_COLUMN_CLASSES, HOUR_COLUMN_CLASSES=="d", "double")
print("HOUR_COLUMN_CLASSES")
print(HOUR_COLUMN_CLASSES)

# Methods ----------------------------------------------------------------------

#' Check for meta data file, read it and return as a dataframe
consume_meta <- function(data_dir, district, year) {
  
  district_string <- sprintf("%02d", district)
  meta_file_vector <- list.files(path = file.path(data_dir, year), 
                                 pattern = paste0(district_string, "_text_meta_", year))
  stopifnot(length(meta_file_vector) > 0)
  meta_filename <- file.path(data_dir, year, meta_file_vector[1])
  df <- read_delim(meta_filename, delim = "\t", col_types = cols(.default = col_character()))
  print(paste("Read metadata from", meta_filename))
  # print(problems(df))
  return(df)
}

#' Read monthly data files (e.g., d[DD]_text_station_hour_[YYYY]_[MM].txt) and
#' return as a dataframe
consume_raw <- function(data_dir, district, year, month){
    
  district_string <- sprintf("%02d", district)
  month_string <- sprintf("%02d", month)
  
  filename <- paste0("d", district_string, "_text_station_hour_", year, "_", month_string, ".txt")
  # try unzipped first
  if (file.exists(file.path(data_dir, year, filename))) {
    df <- read_csv(file.path(data_dir, year, filename), col_names = HOUR_COLUMN_NAMES, col_types = HOUR_COLUMN_TYPES)
    print(paste("Read",nrow(df),"rows from",file.path(data_dir, year, filename)))
  } else {
    filename <- paste0(filename, ".gz")
    # try zipped version second
    if (file.exists(file.path(data_dir, year, "original_zipped", filename))) {
      df <- read.table(
        gzfile(file.path(data_dir, year, "original_zipped", filename)),
        sep = ",",
        col.names = HOUR_COLUMN_NAMES, 
        colClasses = HOUR_COLUMN_CLASSES)
      print(paste("Read",nrow(df),"rows from",file.path(data_dir, year, "original_zipped", filename)))
    }
    else {
      print(paste("Didn't find data for district:",district_string,", year:",year,", month:", month_string))
      return(data.frame())
    }
  }
  # print(problems(df))
  return(df)
}

#' Converts time_stamp_string to date/your/day_of_week
#' Filters to rows with pct_obs >= MIN_PCT_OBS
#' Filters out holidays and Weekends/Monday/Friday
#' Adds lanes column based on presence of flow data for lanes
clean_raw <- function(input_df){
  
  # print('clean_raw: input_df head:')
  # print(head(input_df))
  df <- input_df %>%
    filter(pct_obs >= MIN_PCT_OBS) %>%
    mutate(date = as.Date(time_stamp_string, format = "%m/%d/%Y %H:%M:%S")) %>%
    mutate(month = months(date)) %>%
    mutate(hour = as.numeric(str_sub(as.character(time_stamp_string), 12, 13))) %>%
    mutate(day_of_week = weekdays(date)) %>%
    filter(day_of_week == "Tuesday" | day_of_week == "Wednesday" | day_of_week == "Thursday") %>%
    filter(!is.holiday(date, all_holidays_dates)) %>%
    mutate(lanes = 8) %>%
    mutate(lanes = ifelse(is.na(flow_8), 7, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_7), 6, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_6), 5, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_5), 4, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_4), 3, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_3), 2, lanes)) %>%
    mutate(lanes = ifelse(is.na(flow_2), 1, lanes)) %>%
    select(date, month, day_of_week, station, district, route, direction, type, hour, 
           pct_obs, length, flow, speed, lanes, occupancy)
  return(df)
}

#' Flag some rows as "suspect' if there are flows that exceed MAX_FLOW_ZERO_PLAUSIBLE
#' when aggregated to station/hour and filter them out
remove_suspect <- function(input_df, suffix){

  sum_hour_df <- input_df %>%
    group_by(station, district, route, direction, type, hour, lanes, 
            # meta data
            state_pm, abs_pm, latitude, longitude) %>%
    summarise(median_flow  = median(flow),
              avg_flow     = mean(flow),
              sd_flow      = sd(flow),
              max_flow     = max(flow),
              min_flow     = min(flow),
              median_speed = median(speed),
              avg_speed    = mean(speed),
              sd_speed     = sd(speed),
              median_occup = median(occupancy),
              avg_occup    = mean(occupancy), 
              sd_occupancy = sd(occupancy),
              .groups      = "drop")
  
  suspect_stations_df <- sum_hour_df %>%
    mutate(suspect_station = ifelse(max_flow > MAX_FLOW_ZERO_PLAUSIBLE & min_flow == 0L, TRUE, FALSE))

  # write these for debugging
  suspect_file <- file.path(SOURCE_DATA_DIR, "suspect_stations_debug", paste0("suspect_stations_",suffix,".csv"))
  write.csv(filter(suspect_stations_df, suspect_station==TRUE), suspect_file, row.names=FALSE)
  print(paste("Wrote",nrow(filter(suspect_stations_df, suspect_station==TRUE)),"rows to",suspect_file))

  suspect_stations_df <- suspect_stations_df %>%
    select(station, district, route, direction, type, hour, lanes, suspect_station)
  
  return_df <- left_join(input_df, 
                         suspect_stations_df, 
                         by = c("station", "district", "route", "direction", "type", "hour", "lanes")) %>%
    filter(!(suspect_station & flow < 1))
  return(return_df)
  
}

#' Summarize given data frame to (station, district, route, direction, type, hour, lanes),
#' filtering to only rows with days_observed > MIN_DAYS_OBSERVED
#' Returns summary data frame
sum_for_hours <- function(input_df) {
  
  df <- input_df %>%
    group_by(station, district, route, direction, type, hour, lanes, 
             state_pm, abs_pm, latitude, longitude, year) %>%
    summarise(median_flow   = median(flow),
              avg_flow      = mean(flow),
              sd_flow       = sd(flow),
              median_speed  = median(speed),
              avg_speed     = mean(speed),
              sd_speed      = sd(speed),
              median_occup  = median(occupancy),
              avg_occup     = mean(occupancy),
              sd_occupancy  = sd(occupancy),
              days_observed = n(),
              .groups = "drop") %>%
    filter(days_observed > MIN_DAYS_OBSERVED)
  return(df)

}

#' Summarize given data frame to (station, district, route, direction, type, time period, lanes),
#' filtering to only rows with days_observed > MIN_DAYS_OBSERVED
#' Returns summary data frame
sum_for_periods <- function(input_df) {
  
  df <- left_join(input_df, HOUR_TO_TIMEPERIOD_DF, by=c("hour")) %>%
    mutate(speed_flow = speed * flow) %>%
    mutate(occup_flow = occupancy * flow) %>%
    group_by(date, station, district, route, direction, type, time_period, lanes,
             state_pm, abs_pm, latitude, longitude, year) %>%
    summarise(flow = sum(flow), 
              speed_flow = sum(speed_flow), 
              occup_flow = sum(occup_flow), 
              hours_observed = n(),
              .groups = "drop") %>%
    left_join(., TIMEPERIOD_COUNTS_DF, by = c("time_period")) %>%
    filter(hours_observed == time_period_count) %>%
    mutate(speed = ifelse(flow > 0, speed_flow / flow, DEFAULT_SPEED)) %>%
    mutate(occupancy = ifelse(flow > 0, occup_flow / flow, 0.0)) %>%
    group_by(station, district, route, direction, type, time_period, lanes,
             state_pm, abs_pm, latitude, longitude, year) %>%
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

#' Summarize given data frame to (station, district, route, direction, type, MONTH, hour, lanes)
#' filtering to only rows with days_observed > MIN_DAYS_OBSERVED_ONE_MONTH
#' Returns summary data frame
sum_for_hours_by_month <- function(input_df) {
  df <- input_df %>%
    group_by(station, district, route, direction, type, hour, month, lanes, length, 
             abs_pm, latitude, longitude, year) %>%
    summarise(median_flow   = median(flow),      
              avg_flow      = mean(flow),      
              sd_flow       = sd(flow), 
              median_speed  = median(speed),     
              avg_speed     = mean(speed),     
              sd_speed      = sd(speed),
              median_occup  = median(occupancy), 
              avg_occup     = mean(occupancy), 
              sd_occupancy  = sd(occupancy),
              days_observed = n(),
              .groups = "drop") %>%
    filter(days_observed > MIN_DAYS_OBSERVED_ONE_MONTH)
  return(df)

}

for (year in argv$year) {

  for (district in argv$district){
    
    # read meta data
    meta_df <- consume_meta(SOURCE_DATA_DIR, district, year)
    stopifnot(nrow(filter(meta_df, is.null(Latitude) | is.null(Longitude) | is.null(Abs_PM))) == 0)

    typical_months_df <- tibble()
    all_months_df <- tibble()

    for (month in all_months){
      #' wrap expression in try() to continue run in the event of data for months not being downloaded or available
      try({

        # print(paste("Consuming Year", year, "Month", month, "for District", district))
        raw_df <- consume_raw(SOURCE_DATA_DIR, district, year, month)
        # if no data found, continue
        if (nrow(raw_df) == 0) { next }
        clean_df <- clean_raw(raw_df)

        # keep all months
        all_months_df <- bind_rows(all_months_df, clean_df)
        # typical months
        if (month %in% typical_travel_month_array){
          typical_months_df <- bind_rows(typical_months_df, clean_df)
        }
        remove(raw_df, clean_df)
      })
    } # month
    
    # join with metadata
    join_meta_df <- meta_df %>%
    select(station   = ID, 
           district  = District, 
           route     = Fwy, 
           direction = Dir, 
           type      = Type,
           state_pm  = State_PM, 
           abs_pm    = Abs_PM, 
           latitude  = Latitude, 
           longitude = Longitude) %>%
    mutate(station   = as.integer(station),
           route     = as.integer(route),
           district  = as.integer(district),
           latitude  = as.double(latitude),
           longitude = as.double(longitude),
           year      = year)
    
    # inner_join because metadata is required
    typical_months_df <- inner_join(
      typical_months_df,
      join_meta_df,
      by = c("station","district","route","direction","type"))
    stopifnot(nrow(filter(typical_months_df, is.null(latitude) | is.null(longitude) | is.null(abs_pm))) == 0)

    all_months_df <- inner_join(
      all_months_df,
      join_meta_df,
      by = c("station","district","route","direction","type"))
    stopifnot(nrow(filter(all_months_df, is.null(latitude) | is.null(longitude) | is.null(abs_pm))) == 0)

    # summaries for typical months -- by hour and by period
    typical_months_df <- remove_suspect(typical_months_df, sprintf("%d_typical", year))
    annual_hourly_sum_df <- sum_for_hours(typical_months_df)
    annual_period_sum_df <- sum_for_periods(typical_months_df)

    stopifnot(nrow(filter(annual_hourly_sum_df, is.null(latitude) | is.null(longitude) | is.null(abs_pm))) == 0)
    stopifnot(nrow(filter(annual_period_sum_df, is.null(latitude) | is.null(longitude) | is.null(abs_pm))) == 0)

    # summary for all months -- by hour & month
    all_months_df <- remove_suspect(all_months_df, sprintf("%d_all", year))
    annual_hourly_sum_by_month_df <- sum_for_hours_by_month(all_months_df)

    # reorder columns to be consistent with before
    annual_hourly_sum_df <- relocate(annual_hourly_sum_df, state_pm, abs_pm, latitude, longitude, year, .after = last_col())
    annual_period_sum_df <- relocate(annual_period_sum_df, state_pm, abs_pm, latitude, longitude, year, .after = last_col())
  
    stopifnot(nrow(filter(annual_hourly_sum_df, is.null(latitude) | is.null(longitude) | is.null(abs_pm))) == 0)
    stopifnot(nrow(filter(annual_period_sum_df, is.null(latitude) | is.null(longitude) | is.null(abs_pm))) == 0)

    # write them
    output_hour_filename          <- file.path(OUTPUT_DATA_DIR, sprintf("pems_hour_d%02d_%d.RDS", district, year))
    output_period_filename        <- file.path(OUTPUT_DATA_DIR, sprintf("pems_period_d%02d_%d.RDS", district, year))
    output_hour_by_month_filename <- file.path(OUTPUT_DATA_DIR, sprintf("pems_hour_by_month_d%02d_%d.RDS", district, year))

    saveRDS(annual_hourly_sum_df, file = output_hour_filename)
    print(paste("Wrote",output_hour_filename))
  
    saveRDS(annual_period_sum_df, file = output_period_filename)
    print(paste("Wrote",output_period_filename))
    
    saveRDS(annual_hourly_sum_by_month_df, file = output_hour_by_month_filename)
    print(paste("Wrote",output_hour_by_month_filename))

  } # district
} # year
