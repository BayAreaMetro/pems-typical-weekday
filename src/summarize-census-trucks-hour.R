library(tidyverse)
library(chron)     # for dates()
library(timeDate)  # for holiday()
library(sf)        # for st_read()
library(lubridate) # for mdy_hms()

# I/O
SOURCE_DATA_DIR <- "M:/Data/Traffic/PeMS"  # raw data files are in here, in sub directories by year
OUTPUT_DATA_DIR <- "../data"     # hourly and period summaries (by district, year) written here

# mapping between county name, county fips code and 2-3 letter Caltrans county code
COUNTY_FIPS_NAME_ABBREV_FILE <- "M:/Data/Traffic/Caltrans/county_fips_name_abbrev.csv"

# From PeMS Field Specification
CENSUS_TRUCKS_HOUR_COLUMNS <- c(
  'Timestamp',
  'Census.Station.Identifier',
  'Census.Substation.Identifier',
  'Freeway.Identifier',
  'Freeway.Direction',
  'City.Identifier',
  'County.Identifier',
  'District.Identifier',
  'Absolute.Postmile',
  'Station.Type',
  'Census.Station.Set.ID',
  'Lane.Number',
  'Vehicle.Class', 
  'Vehicle.Count',
  'Average.Speed',
  'Violation.Count',
  'Violation.Codes',
  'Single.Axle.Count',
  'Tandem.Axle.Count',
  'Tridem.Axle.Count',
  'Quad.Axle.Count',
  'Aveage.Gross.Weight',
  'Gross.Weight.Distribution',
  'Average.Single.Weight',
  'Average.Tandem.Weight',
  'Average.Tridem.Weight',
  'Average.Quad.Weight',
  'Average.Vehicle.Length',
  'Vehicle.Length.Distribution',
  'Average.Tandem.Spacing',
  'Average.Tridem.Spacing',
  'Average.Quad.Spacing',
  'Average.Wheelbase',
  'Wheelbase.Distribution',
  'Total.Flex.ESAL.300',
  'Total.Flex.ESAL.285',
  'Total.Rigid.ESAL.300',
  'Total.Rigid.ESAL.285'
)

# From PeMS Field Specification
METADATA_LOCATION_COLUMNS = c(
  "Location.ID",
  "Segment.ID",
  "State.Postmile",
  "Absolute.Postmile",
  "Latitude",
  "Longitude",
  "Angle",
  "Name",
  "Abbrev",
  "Freeway.ID",
  "Freeway.Direction",
  "District.ID",
  "County.ID",
  "City.ID"
)

# Parameters
year_array     <- c(2014, 2015, 2016)
month_array    <- c(3, 4) # , 5, 9, 10, 11)

# Relevant holidays database - consistent with summarize-to-hour-and-timeperiod.R
holiday_list  <- c("USLaborDay", "USMemorialDay", "USThanksgivingDay", "USVeteransDay")
holiday_dates <- dates(as.character(holiday(2000:2025, holiday_list)), format = "Y-M-D")

# Make Time Periods Map - consistent with summarize-to-hour-and-timeperiod.R
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


# for now, this is the date fo which the relevant metadata lives
# but this isn't very flexible.
# In the future, could search for this file based on the census data date.
metadata_date <- as.Date("2008-10-08", format="%Y-%m-%d")

# Metadata (Location) ----------------------------------------------------------

metadata_zip_file <- file.path(SOURCE_DATA_DIR, 
                               as.integer(format(metadata_date, "%Y")), 
                               'original zipped',
                               sprintf('all_text_tmg_locations_%d_%02d_%02d.txt.gz',
                                       as.integer(format(metadata_date, "%Y")),
                                       as.integer(format(metadata_date, "%m")),
                                       as.integer(format(metadata_date, "%d"))))
metadata_locations <- read.table(gzfile(metadata_zip_file), 
                                 sep = ",", header = F, quote="", comment.char="",
                                 col.names=METADATA_LOCATION_COLUMNS)
metadata_locations <- mutate(metadata_locations, Abs.PM.str = sprintf("%.3f", Absolute.Postmile))
# rename columns to be consistent with truck data
metadata_locations <- rename(metadata_locations, 
  Freeway.Identifier = Freeway.ID,
  District.Identifier= District.ID,
  County.Identifier  = County.ID,
  City.Identifier    = City.ID)

# metadata will be joined on these so make sure they're unique
# Note that Location.ID, Segment.ID, and Name are not the same
metadata_locations <- group_by(metadata_locations, 
                               Freeway.Identifier,
                               Freeway.Direction,
                               District.Identifier,
                               County.Identifier,
                               Abs.PM.str) %>%
  summarise(
    Location.ID         = paste(unique(Location.ID), collapse = "|"),
    Segment.ID          = paste(unique(Segment.ID), collapse="|"),
    Name                = paste(unique(Name), collapse="|"),
    State.Postmile      = paste(unique(State.Postmile), collapse="|"),
    Latitude            = first(Latitude),  # unique but float
    Longitude           = first(Longitude), # unique but float
    Angle               = first(Angle),     # unique but float
    .groups             = "drop")

# Summarize by hour and time period --------------------------------------------

#' similar to summarize-to-hour-and-timeperiod.R:sum_for_hours()
#' Summarizes vehicle counts to hourly flows and returns.
#' Does no filtering presently
summarize_for_hours <- function(input_df) {
  df <- group_by(input_df,
                 Census.Station.Identifier,
                 Census.Substation.Identifier,
                 Freeway.Identifier,
                 Freeway.Direction,
                 City.Identifier,
                 County.Identifier,
                 District.Identifier,
                 Absolute.Postmile,
                 Station.Type,
                 Vehicle.Class,
                 year, hour) %>%
    summarise(
      lanes         = n_distinct(Lane.Number),
      median_flow   = median(Vehicle.Count),
      avg_flow      = mean(Vehicle.Count),
      sd_flow       = sd(Vehicle.Count),
      days_observed = n(),
      .groups       = "drop")
  
  return(df)
}

#' Similar to summarize-to-hour-and-timeperiod.R:sum_for_periods()
summarize_for_periods <- function(input_df) {
  # summarize to time period per day
  df <- group_by(input_df,
                 Census.Station.Identifier,
                 Census.Substation.Identifier,
                 Freeway.Identifier,
                 Freeway.Direction,
                 City.Identifier,
                 County.Identifier,
                 District.Identifier,
                 Absolute.Postmile,
                 Station.Type,
                 Vehicle.Class,
                 year, month, mday, time_period) %>%
    summarise(
      lanes          = n_distinct(Lane.Number),
      flow           = sum(Vehicle.Count), 
      hours_observed = n(),
      .groups        = "drop") %>%
    # check that time period is complete
    left_join(., time_per_counts_df, by = c("time_period"))
  
  # check that all hours observed for all lanes and log/drop incomplete
  df <- mutate(df, all_hours_lanes_observed=(hours_observed == lanes*time_period_count))
  print(sprintf("summarize_for_periods: %d out of %d rows (%.1f%%) missing data for all lanes/all hours in the time period; dropping", 
                nrow(df)-sum(df$all_hours_lanes_observed),
                nrow(df),
                100*(nrow(df)-sum(df$all_hours_lanes_observed))/nrow(df)))
  df <- filter(df, all_hours_lanes_observed == TRUE)

  df <- group_by(df,
                 Census.Station.Identifier,
                 Census.Substation.Identifier,
                 Freeway.Identifier,
                 Freeway.Direction,
                 City.Identifier,
                 County.Identifier,
                 District.Identifier,
                 Absolute.Postmile,
                 Station.Type,
                 Vehicle.Class,
                 lanes,
                 year, time_period) %>%
    summarise(median_flow   = median(flow),      
              avg_flow      = mean(flow),      
              sd_flow       = sd(flow),
              days_observed = n(),
              .groups = "drop")
  return(df)
}

#' Given a truck census data frame, figures out the census station locations
#' and returns a dataframe with location information
get_truck_census_locations <- function(truck_census_for_year) {
  
  # Create a table of sensors, their Census Identifiers, and the PM point
  truck_census_locations <- select(truck_census_for_year,
                                   Census.Station.Identifier, 
                                   Census.Substation.Identifier, 
                                   Freeway.Identifier, 
                                   Freeway.Direction, 
                                   District.Identifier,
                                   County.Identifier,
                                   Absolute.Postmile) %>% 
    distinct() %>% # drop duplicates
    as_tibble()
  # for cleaner joining, convert postmile to a string
  truck_census_locations <- mutate(truck_census_locations,
                                   Abs.PM.str = sprintf("%.3f", Absolute.Postmile))
  # read county mapping
  county_fips_name_abbrev <- read_csv(COUNTY_FIPS_NAME_ABBREV_FILE)
  
  # join to truck_census_locations
  truck_census_locations <- left_join(x=truck_census_locations,
                                      y=county_fips_name_abbrev,
                                      by=c("County.Identifier"="County.FIPS"))
  # verify all have a County Name
  stopifnot(sum(is.na(truck_census_locations["County.Name"]))==0)
  
  
  # left join truck_census_locations to postmile
  truck_census_locations <- left_join(x=truck_census_locations, 
                                      y=metadata_locations,
                                      by=c("Freeway.Identifier",
                                           "Freeway.Direction",
                                           "District.Identifier",
                                           "County.Identifier",
                                           "Abs.PM.str"))
  
  # print(paste("truck census locations missing latitude:",sum(is.na(truck_census_locations["Latitude"]))))
  stopifnot(sum(is.na(truck_census_locations["Latitude"])) == 0)
  
  # return just the join columns + 
  #  County.Name, County.Abbreviation, Location.ID, Segment.ID, State.Postmile, Latitude, Longitude, Angle, Name
  truck_census_locations <- select(truck_census_locations,
                                   Freeway.Identifier,
                                   Freeway.Direction,
                                   District.Identifier,
                                   County.Identifier,
                                   Abs.PM.str,
                                   # from metadata
                                   County.Name, 
                                   County.Abbreviation,
                                   Location.ID,
                                   Segment.ID,
                                   State.Postmile,
                                   Latitude,
                                   Longitude,
                                   Angle,
                                   Name)
  return(truck_census_locations)
}


# Read Census Trucks Hourly data -----------------------------------------------

for (year in year_array) {
  
  truck_census_for_year <- tibble()
  
  # iterate through the "typical weekdays" in this year;
  # this is necessary because the files are daily
  for (month in month_array){
      
    date_array <- seq(from=as.Date(paste0(year,"/",month,"/1")), by="day", length.out=32)
    for (idx in seq_along(date_array)) {
      date = date_array[idx] # Date instance
      day_of_week = weekdays(date)
        
      # if we overshot the month, break
      if (as.integer(format(date, "%m")) != month) { break }
        
      # if it's not a mid-day weekday, skip
      if (day_of_week != "Tuesday" & day_of_week != "Wednesday" & day_of_week != "Thursday") { 
        next 
      }
        
      # if it's a holiday, skip
      if (is.holiday(date, holiday_dates)) {
        print(paste("skipping holiday",date,' (', day_of_week,')'))
        next
      }
        
      # look for the truck census file file, e.g. all_text_tmg_trucks_hour_2015_03_02.txt.gz
      mday <- as.integer(format(date, "%d"))
      truck_census_zip_file <- file.path(SOURCE_DATA_DIR, year, 'original zipped',
                                         sprintf('all_text_tmg_trucks_hour_%d_%02d_%02d.txt.gz',
                                                 year,month,mday))
      # processing this date
      print(sprintf("Processing %s (%9s) - %s", date, day_of_week, truck_census_zip_file))
    
      # check that the file exists
      if (!file.exists(truck_census_zip_file)) {
        stop(paste('File',truck_census_zip_file,'not found - aborting'))
      }
      
      # read directly from the zip file
      truck_census <- read.table(gzfile(truck_census_zip_file), 
                                 sep = ",", header = F,
                                 col.names=CENSUS_TRUCKS_HOUR_COLUMNS)

      # keep the first 15 columns -- through Average.Speed
      truck_census <- select(truck_census, CENSUS_TRUCKS_HOUR_COLUMNS[1:15])
      truck_census <- mutate(truck_census, 
                             Timestamp = mdy_hms(Timestamp),
                             year      = year(Timestamp),
                             month     = month(Timestamp),
                             mday      = mday(Timestamp),
                             hour      = hour(Timestamp))
      # join to time period
      truck_census <- left_join(truck_census, time_per_df, by=c("hour"))

      # accumulate to year
      truck_census_for_year <- rbind(truck_census_for_year, truck_census)
    }

  }
  # summarize to hour and time_period
  truck_census_hour        <- summarize_for_hours(truck_census_for_year)
  truck_census_time_period <- summarize_for_periods(truck_census_for_year)
  
  # get location data
  truck_census_locations   <- get_truck_census_locations(truck_census_for_year)
  
  # add location to summarized datasets
  truck_census_hour        <- left_join(truck_census_hour, truck_census_locations)
  truck_census_time_period <- left_join(truck_census_time_period, truck_census_locations)
  
  # write
  output_hour_filename   <- file.path(OUTPUT_DATA_DIR, sprintf("pems_truck_hour_%d.RDS", year))
  output_period_filename <- file.path(OUTPUT_DATA_DIR, sprintf("pems_truck_period_%d.RDS", year))

  saveRDS(truck_census_hour,        file = output_hour_filename)
  saveRDS(truck_census_time_period, file = output_period_filename)
  
}

