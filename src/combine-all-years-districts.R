# Reads all the hours and period summaries files from data directory
# (these are by district and year) and combines into a single hour and period file.
#
# Outputs to a single 
#   - pems_hour.[RDS,Rdata,csv]
#   - pems_hour_by_month.[RDS,Rdata,csv]
#   - pems_period.[RDS,Rdata,csv]
#   - pems_truck_hour.[RDS,Rdata,csv]
#   - pems_truck_period.[RDS,Rdata,csv

library(dplyr)

# I/O
OUTPUT_DATA_DIR <- "../data"     # hourly and period summaries (by district, year)
file_list <-  list.files(path=OUTPUT_DATA_DIR)

prefix_list <- c(
  "pems_hour_d",
  "pems_hour_by_month_d",
  "pems_period_d",
  "pems_truck_hour_",
  "pems_truck_period_"
)

for(prefix in prefix_list) {

  tibble_for_prefix = tibble()
  file_list = list.files(path=OUTPUT_DATA_DIR, pattern=prefix)

  for (file_idx in 1:length(file_list)) {
    file_name <- file_list[file_idx]

    this_df <- readRDS(file.path(OUTPUT_DATA_DIR, file_name))
      
    # print(colnames(this_df))
    tibble_for_prefix <- rbind(tibble_for_prefix, this_df)

    print(sprintf('Read %s with %6d rows; total rows for all years: %8d', 
                  file_name, nrow(this_df), nrow(tibble_for_prefix)))
    # print(table(tibble_for_prefix$year, useNA="always"))
  }

  output_file <- file.path(OUTPUT_DATA_DIR, prefix)
  # drop the '_d'
  if (endsWith(prefix,'_d')) {
    output_file <- substr(output_file, 0, nchar(output_file)-2)
  }
  else if (endsWith(prefix,'_')) {
     output_file <- substr(output_file, 0, nchar(output_file)-1)
  }

  print("table for year:")
  print(table(tibble_for_prefix$year, useNA="always"))

  # these are big -- do not commit!
  # Write as Rdata (for tableau)
  save(tibble_for_prefix, file=paste0(output_file,".Rdata"))
  print(paste('Wrote',paste0(output_file,".Rdata")))

  # Write as RDS
  saveRDS(tibble_for_prefix, paste0(output_file,".RDS"))
  print(paste('Wrote',paste0(output_file,".RDS")))

  # write as CSV
  write.csv(tibble_for_prefix, paste0(output_file,".csv"), row.names=FALSE)
  print(paste('Wrote',paste0(output_file,".csv")))
}
