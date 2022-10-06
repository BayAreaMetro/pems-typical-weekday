# Reads all the hours and period summaries files from data directory
# (these are by district and year) and combines into a single hour and period file.
#
# Outputs to a single 
#   - pems_hour.[RDS,Rdata,csv]
#   - pems_period.[RDS,Rdata,csv]
#   - pems_truck_hour.[RDS,Rdata,csv]
#   - pems_truck_period.[RDS,Rdata,csv

library(dplyr)

# I/O
OUTPUT_DATA_DIR <- "../data"     # hourly and period summaries (by district, year)
file_list <-  list.files(path=OUTPUT_DATA_DIR)

tibble_list <- list(
    pems_hour_d         = tibble(),
    pems_period_d       = tibble(),
    pems_truck_hour_    = tibble(),
    pems_truck_period_  = tibble()
)

for (file_idx in 1:length(file_list)) {
    file_name <- file_list[file_idx]

    for(prefix in names(tibble_list)) {
      if (startsWith(file_name,prefix)) {
        this_df <- readRDS(file.path(OUTPUT_DATA_DIR, file_name))
        tibble_list[[prefix]] <- rbind(tibble_list[[prefix]], this_df)
        print(sprintf('Read %s; %s has %8d rows', 
                      file_name, prefix, nrow(tibble_list[[prefix]])))
        # continue in the loop
        next
      }
    }
}

# these are big -- do not commit!
for(prefix in names(tibble_list)) {
  output_file <- file.path(OUTPUT_DATA_DIR, prefix)
  # drop the '_d'
  if (endsWith(prefix,'_d')) {
    output_file <- substr(output_file, 0, nchar(output_file)-2)
  }
  else if (endsWith(prefix,'_')) {
     output_file <- substr(output_file, 0, nchar(output_file)-1)
  }

  tibble_to_save <- tibble_list[[prefix]]

  # Write as Rdata (for tableau)
  save(tibble_to_save, file=paste0(output_file,".Rdata"))
  print(paste('Wrote',paste0(output_file,".Rdata")))

  # Write as RDS
  saveRDS(tibble_to_save, paste0(output_file,".RDS"))
  print(paste('Wrote',paste0(output_file,".RDS")))

  # write as CSV
  write.csv(tibble_to_save, paste0(output_file,".csv"), row.names=FALSE)
  print(paste('Wrote',paste0(output_file,".csv")))
}
