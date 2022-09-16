# Reads all the hours and period summaries files from data directory
# (these are by district and year) and combines into a single hour and period file.
#
# Outputs to a single 
#   - pems_hour.[RDS,Rdata]
#   - pems_period.[RDS,Rdata]
#

library(dplyr)

# I/O
OUTPUT_DATA_DIR <- "../data"     # hourly and period summaries (by district, year)
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
hour_output_file   <- file.path(OUTPUT_DATA_DIR, 'pems_hour')    # suffix to be added below
period_output_file <- file.path(OUTPUT_DATA_DIR, 'pems_period')  # suffix to be added below

# Write as Rdata (for tableau)
save(hour_df, file=paste0(hour_output_file,".Rdata"))
print(paste('Wrote',paste0(hour_output_file,".Rdata")))

save(period_df, file=paste0(period_output_file,".Rdata"))
print(paste('Wrote',paste0(period_output_file,".Rdata")))

# Write as RDS
saveRDS(hour_df, paste0(hour_output_file,".RDS"))
print(paste('Wrote',paste0(hour_output_file,".RDS")))

saveRDS(period_df, paste0(period_output_file,".RDS"))
print(paste('Wrote',paste0(period_output_file,".RDS")))

# write as CSV
write.csv(hour_df, paste0(hour_output_file,".csv"), row.names=FALSE)
print(paste('Wrote',paste0(hour_output_file,".csv")))

write.csv(period_df, paste0(period_output_file,".csv"), row.names=FALSE)
print(paste('Wrote',paste0(period_output_file,".csv")))
