pems-typical-weekday
====================

Generates typical weekday summaries of [Caltrans PeMS Data](http://pems.dot.ca.gov/).  For transportation planning purposes, we seek to understand "typical" traffic conditions, which we define here to occur Tuesdays, Wednesdays, and Thursdays in the months of March, April, May, September, October, and November.  Methods herein strive to process the PeMS data to inform estimates of typical weekday travel conditions over time.

<img src="./docs/DataFlowDiagram.png" width=800>

The scripts in `src` directory processes a year's worth of data and then combines the annual summaries into a single database.  The data is available in the `pems-typical-weekday` folder [on Box](https://mtcdrive.box.com/v/pems-typical-weekday).  The data is presented via Tableau (see the `.twb` files in the `Summaries` directory) both [**hourly dashboard**](https://public.tableau.com/app/profile/bayareametro/viz/PeMSTypicalWeekday-Hourly/StationFlows) and by (groups of hours) [**time period dashboard**](https://public.tableau.com/app/profile/bayareametro/viz/PeMSTypicalWeekday-ByTimePeriod/StationFlows).

To use the Tableau workbooks, first download the hourly or time period data files from the `pems-typical-weekday` folder [here](https://mtcdrive.box.com/v/pems-typical-weekday).  Then point the Tableau workbooks to local copies of the CSV file, rather than the data extract/csv my files point to (e.g., `M:\Data\Traffic\PeMS\pems_period.tde` or `E:/Box/Share Data/pems-typical-weekday/pems_period.csv`).

## Data Dictionary

Column | Description
------ | -------------
station | PeMS Station ID. An integer value that uniquely indenties the Station Metadata. Use this value to 'join' other PeMS clearinghouse files that contain Station Metadata.
Vehicle.Class (only in truck files) | Vehicle classification. Possible values: 1 = 0-8 ft, 2 = 8-20 ft, 3 = 2 Axle, 4T SU, 4 = Bus, 5 = 2 Axle,6T SU, 6 = 3 Axle SU, 7 = 4+ Axle SU, 8 = < 4 Axle ST, 9 = 5 Axle ST, 10 = 6+ Axle ST, 11 = < 5 Axle MT, 12 = 6 Axle MT, 13 = 7+ Axle MT, 14 = User-Def, 15 = Unknown
district | Caltrans district number.
route | Route number.
direction | Direction of travel. One of N, S, E, or W.
type | Lane type.  Possible values: CD = Coll/Dist.  CH = Conventional Highway.  FF = Freeway-Freeway Connector.  FR = Off Ramp.  HV = HOV. ML = Mainline. OR = On ramp.
lanes | Total number of lanes.
latitude | Station latitude.
longitude | Station longitude.
state_pm | State postmile.
abs_pm | Absolute postmile.
time_period | Time periods.  See [MTC model time periods](https://github.com/BayAreaMetro/modeling-website/wiki/TimePeriods)
year |
median_flow |
avg_flow |
sd_flow |
median_speed |
avg_speed |
sd_speed |
median_occup |
avg_occup |
sd_occupancy |
days_observed |
