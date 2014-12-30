# Build Database
#
## Administration
# 
### Purpose
# `Build Annual Database.Rmd` creates two year-specific databases of typical weekday PeMS traffic data.  One database has hourly summaries and the other has time-period summaries.  This script combines these databases across years and writes out a two consolidated databases in `Rdata` and `CSV` format. 
# 
### _ISSUES_
# 1. 
# 
### _TODO_
# 7.  Put hourly in SQL server --> tableau


## Overhead

### Remote file names

# Year 2005 data
YEAR = 2005
F_2005_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2005_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2006 data
YEAR = 2006
F_2006_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2006_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2007 data
YEAR = 2007
F_2007_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2007_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2008 data
YEAR = 2008
F_2008_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2008_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2009 data
YEAR = 2009
F_2009_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2009_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2010 data
YEAR = 2010
F_2010_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2010_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2011 data
YEAR = 2011
F_2011_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2011_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2012 data
YEAR = 2012
F_2012_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2012_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2013 data
YEAR = 2013
F_2013_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2013_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Year 2014 data
YEAR = 2014
F_2014_HOUR_R   = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_hour_",YEAR,".Rdata", sep = "")
F_2014_PERIOD_R = paste("M:/Data/Traffic/PeMS/",YEAR,"/pems_period_",YEAR,".Rdata", sep = "")

# Ouput 
F_OUTPUT_HOUR_R   = "D:/files/My Box Files/Share Data/pems-typical-weekday/pems_hour.Rdata"
F_OUTPUT_HOUR_CSV = "D:/files/My Box Files/Share Data/pems-typical-weekday/pems_hour.csv"

F_OUTPUT_PERIOD_R   = "D:/files/My Box Files/Share Data/pems-typical-weekday/pems_period.Rdata"
F_OUTPUT_PERIOD_CSV = "D:/files/My Box Files/Share Data/pems-typical-weekday/pems_period.csv"

## Bind and Write

# Hour data
load(F_2005_HOUR_R)
hour_2005 <- data_sum_hour_write

load(F_2006_HOUR_R)
hour_2006 <- data_sum_hour_write

load(F_2007_HOUR_R)
hour_2007 <- data_sum_hour_write

load(F_2008_HOUR_R)
hour_2008 <- data_sum_hour_write

load(F_2009_HOUR_R)
hour_2009 <- data_sum_hour_write

load(F_2010_HOUR_R)
hour_2010 <- data_sum_hour_write

load(F_2011_HOUR_R)
hour_2011 <- data_sum_hour_write

load(F_2012_HOUR_R)
hour_2012 <- data_sum_hour_write

load(F_2013_HOUR_R)
hour_2013 <- data_sum_hour_write

load(F_2014_HOUR_R)
hour_2014 <- data_sum_hour_write

hour_all <- rbind(hour_2005, hour_2006, hour_2007, hour_2008, hour_2009, hour_2010, hour_2012, hour_2013, hour_2014)

save(hour_all, file = F_OUTPUT_HOUR_R)
write.csv(hour_all, file = F_OUTPUT_HOUR_CSV, row.names = FALSE, quote = T)

# Period data
load(F_2005_PERIOD_R)
period_2005 <- data_sum_period_write

load(F_2006_PERIOD_R)
period_2006 <- data_sum_period_write

load(F_2007_PERIOD_R)
period_2007 <- data_sum_period_write

load(F_2008_PERIOD_R)
period_2008 <- data_sum_period_write

load(F_2009_PERIOD_R)
period_2009 <- data_sum_period_write

load(F_2010_PERIOD_R)
period_2010 <- data_sum_period_write

load(F_2011_PERIOD_R)
period_2011 <- data_sum_period_write

load(F_2012_PERIOD_R)
period_2012 <- data_sum_period_write

load(F_2013_PERIOD_R)
period_2013 <- data_sum_period_write

load(F_2014_PERIOD_R)
period_2014 <- data_sum_period_write

period_all <- rbind(period_2005, period_2006, period_2007, period_2008, period_2009, period_2010, period_2011, period_2012, period_2013, period_2014)

save(period_all, file = F_OUTPUT_PERIOD_R)
write.csv(period_all, file = F_OUTPUT_PERIOD_CSV, row.names = FALSE, quote = T)


