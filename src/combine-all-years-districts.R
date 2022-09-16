# Reads all the hours and period summaries files from data directory
# (these are by district and year) and combines into a single hour and period file.
#
# Outputs to a single 
#   - pems_hour.[RDS,Rdata]
#   - pems_period.[RDS,Rdata]
#

library(dplyr)

# I/O
OUTPUT_DATA_DIR <- "../data"     # hourly and period summaries (by district, year) written here

file_list <-  list.files(path=OUTPUT_DATA_DIR)

hour_df   <- tibble()
period_df <- tibble()

for (file_idx in 1:length(file_list)) {
    file_name <- file_list[file_idx]

    if (startsWith(file_name,'pems_hour_d')) {
        this_hour_df <- readRDS(file.path(OUTPUT_DATA_DIR, file_name))
        hour_df <- rbind(hour_df, this_hour_df)
        print(sprintf('Read %s; hour_df has %8d rows', file_name, nrow(hour_df)))
    }
    if (startsWith(file_name,'pems_period_d')) {
        this_period_df <- readRDS(file.path(OUTPUT_DATA_DIR, file_name))
        period_df <- rbind(period_df, this_period_df)
        print(sprintf('Read %s; period_df has %8d rows', file_name, nrow(period_df)))
    }
}

# these are big -- do not commit!

# Write as Rdata (for tableau)
hour_output_file <- file.path(OUTPUT_DATA_DIR, 'pems_hour.RData')
save(hour_df, file=hour_output_file)
print(paste('Wrote',hour_output_file))

period_output_file <- file.path(OUTPUT_DATA_DIR, 'pems_period.RData')
save(period_df, file=period_output_file)
print(paste('Wrote',period_output_file))

# Write as RDS
hour_output_file <- file.path(OUTPUT_DATA_DIR, 'pems_hour.RDS')
saveRDS(hour_df, hour_output_file)
print(paste('Wrote',hour_output_file))

period_output_file <- file.path(OUTPUT_DATA_DIR, 'pems_period.RDS')
saveRDS(period_df, period_output_file)
print(paste('Wrote',period_output_file))
