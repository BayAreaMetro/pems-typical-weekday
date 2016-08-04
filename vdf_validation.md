---
layout: page
title: Volume Delay Function Validation
---

# Volume Delay Function Validation
Travel models attempt to iteratively predict the demand for automobile travel and the resulting travel speed on roadway segments.  The estimation of travel demand is complex and, for MTC, described in detail [here](http://analytics.mtc.ca.gov/foswiki/Main/Development).  The estimation of travel speed is fairly straightforward and uses so-called "volume delay functions", which estimate congested travel speed as a function of each roadway's demand, free-flow speed, and effective capacity.  During MTC's *Travel Model One* development efforts, our legacy volume delay functions were retained.

The purpose of this memorandum is to investigate the reasonableness of the input assumptions which inform the volume delay functions as well as the shape of the volume delay curves themselves.  Data from the [Caltrans Performance Measurement System (PeMS) database](http://pems.dot.ca.gov/) is used in the analysis.

Travel model validation efforts often focus on comparing observed and estimate traffic volumes and point-to-point average speeds.  MTC's model validation efforts focus, instead, on observed and estimated traffic volumes and, the subject of this memorandum, the underlying assumptions that inform our volume delay functions.  By so doing, we ask: if the demand is correct, are the models capable of reliably predicting travel speed?  This approach should facilitate a more robust examination of our models ability to replicate travel speed than point-to-point average speed comparisons, which are confounded by differences in estimated and observed traffic flow.

## Background
MTC's *Travel Model One* uses a typical aggregate static user equilibrium assignment method to predict the routing of vehicles. This approach, which is nearly ubiquitous across regional modeling practice in the United States, makes several important assumptions, as follows:

* Demand on a roadway segment during a finite time interval can exceed roadway supply/effective capacity. For example, if 4,000 vehicles want to traverse a section of roadway that can only handle 3,000 vehicles, the model responds by predicting travel through the corridor will be very slow, but still possible.
* The delay resulting from high demand on a roadway segment is contained entirely within that segment (i.e., queues do not form at bottlenecks and cause upstream delay; rather, the bottleneck is contoined on the segment of roadway where the bottleneck occurs).
* An equilibrium condition is found shuch that now vehicles moving betveen any single origin/destination pair can achieve a substantially faster travel time by switching routes.

In the *Travel Model One* application, the demand and resulting congested conditions are described separately for five time periods which, when combined, encompass an entire typical weekday, as follows:

* early morning, 3 am to 6 am;
* morning commute, 6 am to 10 am;
* midday, 10 am to 3 pm;
* evening commute, 3 pm to 7 pm;
* evening, 7 pm to 3 am.

In aggregating travel into these time periods, we are explicitly assuming that congestion is constant within each time period.  We know this is not true, e.g., traffic is almost always heavier from 7 to 8 am than from 9 to 10 am.  However, we make this and numerous other simplifications to increase the computational efficiency and tractability of the model system.

To predict congested speeds on freeways, MTC uses so-called "BPR Curves", the form originally developed by the Bureau of Public Roads. The shape of the curves are discussed in more detail in a later section of this document.

The Caltrans PeMS database compiles roadway monitoring data collected continuously via loop detectors to support traveler information systems. Historical data can be downloaded from the [PeMS website](http://pems.dot.ca.gov/). Records for every five- or sixty-minute interval are available. The data includes observed flow, sensor occupancy, and speed for each working detector across the State. 

## PeMS Data Preparation
The MTC travel model predicts traveler behavior for a typical weekday -- when school is in session, the weather is clear, no major accidents occur on the roadway, etc. To extract data that best represents this abstract concept, the following [process](https://github.com/MetropolitanTransportationCommission/pems-typical-weekday/blob/master/Consume/Build_Annual_Database.R) was used to filter the PeMS data:
* Begin with the hourly data, which includes estimates af average flow, sensor occupancy, and speed for every hour in the subject day.
* Only consider data from the following months: March, April, May, September, October, and November. 
* Only consider data from the following days of the week: Tuesday, Wednesday, and Thursday.
* Consider data from every past historical year for which data is available. At the time of writing, this includes 2005 through 2015. 
* Only consider data from functioning detectors. Specifically: records for which 100 percent of the observations that make up the computed averages is observed, rather than imputed (Caltrans imputes data when the detectors are down or working intermittently).

One more step is carried out in a separate [script](https://github.com/MetropolitanTransportationCommission/pems-typical-weekday/blob/master/volume-delay/validate-volume-delay.Rmd) to prepare the PeMS data for this analysis specifically (the data resulting from the above steps is used for a variety of purposes):
* Only considered sensors on the following routes: 4, 17, 24, 80, 84, 85, 87, 92, 101, 237, 280, 380, 580, 680, 780, 880, and 980. While MTC mapped many of the PeMS sensors to our travel model network, we did not map them all.  As such, we cannot ensure that each sensor is mapped to a roadway of a known -- to the travel model -- facility type.  To increase the chances that every sensor we are examining is on a facility designated as a "freeway" in our travel model, we first exclude any sensors that are mapped to non freeways and then only select routes that are, in the Bay Area, largely grade-separated freeways. Note that these manipulations are carried out in this script. 

After extracting hourly data, for each year of typical weekdays, we compute the following statistics:

* median, average, and standard deviation of flow (vehicles passing the sensor);
* median, average, and standard deviation of vehicle speed; and,
* median, average, and standard deviation of sensor occupance (the share of time a vehicle is above the sensor).

Do further cull problematic data, we eliminate sensor/hourly records with fewer than fifteen observations.  Further, we eliminate observations from sensors with a maximum hourly flow of 150 vehicles or more than record a flow of zero -- the idea being that if a sensor records zero vehicles during an hour in which more than 150 vehicles have been observed, it's more likely that the sensor is broken or the lane/roadway closed than it is that the zero observation is correct.

We then compute a flow-weighted speed and occupancy estimate for each of the time periods in *Travel Model One* for each observation day for each sensor.  We then compute the median, average, and standard deviation of these estimates across all typical weekdays in a calendar year. The details of these procedures can be reviewed in the [implementation script](https://github.com/MetropolitanTransportationCommission/pems-typical-weekday/blob/master/Consume/Build_Annual_Database.R).

## Roadway Capacity
*Travel Model One* uses a simple look-up table to estimate each roadway's effective operating capacity. Specifically, a roadway's facility type and area type determine the roadway's capacity. A facility's area type is determined by the use of land immediately adjacent to the roadway using an area type density measure, which is computed as follows:

`area type density index = (total population + 2.5 * total employment)/(residential acres + commercial acres + industrial acres)`

Each link is assigned one of six area type categories, as shown in Table 1. The thresholds are not strict and are hand-smoothed to make them continuous across the network. Importantly, in this document we are only examining the capacity of "freeways", which is one of eight facility types used in *Travel Model One* (each of the eight have similar capacity assumptions). As noted above, most all of the PeMS sensors are on roadways the travel model designates as "freeways" and we filtered out routes that we would not expect to be designated as freeways.  

**Table 1: Area Type Density Thresholds and Freeway Capacity Assumptions**

| **Area Type**              | **Area Type Density Index (from, to)**| **Assumed Freeway Capacity (passengers cars per hour per lane)**|
|:---------------------------|---------------------------------------|-----------------------------------------------------------------|
| Regional core              | 300, infinity                         | 2050                                                            |
| Central business district  | 100, 300                              | 2050                                                            | 
| Urban business             | 55, 100                               | 2100                                                            | 
| Urban                      | 30, 55                                | 2100                                                            |
| Suburban                   | 6, 30                                 | 2150                                                            |
| Rural                      | 0, 6                                  | 2150                                                            | 





 

 
