USAGE = '
 USAGE: Compares output from the previous process 
 (e.g., before https://github.com/BayAreaMetro/pems-typical-weekday/pull/3)
 with more recent output to understand how the process has changed

 Arguments: year
 Example: RScript --vanilla compare-aggregate-results-to-legacy.R 2018
'

library(dplyr)
library(stringr)

external_dir  <- "M:/Data/Traffic/PeMS"
processed_dir <- "../data/processed"

HOUR_INDEX_COLUMNS <- c("station","district","route","direction","type","hour","year")
PERIOD_INDEX_COLUMNS <- c("station","district","route","direction","type","time_period","year")


#' For all X.legacy/X.new columns, compare equality
compare_legacy_vs_new_columns <- function(df, INDEX_COLUMNS) {
  column_names   <- colnames(hour_merged_df)
  column_types   <- sapply(hour_merged_df, typeof)

  for (i in 1:length(column_names)) {
    column_name <- column_names[i]
  
    # compare legacy with new; skip others
    if (endsWith(column_name,".legacy") == FALSE) { next }
  
    column_type         <- column_types[i]
    new_column_name     <- str_replace(column_name, ".legacy", ".new")
    diff_column_name    <- str_replace(column_name, ".legacy", "diff")
    unequal_column_name <- str_replace(column_name, ".legacy", ".unequal")
    both_na_column_name <- str_replace(column_name, ".legacy", ".both_na")
    one_na_column_name  <- str_replace(column_name, ".legacy", ".one_na")
    
    hour_merged_df[diff_column_name]    <- abs(hour_merged_df[column_name] - hour_merged_df[new_column_name])
    hour_merged_df[both_na_column_name] <- is.na(hour_merged_df[column_name]) & is.na(hour_merged_df[new_column_name])
    hour_merged_df[one_na_column_name]  <- xor(is.na(hour_merged_df[column_name]), is.na(hour_merged_df[new_column_name]))
    
    # within margin of error
    hour_merged_df[unequal_column_name] <- abs(hour_merged_df[diff_column_name]) > 1e-5
    
    # print(head(select(hour_merged_df, c(INDEX_COLUMNS, column_name, new_column_name, diff_column_name, unequal_column_name))))
    
    print(sprintf('  Column %20s has type %8s and %6d unequal rows, %6d both-NA rows and %6d one-NA rows',
                  column_name, column_type,
                  sum(hour_merged_df[unequal_column_name], na.rm=TRUE), 
                  sum(hour_merged_df[both_na_column_name]), 
                  sum(hour_merged_df[one_na_column_name])))
  }
}

# Get year, district from arguments
args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  print(cat(USAGE))
  stop("Missing arguments")
}
YEAR     <- as.numeric(args[1])
DISTRICT <- 4 # legacy files are only for district 4

    
legacy_hour_file   <- file.path(external_dir, YEAR, paste0("pems_hour_",YEAR,".Rdata"))
legacy_period_file <- file.path(external_dir, YEAR, paste0("pems_period_",YEAR,".Rdata"))
    
hour_file   <- file.path(processed_dir, sprintf("pems_hour_d%02d_%d.RDS", DISTRICT, YEAR))
period_file <- file.path(processed_dir, sprintf("pems_period_d%02d_%d.RDS", DISTRICT, YEAR))
    
# read legacy files
load(legacy_hour_file)    # data_sum_hour_write
load(legacy_period_file)  # data_sum_period_write

# convert state_pm from factor to string to double
data_sum_hour_write <- mutate(data_sum_hour_write, state_pm = as.character(state_pm)) %>% 
  mutate(state_pm = as.numeric(state_pm))
data_sum_period_write <- mutate(data_sum_period_write, state_pm = as.character(state_pm)) %>%
  mutate(state_pm = as.numeric(state_pm))

# read non-legacy files
hour_df   <- readRDS(hour_file)
period_df <- readRDS(period_file)
    
# convert abs_pm and state_pm to double from string
hour_df <- mutate(hour_df, 
                  state_pm = as.numeric(state_pm),
                  abs_pm = as.numeric(abs_pm))
period_df <- mutate(period_df,
                    state_pm = as.numeric(state_pm),
                    abs_pm = as.numeric(abs_pm))
    
# create merged hour data frame and compare
hour_merged_df <- full_join(x     = data_sum_hour_write,
                            y     = hour_df,
                            by    = HOUR_INDEX_COLUMNS,
                            suffix= c(".legacy",".new"))
print('=== Comparing hour files ===')
print(paste('legacy: ',legacy_hour_file))
print(paste('   new: ',hour_file))

compare_legacy_vs_new_columns(hour_merged_df, HOUR_INDEX_COLUMNS)
    
# create merged period data frame and compare
period_merged_df <- full_join(x     = data_sum_period_write,
                              y     = period_df,
                              by    = PERIOD_INDEX_COLUMNS,
                              suffix= c(".legacy",".new"))
print('=== Comparing period files ===')
print(paste('legacy: ',legacy_period_file))
print(paste('   new: ',period_file))
compare_legacy_vs_new_columns(period_merged_df, PERIOD_INDEX_COLUMNS)
  