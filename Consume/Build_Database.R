# Build Database
#
## Administration
# 
### Purpose
# `Build Annual Database.R` creates two year-specific databases of typical weekday PeMS traffic data.  
#  One database has hourly summaries and the other has time-period summaries.  
#  This script combines these databases across years and writes out a two consolidated databases in `Rdata` and `CSV` format.
# 
### _ISSUES_
# 1. 
# 

## Parameters

### Relevant year strings
year_array = c(2005, 2006, 2007, 2008, 2009,
               2010, 2011, 2012, 2013, 2014,
               2015, 2016)

### Input file pieces
input_file_first = "M:/Data/Traffic/PeMS/"
input_file_third = "/pems"
input_file_sixth = ".Rdata"

### Output file names
F_OUTPUT_HOUR_R   = "~/../Box Sync/Share Data/pems-typical-weekday/pems_hour.Rdata"
F_OUTPUT_HOUR_CSV = "~/../Box Sync/Share Data/pems-typical-weekday/pems_hour.csv"

F_OUTPUT_PERIOD_R   = "~/../Box Sync/Share Data/pems-typical-weekday/pems_period.Rdata"
F_OUTPUT_PERIOD_CSV = "~/../Box Sync/Share Data/pems-typical-weekday/pems_period.csv"

## Hour reads and binds
time_period = "_hour_"

### initialize with 2005
year = 2005
input_file <- paste(input_file_first, year, input_file_third, time_period, year, input_file_sixth, sep = "")
load(input_file)
hour_all <- rbind(data_sum_hour_write)

hour_all <- hour_all %>%
  mutate(state_pm = as.numeric(state_pm))

### other years
for(year in year_array){
  
  if (year != 2005){
    input_file <- paste(input_file_first, year, input_file_third, time_period, year, input_file_sixth, sep = "")
    load(input_file)
    data_sum_hour_write <- data_sum_hour_write %>%
      mutate(state_pm = as.numeric(state_pm))
    hour_all <- rbind(hour_all, data_sum_hour_write)
  }
}

save(hour_all, file = F_OUTPUT_HOUR_R)
write.csv(hour_all, file = F_OUTPUT_HOUR_CSV, row.names = FALSE, quote = F) # SQL server does not like quotes

## Period reads and binds
time_period = "_period_"

### initialize with 2005
year = 2005
input_file <- paste(input_file_first, year, input_file_third, time_period, year, input_file_sixth, sep = "")
load(input_file)
period_all <- rbind(data_sum_period_write)
period_all <- period_all %>%
  mutate(state_pm = as.numeric(state_pm))

### other years
for(year in year_array){
  
  if (year != 2005){
    input_file <- paste(input_file_first, year, input_file_third, time_period, year, input_file_sixth, sep = "")
    load(input_file)
    data_sum_period_write <- data_sum_period_write %>%
      mutate(state_pm = as.numeric(state_pm))
    period_all <- rbind(period_all, data_sum_period_write)
  }
}

save(period_all, file = F_OUTPUT_PERIOD_R)
write.csv(period_all, file = F_OUTPUT_PERIOD_CSV, row.names = FALSE, quote = F) # SQL server does not like quotes

