
# Remote I/O
interim_dir <- "../data/interim/"

input_hour_filename <- paste0(interim_dir, "pems_hour.RData")
input_period_filename <- paste0(interim_dir, "pems_period.RData")

output_hour_filename <- paste0(interim_dir, "mtc_pems_hour.RDS")
output_period_filename <- paste0(interim_dir, "mtc_pems_period.RDS")

# Write
load(input_hour_filename)
load(input_period_filename)

saveRDS(hour_all, output_hour_filename)
saveRDS(period_all, output_period_filename)
