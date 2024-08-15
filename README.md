# Bellabeat's Fitness Product Analysis

## Table of Content
- [Project Overview](#project-overview)
- [Data Source](#data-source)
- [Tools](#tools)
- [Data cleaning process](#data-cleaning-process)
- [Exploratory data analysis](#exploratory-data-analysis)
- [Data Analysis](#data-analysis)
- [Results](#results)
- [Recommendations](#recommendations)
- [Limitations](#limitations)
- [References](#references)
  
### Project Overview
---

This project was designed to analyze the way customers use a fitness device produced by a company named Bellabeat. The result of the analysis will help stakeholders understand trends and patterns that will inform better marketing and device optimization.

<img width="616" alt="Fitness screenshot" src="https://github.com/user-attachments/assets/43fc0ce7-f672-4ccc-bde4-3583d54dda87">


### Data source

The data for this analysis was obtained from the FitBit Fitness Tracker Data in Kaggle's publc domain. [Download here](https://www.kaggle.com/datasets/arashnic/fitbit)

### Tools
- Excel (for data cleaning)
- MySQL (for data analysis)
- Power BI (for reporting)

### Data cleaning process
For this task, I prepared the data for analysis by
1. inspecting for missing values
2. standardizing dates and time

### Exploratory data analysis
The analysis answered the following questions;
- What are some trends in smart device usage?
- How could these trends apply to Bellabeat customers?
- How could these trends help influence Bellabeat marketing strategy?

### Data Analysis
The following codes were written and executed on Bigquery.

```sql
-----------------Derive summary statistics from the joined table and classify users by their level of activity------------------------
-----------------Also determine the percentages of the classified users---------------------------------------------------------------

WITH summarystat AS
	(SELECT da.Id AS dailyactivityid,  
	TotalSteps,  
	Calories,
	TotalMinutesAsleep
	FROM daily_activity da
	JOIN dailysleep_records   dsr
	ON da.id = dsr.id
	AND da.date = dsr.date
	),
summarised AS
(
	SELECT  dailyactivityid, 
	AVG(totalsteps) AS mean_daily_steps, 
	AVG(calories) AS mean_daily_calories, 
	AVG(totalminutesasleep) AS mean_daily_sleep
	FROM summarystat
	GROUP BY dailyactivityid),
classified AS(
	SELECT 
	dailyactivityid,
	mean_daily_steps,
	mean_daily_calories,
	mean_daily_sleep,
CASE 
	WHEN mean_daily_steps < 5000 THEN 'sedentary'
	WHEN mean_daily_steps >= 5000 AND mean_daily_steps <= 7499 THEN 'lightly active'
	WHEN mean_daily_steps >= 7500 AND mean_daily_steps <= 9999 THEN 'fairly active'
    ELSE 'very active'
    END AS classifications
FROM summarised
),
class_nos AS(
	SELECT 
	classifications,
	COUNT(*) AS total
	FROM classified
	GROUP BY classifications
),
total_count AS(
	SELECT 
	classifications,
	ROUND(total * 100 / (SELECT SUM(total) FROM class_nos), 0) AS percentage
	FROM  class_nos
)
SELECT
DISTINCT cn.classifications,
cn.total,
tc.percentage
FROM class_nos AS cn
JOIN total_count AS tc
ON 
cn.classifications = tc.classifications;


---------------------Determine what days of the week users are more active------------------------------------------------------
WITH weekday AS(
	SELECT
	WEEKDAY(da.`Date`) AS day,
	totalsteps,
	totalminutesasleep
	FROM daily_activity da
	JOIN dailysleep_records dsr
	ON da.id = dsr.id
	AND da.date = dsr.date
),
days AS(
	SELECT 
	totalsteps,
	totalminutesasleep,
CASE
	WHEN day = 0 THEN 'Monday'
	WHEN day = 1 THEN 'Tuesday'
	WHEN day = 2 THEN 'Wednesday'
	WHEN day = 3 THEN 'Thursday'
	WHEN day = 4 THEN 'Friday'
	WHEN day = 5 THEN 'Saturday'
	WHEN day = 6 THEN 'Sunday'
	ELSE ' '
	END AS weeknames 
	FROM weekday),
means AS(
	SELECT 
	weeknames,
	AVG(totalsteps),
	AVG(totalminutesasleep)
	FROM days
	GROUP BY weeknames
)
SELECT * FROM means;

----------------------------Determine what times of the day users are more active-------------------------------------------------
WITH separation_of_datetime AS(
	SELECT
	Id,
	SUBSTRING(`activityhour`, 1, 10) AS the_day,
	SUBSTRING(`activityhour`, 12, 19) AS time_of_day,
	steptotal
	FROM hourly_steps
)
SELECT
Id,
the_day,
time_of_day,
AVG(steptotal)
FROM separation_of_datetime
GROUP BY Id, the_day, time_of_day;

------------------------------Determine the correlations between variables-------------------------------------------------
------------------------------Daily steps and daily sleep------------------------------------------------------------------

SELECT 
	da.totalsteps,
	dsr.totalminutesasleep
FROM daily_activity da
JOIN dailysleep_records dsr
ON da.id = dsr.id
AND da.date = dsr.date;

--------------------------------------Daily steps and calories--------------------------------------------------------------
SELECT 
	totalsteps,
	calories
FROM daily_activity;


-----------------------------------Check the number of days users wore their devices----------------------------
WITH num_in_a_month AS(
	SELECT
	Id,
	COUNT(*) AS no_of_days
	FROM dailysleep_records
	GROUP BY id),
regularity AS(
	SELECT Id,
	no_of_days,
CASE 
	WHEN no_of_days >= 1 AND no_of_days <= 10 THEN 'Low Use'
	WHEN no_of_days >= 10 AND no_of_days <= 20 THEN 'Moderate Use'
	WHEN no_of_days >= 21 AND no_of_days <= 31 THEN 'High Use'
	ELSE ' '
	END AS usage_type
FROM num_in_a_month
),
percent_of_categories AS(
	SELECT
	usage_type,
	(COUNT(usage_type) * 100 / (SELECT SUM(COUNT(usage_type)) OVER() FROM regularity)) AS the_percentages
	FROM regularity
	GROUP BY 1)
SELECT * FROM percent_of_categories;

;
```
### Results
The results of the analysis indicated the following;
- Most users of the fitness app sleep less than 8 hours so new devices can incorporate measures of alerting them to sleep time.
- More than half of users did not walk the daily recommended number of steps.
- Only half of users wear the device everyday.
- Innovative applications can be developed to make users more conscious of exercise and daily steps goals.

### Recommendations
- Develop IoT devices that are trendy, accurate, and tailored to individual needs.
- Incorporate engaging features that will encourage users to walk more and reach the CDC recommended steps of 8000 per day.
- Invest in research to introduce more portable devices to the budding market.

### Limitations 
The small sample size of 30 may have some bias and not be representative of the entire population. The currency of the data is also questionable because the dataset was collated in 2021.

### References
1. [Stack Overflow](https://stackoverflow.com/questions/17946221/sql-join-and-different-types-of-joins)

💻
🖱️
   
