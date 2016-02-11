pems-typical-weekday
====================

Typical Weekday Summaries of [Caltrans PeMS Data](http://pems.dot.ca.gov/).  For transportation planning purposes, we seek to understand "typical" traffic conditions, which we define here to occur Tuesdays, Wednesdays, and Thursdays in the months of March, April, May, September, October, and November.  Methods herein strive to process the PeMS data to inform estimates of typical weekday travel conditions over time.

The `Consume` directory processes a year's worth of data and then combines the annual summaries into a single database.  The data is available in the `pems-typical-weekday' folder [here](https://mtcdrive.box.com/share-data).  The data is presented via Tableau (see the `.Twb` files in the `Summaries` directory) both [hourly](http://analytics.mtc.ca.gov/foswiki/Main/PeMSFlowsAndSpeedsHour) and by (groups of hours) [time period](http://analytics.mtc.ca.gov/foswiki/Main/PeMSFlowsAndSpeeds). 

To use the Tableau workbooks, first download the hourly or time period data files from the `pems-typical-weekday` folder [here](https://mtcdrive.box.com/share-data).  Then point the Tableau workbooks to local copies of the CSV file, rather than the data extract/csv my files point to (e.g., `M:\Data\Traffic\PeMS\pems_period.tde` or `D:/files/Box Sync/Share Data/pems-typical-weekday/pems_period.csv`).

