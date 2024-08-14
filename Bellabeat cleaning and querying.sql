--------------------------------------Preview data and determine the number of distinct ids----------------------------------------------------------------

SELECT COUNT(DISTINCT Id) FROM hourlysteps;
SELECT COUNT(DISTINCT Id) FROM sleepday_merged;
SELECT COUNT(DISTINCT Id) FROM dailyactivity_merged;

---------------------------------------------------Renaming tables------------------------------------------------------------------------------------------------------

ALTER TABLE dailyactivity_merged RENAME TO dailyactivity;
ALTER TABLE hourlysteps_merged RENAME TO hourlysteps;
ALTER TABLE sleepday_merged RENAME TO sleepday;

-------------------------------------------------------Data Cleaning--------------------------------------------------------------------------------------------------------
-------------------------------------------------Create new tables from the originals---------------------------------------------------------------------------------

CREATE TABLE dailyactivity_cleaned
LIKE dailyactivity;

INSERT dailyactivity_cleaned
SELECT * 
FROM dailyactivity;

SELECT * FROM dailyactivity_cleaned;

--------------------------------------------2nd table--------------------------------------------------------------------------------------

CREATE TABLE hourlysteps_cleaned
LIKE hourlysteps;

INSERT hourlysteps_cleaned
SELECT * 
FROM hourlysteps


-------------------------------------------3rd table---------------------------------------------------------------------------------------

CREATE TABLE sleepday_cleaned
LIKE sleepday;

INSERT sleepday_cleaned
SELECT * 
FROM sleepday;


-------------------------------Change activityhour in the hourlysteps table from variable character to datetime format-------------------------

SELECT 
	`activityhour`,
	STR_TO_DATE(`activityhour`, '%Y-%m-%d %H:%i:%s') AS activitydate_hour
FROM hourlysteps_cleaned;
 
 UPDATE hourlysteps_cleaned
	SET `activityhour` = STR_TO_DATE(`activityhour`, '%Y-%m-%d %H:%i:%s'); 
 
 ALTER TABLE hourlysteps_cleaned
	MODIFY `activityhour` DATETIME;
 
SELECT * FROM hourlysteps_cleaned;


--------------------------------------------Look for duplicates----------------------------------------------------------------------------

SELECT 
Id, Sleepday, TotalSleepRecords, TotalMinutesAsleep, TotalTimeInBed
FROM sleepday_cleaned
GROUP BY Id, Sleepday, TotalSleepRecords, TotalMinutesAsleep, TotalTimeInBed
HAVING COUNT(*) > 1;

SELECT * 
FROM sleepday_cleaned
WHERE Id IN (8378563200, 4702921684, 4388161847)
ORDER BY TotalTimeInBed;


---------------------------------------Delete duplicates-----------------------------------------------------------------------------------

WITH duplicates AS (
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY Id, SleepDay, TotalSleepRecords, TotalMinutesAsleep, TotalTimeInBed) AS row_num
	FROM sleepday_cleaned
);


CREATE TABLE `sleepday_cleaned1` (
  `Id` bigint DEFAULT NULL,
  `SleepDay` datetime DEFAULT NULL,
  `TotalSleepRecords` int DEFAULT NULL,
  `TotalMinutesAsleep` int DEFAULT NULL,
  `TotalTimeInBed` int DEFAULT NULL,
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO sleepday_cleaned1
SELECT *,
ROW_NUMBER() OVER(PARTITION BY Id, SleepDay, TotalSleepRecords, TotalMinutesAsleep, TotalTimeInBed) AS row_num
FROM sleepday_cleaned;


SELECT * 
FROM sleepday_cleaned1
WHERE row_num > 1;

DELETE
FROM sleepday_cleaned1
WHERE row_num > 1;

--------------------------------Check to see that duplicates are removed-------------------------------------------------------------------

SELECT 
	Id, Sleepday,TotalSleepRecords, TotalMinutesAsleep, TotalTimeInBed
FROM sleepday_cleaned1
GROUP BY Id, Sleepday,TotalSleepRecords, TotalMinutesAsleep, TotalTimeInBed
HAVING COUNT(*) > 1;



---------------------------Standardize column names----------------------------------------------------------------------------------------
----------------------------Rename table and column names----------------------------------------------------------------------------------

ALTER TABLE sleepday_cleaned1 RENAME TO dailysleep_records;
ALTER TABLE hourlysteps_cleaned RENAME TO hourly_steps;
ALTER TABLE dailyactivity_cleaned RENAME TO daily_activity;

SELECT * FROM dailysleep_records;
SELECT * FROM hourly_steps;
SELECT * FROM daily_activity;

ALTER TABLE daily_activity CHANGE ActivityDate Date DATE;
ALTER TABLE dailysleep_records CHANGE Date_time Date DATE;
ALTER TABLE hourly_steps CHANGE activityhour Date_time DATETIME;


------------------------------------------------Data Querying-------------------------------------------------------------------------------------------------------------

SELECT * FROM daily_activity da
JOIN dailysleep_records   dsr
ON da.id = dsr.id
AND da.date = dsr.date;
    
    
-----------------Derive summary statistics from the joined table and classify users by their level of activity-----------------------------
----------------- Also determine the percentages of the classified users--------------------------------------------------------------------

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


---------------------Determine what days of the week users are more active-----------------------------------------------------------------

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

----------------------------Determine what times of the day users are more active----------------------------------------------------------

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

------------------------------Determine the correlations between variables-----------------------------------------------------------------
------------------------------Daily steps and daily sleep----------------------------------------------------------------------------------

SELECT 
	da.totalsteps,
	dsr.totalminutesasleep
FROM daily_activity da
JOIN dailysleep_records dsr
ON da.id = dsr.id
AND da.date = dsr.date;

--------------------------------------Daily steps and calories-----------------------------------------------------------------------------

SELECT 
	totalsteps,
	calories
FROM daily_activity;


-----------------------------------Check the number of days users wore their devices-------------------------------------------------------

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


---------------------------------------How many minutes are the devices worn in a day?-----------------------------------------------------
--------------------------------------Create three categories that specify the total minutes that the devices are worn by users in a day-------

WITH num_in_a_month AS(
SELECT
	Id,
	COUNT(*) AS no_of_days
	FROM dailysleep_records
	GROUP BY id),
regularity AS(
SELECT 
	Id,
	no_of_days,
CASE 
	WHEN no_of_days >= 1 AND no_of_days <= 10 THEN 'Low Use'
	WHEN no_of_days >= 10 AND no_of_days <= 20 THEN 'Moderate Use'
	WHEN no_of_days >= 21 AND no_of_days <= 31 THEN 'High Use'
ELSE ' '
END AS usage_type
FROM num_in_a_month
),
merged AS(
SELECT 
        regu.no_of_days,
        regu.usage_type,
        da.*
FROM regularity regu
JOIN daily_activity da
ON regu.id = da.id),
aggregating AS(
	SELECT 
	id,
	date,
	(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes) AS total_minutes_worn
FROM merged),
groupings AS(
	SELECT
	id,
	date,
	((total_minutes_worn / 1440.0) * 100) AS percentage_of_minutes_worn
	FROM aggregating),
Classes AS(
	SELECT 
	id,
	date,
CASE 
	WHEN percentage_of_minutes_worn > 0 AND percentage_of_minutes_worn < 50 THEN 'Less than half day'
    WHEN percentage_of_minutes_worn >= 50 AND percentage_of_minutes_worn < 100 THEN 'More than half day'
    WHEN percentage_of_minutes_worn >= 100 THEN 'Whole day'
    ELSE ' '
    END AS Minute_grouping
FROM groupings),
everything AS(
SELECT
    me.*,
    ag.total_minutes_worn,
    g.percentage_of_minutes_worn,
    c.minute_grouping
FROM merged me
JOIN aggregating ag 
    ON me.id = ag.id
    AND me.date = ag.date
JOIN groupings g 
    ON me.id = g.id
    AND me.date = g.date
JOIN Classes c 
    ON me.id = c.id
    AND me.date = c.date)
    SELECT * FROM everything;
    
-----------------------------------Determine the share of each usage group level as a percentage of total minutes worn---------------------------------------------

WITH num_in_a_month AS(
SELECT
	Id,
	COUNT(*) AS no_of_days
	FROM dailysleep_records
	GROUP BY id),
regularity AS(
SELECT 
	Id,
	no_of_days,
CASE 
	WHEN no_of_days >= 1 AND no_of_days <= 10 THEN 'Low Use'
	WHEN no_of_days >= 10 AND no_of_days <= 20 THEN 'Moderate Use'
	WHEN no_of_days >= 21 AND no_of_days <= 31 THEN 'High Use'
ELSE ' '
END AS usage_type
FROM num_in_a_month
),
merged AS(
SELECT 
        regu.no_of_days,
        regu.usage_type,
        da.*
FROM regularity regu
JOIN daily_activity da
ON regu.id = da.id),
aggregating AS(
	SELECT 
	id,
	date,
	(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes) AS total_minutes_worn
FROM merged),
groupings AS(
	SELECT
	id,
	date,
	((total_minutes_worn / 1440.0) * 100) AS percentage_of_minutes_worn
	FROM aggregating),
Classes AS(
	SELECT 
	id,
	date,
CASE 
	WHEN percentage_of_minutes_worn > 0 AND percentage_of_minutes_worn < 50 THEN 'Less than half day'
    WHEN percentage_of_minutes_worn >= 50 AND percentage_of_minutes_worn < 100 THEN 'More than half day'
    WHEN percentage_of_minutes_worn >= 100 THEN 'Whole day'
    ELSE ' '
    END AS Minute_grouping
FROM groupings),
minute_group_count AS(
SELECT 
	id, 
	date,
	COUNT(total_minutes_worn)
	FROM aggregating
	GROUP BY 1, 2),
minute_group_sum AS(
	SELECT 
	id,
	date,
	SUM(total_minutes_worn) AS all_minutes_worn
	FROM aggregating
	GROUP BY 1, 2),
minute_percent_worn AS(
	SELECT
	cs.minute_grouping,
	(COUNT(mgs.all_minutes_worn) * 100.0) / SUM(COUNT(mgs.all_minutes_worn)) OVER () AS pc
FROM classes cs
JOIN minute_group_sum mgs
ON cs.id = mgs.id
AND cs.date = mgs.date
GROUP BY 1)
SELECT * FROM minute_percent_worn;


------------------------------Filtering by usage groups (High use)----------------------------------------------------------------------------

WITH num_in_a_month AS(
SELECT
	Id,
	COUNT(*) AS no_of_days
	FROM dailysleep_records
	GROUP BY id),
regularity AS(
SELECT 
	Id,
	no_of_days,
CASE 
	WHEN no_of_days >= 1 AND no_of_days <= 10 THEN 'Low Use'
	WHEN no_of_days >= 10 AND no_of_days <= 20 THEN 'Moderate Use'
	WHEN no_of_days >= 21 AND no_of_days <= 31 THEN 'High Use'
ELSE ' '
END AS usage_type
FROM num_in_a_month
),
merged AS(
SELECT 
        regu.no_of_days,
        regu.usage_type,
        da.*
FROM regularity regu
JOIN daily_activity da
ON regu.id = da.id
WHERE usage_type = 'High Use'),
aggregating AS(
	SELECT 
	id,
	date,
	(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes) AS total_minutes_worn
	FROM merged),
groupings AS(
SELECT
	id,
	date,
	((total_minutes_worn / 1440.0) * 100) AS percentage_of_minutes_worn
	FROM aggregating),
Classes AS(
	SELECT 
	id,
	date,
CASE 
	WHEN percentage_of_minutes_worn > 0 AND percentage_of_minutes_worn < 50 THEN 'Less than half day'
    WHEN percentage_of_minutes_worn >= 50 AND percentage_of_minutes_worn < 100 THEN 'More than half day'
    WHEN percentage_of_minutes_worn >= 100 THEN 'Whole day'
    ELSE ' '
    END AS Minute_grouping
FROM groupings),
minute_group_count AS(
	SELECT 
	id, 
	date,
	COUNT(total_minutes_worn)
	FROM aggregating
	GROUP BY 1, 2),
minute_group_sum AS(
	SELECT 
	id,
	date,
	SUM(total_minutes_worn) AS all_minutes_worn
	FROM aggregating
	GROUP BY 1, 2),
minute_percent_worn AS(
SELECT
	cs.minute_grouping,
	(COUNT(mgs.all_minutes_worn) * 100.0) / SUM(COUNT(mgs.all_minutes_worn)) OVER () AS pc
FROM classes cs
JOIN minute_group_sum mgs
ON cs.id = mgs.id
AND cs.date = mgs.date
GROUP BY 1)
SELECT * FROM minute_percent_worn;


------------------------------Filtering by groups (moderate use)---------------------------------------------------------------------------

WITH num_in_a_month AS(
SELECT
	Id,
	COUNT(*) AS no_of_days
	FROM dailysleep_records
	GROUP BY id),
regularity AS(
SELECT 
	Id,
	no_of_days,
CASE 
	WHEN no_of_days >= 1 AND no_of_days <= 10 THEN 'Low Use'
	WHEN no_of_days >= 10 AND no_of_days <= 20 THEN 'Moderate Use'
	WHEN no_of_days >= 21 AND no_of_days <= 31 THEN 'High Use'
ELSE ' '
END AS usage_type
FROM num_in_a_month
),
merged AS(
SELECT 
        regu.no_of_days,
        regu.usage_type,
        da.*
FROM regularity regu
JOIN daily_activity da
ON regu.id = da.id
WHERE usage_type = 'Moderate Use'),
aggregating AS(
SELECT 
	id,
	date,
	(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes) AS total_minutes_worn
FROM merged),
groupings AS(
	SELECT
	id,
	date,
	((total_minutes_worn / 1440.0) * 100) AS percentage_of_minutes_worn
FROM aggregating),
Classes AS(
SELECT 
	id,
	date,
CASE 
	WHEN percentage_of_minutes_worn > 0 AND percentage_of_minutes_worn < 50 THEN 'Less than half day'
    WHEN percentage_of_minutes_worn >= 50 AND percentage_of_minutes_worn < 100 THEN 'More than half day'
    WHEN percentage_of_minutes_worn >= 100 THEN 'Whole day'
    ELSE ' '
    END AS Minute_grouping
FROM groupings),
minute_group_count AS(
	SELECT 
	id, 
	date,
	COUNT(total_minutes_worn)
FROM aggregating
GROUP BY 1, 2),
minute_group_sum AS(
	SELECT 
	id,
	date,
	SUM(total_minutes_worn) AS all_minutes_worn
FROM aggregating
GROUP BY 1, 2),
minute_percent_worn AS(
	SELECT
	cs.minute_grouping,
	(COUNT(mgs.all_minutes_worn) * 100.0) / SUM(COUNT(mgs.all_minutes_worn)) OVER () AS pc
FROM classes cs
JOIN minute_group_sum mgs
ON cs.id = mgs.id
AND cs.date = mgs.date
GROUP BY 1)
SELECT * FROM minute_percent_worn;


--------------------------Filtering by usage (Low use)-------------------------------------------------------------------------------------

WITH num_in_a_month AS(
SELECT
	Id,
	COUNT(*) AS no_of_days
	FROM dailysleep_records
	GROUP BY id),
regularity AS(
SELECT 
	Id,
	no_of_days,
CASE 
	WHEN no_of_days >= 1 AND no_of_days <= 10 THEN 'Low Use'
	WHEN no_of_days >= 10 AND no_of_days <= 20 THEN 'Moderate Use'
	WHEN no_of_days >= 21 AND no_of_days <= 31 THEN 'High Use'
ELSE ' '
END AS usage_type
FROM num_in_a_month
),
merged AS(
SELECT 
        regu.no_of_days,
        regu.usage_type,
        da.*
FROM regularity regu
JOIN daily_activity da
ON regu.id = da.id
WHERE usage_type = 'Low Use'),
aggregating AS(
SELECT 
	id,
	date,
	(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes) AS total_minutes_worn
FROM merged),
groupings AS(
	SELECT
	id,
	date,
	((total_minutes_worn / 1440.0) * 100) AS percentage_of_minutes_worn
FROM aggregating),
Classes AS(
SELECT 
id,
date,
CASE 
	WHEN percentage_of_minutes_worn > 0 AND percentage_of_minutes_worn < 50 THEN 'Less than half day'
    WHEN percentage_of_minutes_worn >= 50 AND percentage_of_minutes_worn < 100 THEN 'More than half day'
    WHEN percentage_of_minutes_worn >= 100 THEN 'Whole day'
    ELSE ' '
    END AS Minute_grouping
FROM groupings),
minute_group_count AS(
	SELECT 
	id, 
	date,
	COUNT(total_minutes_worn)
FROM aggregating
GROUP BY 1, 2),
minute_group_sum AS(
	SELECT 
	id,
	date,
	SUM(total_minutes_worn) AS all_minutes_worn
FROM aggregating
GROUP BY 1, 2),
minute_percent_worn AS(
	SELECT
	cs.minute_grouping,
	(COUNT(mgs.all_minutes_worn) * 100.0) / SUM(COUNT(mgs.all_minutes_worn)) OVER () AS pc
FROM classes cs
JOIN minute_group_sum mgs
ON cs.id = mgs.id
AND cs.date = mgs.date
GROUP BY 1)
SELECT * FROM minute_percent_worn;