-- Dataset name: Homicideper1lac

-- ### Easy-Level Questions
-- 1. **What is the average homicide rate for each region for the year 2019?**
-- Aggregated data to compute the average homicide rate per region for the specified year
with avg_region_homicide_rate as (
    select Period, 
           ParentLocation, 
           avg(FactValueNumeric) as average_homicide_rate
    from homicide_per1lac
    where Period = 2019
    group by Period, Parentlocation
)
select *
from avg_region_homicide_rate;

-- 2. **List all homicide rates for Singapore for the year 2019.**
-- Filtered data to get all records of homicide rates for Singapore for year 2019
select *
from homicide_per1lac
where period = 2019 and location = "Singapore";


-- 3. **List all unique values for the `Dim1` (Sex) dimension.**
-- Extract distinct values for the 'dim1' column, which represents gender
select distinct(Dim1)
from homicide_per1lac;


-- 4. **Find the homicide rate for all countries in Western Pacific region for the latest year available.**
-- Filtered data for the Western Pacific region
-- Find the most recent year available
select period, parentlocation, location, factvaluenumeric 
from homicide_per1lac
where parentlocation = "Western Pacific" and period = (
    select period
    from homicide_per1lac
    order by period desc
    limit 1
);

-- 5. **Get the number of records for each `ParentLocation`.**
-- Step 1: Count the number of records grouped by each `parentlocation`
select parentlocation, count(*) as number_of_records
from homicide_per1lac
group by parentlocation
order by number_of_records desc;
 
-- 6. **Display the highest recorded homicide rate for each country in the dataset.**
-- Step 1: Find the maximum homicide rate recorded for each country
select location, max(factvaluenumeric) as highest_homicide_rate
from homicide_per1lac
group by location
order by highest_homicide_rate desc;


-- ### Moderate-Level Questions

-- 1. **Identify the country with the highest homicide rate for females in 2019.**
-- CTE to filter the data for females in 2019
with high_homi_rate as (
		select Period, 
				ParentLocation, 
                Location, 
                Dim1, 
                FactValueNumeric
        from homicide_per1lac
        where Dim1 = "Female" and Period = 2019
),
-- CTE to find the highest homicide rate
	highest as (
			select Location, FactValueNumeric
            from high_homi_rate
            where FactValueNumeric = (select max(FactValueNumeric) as highest_hRate
									  from high_homi_rate)
    )
   -- Final select to get details of the country with the highest rate 
    select *
    from highest;

-- 2. **Find the standard deviation of homicide rates for each sex dimension.**
select Dim1,
		stddev(FactValueNumeric) as standard_deviation
from homicide_per1lac
group by Dim1;

-- 3. **Determine the number of records where the homicide rate falls within a specific range (e.g., 0.1 to 0.3).**
-- Step 1: Filter and count records where the homicide rate is within the given range
select count(*) as records_in_range
from homicide_per1lac
where factvaluenumeric between 0.1 and 0.3;


-- 4. **Compare the average homicide rates between different regions for the latest year available.**
select Period, 
		ParentLocation,
		avg(FactValueNumeric) as average_homicide_rate
from homicide_per1lac
where Period = (select Period
				from homicide_per1lac
                order by Period desc
                limit 1
)
group by Period, ParentLocation
order by average_homicide_rate desc;


-- ### Hard-Level Questions

-- 1. **Compare the homicide rates between male and female populations across all countries for 2019 and identify countries where the male rate is significantly higher than the female rate.**
-- CTE to calculate the average homicide rates for males and females
with comp as (
		select Period, 
				Location, 
                Dim1, 
                avg(FactValueNumeric) as averageHR
        from homicide_per1lac
        where Dim1 in ("Male", "Female") and Period = 2019
        group by Period, Location, Dim1
),

-- CTE to compare male and female homicide rates
	compare as (
			select male.Location,
		coalesce(male.averageHR, 0) as maleHomRate,
        coalesce(female.averageHR, 0) as femaleHomRate,
        (coalesce(male.averageHR, 0) - coalesce(female.averageHR, 0)) as difference
from comp male
join comp female
on female.Location = male.Location
and female.Dim1 = "Female"
where male.Dim1 = "Male"
order by male.Location
)
-- Final query to select and categorize the results
select Location,
		maleHomRate,
        femaleHomRate,
        difference,
		case 
				when maleHomRate > femaleHomRate then "Yes"
                when maleHomRate < femaleHomRate then "No"
			else "Equal"
		end as isMaleHomicideRateHigh
from compare
order by Location;

-- 2. **Analyze trends in homicide rates over multiple years (if applicable) for Japan and identify any upward or downward trends.**

select Period, avg(FactValueNumeric) as averageHomRateJapan
from homicide_per1lac
where Location = "Japan"
group by Period
order by Period asc;

-- 3. **Calculate the percentage change in the homicide rate from one year to the next for each country and identify the countries with the most significant changes.**
-- Step 1: Compute the average homicide rate for each year and country
with yearly_average_rate as (
    select period, 
           location,
           avg(factvaluenumeric) as average_rate
    from homicide_per1lac
    group by period, location
    order by period
),
-- Step 2: Calculate the percentage change in homicide rate from one year to the next
percentage_change as (
    select period,
           location,
           average_rate,
           lag(average_rate) over (partition by location order by period) as previous_rate,
           case
               when lag(average_rate) over (partition by location order by period) is not null
               then (average_rate - lag(average_rate) over (partition by location order by period)) 
               / lag(average_rate) over (partition by location order by period) * 100
               else null
           end as percentage_change
    from yearly_average_rate
    order by location asc, period asc
)
-- Step 3: Select and analyze the percentage change
select *
from percentage_change;


-- 4. **Identify discrepancies by comparing the homicide rate provided (`FactValueNumeric`) with the range (`FactValueNumericLow`, `FactValueNumericHigh`) and find records where the rate is outside this range.**
-- Step 1: Compare the homicide rate with the given range and identify discrepancies
with rate_discrepancies as (
    select *,
           case 
               when (factvaluenumeric > factvaluenumericlow and factvaluenumeric < factvaluenumerichigh) then "In range"
               else "Out of range"
           end as discrepancy_status
    from homicide_per1lac
),
-- Step 2: Select records where the rate is outside the range
out_of_range as (
    select *
    from rate_discrepancies
    where discrepancy_status = "Out of range"
)
-- Step 3: Get the final list of records with discrepancies
select *
from out_of_range;


-- 5. **Determine the average homicide rate for each sex dimension within specific regions and compare these averages across regions to find any notable differences.**
-- Step 1: Compute the average homicide rate for each sex dimension within each region
with avg_rate_by_region_and_sex as (
    select parentlocation,
           dim1,
           avg(factvaluenumeric) as average_homicide_rate
    from homicide_per1lac
    group by parentlocation, dim1
)
-- Step 2: Display the averages for comparison
select *
from avg_rate_by_region_and_sex;



-- ### Advanced-Level Questions

-- 1. **Perform a cross-tabulation analysis to compare the average homicide rates by both `ParentLocation` and `Dim1` (Sex) dimension, showing how rates differ by region and sex.**
-- Step 1: Calculate the average homicide rate by `parentlocation` and `dim1
with avgHRate as (select ParentLocation, 
					 Dim1, 
                     avg(FactValueNumeric) as averageHomicideRate
			  from homicide_per1lac
              where Dim1 in ("Male", "Female")
			  group by ParentLocation, Dim1
			  order by ParentLocation asc
),
-- Step 2: Create a cross-tabulation of average rates
	cross_table as (
		select male.ParentLocation as Regions,
				coalesce(male.averageHomicideRate, 0) as male,
                coalesce(female.averageHomicideRate, 0) as female
        from avgHRate male
        left join avgHRate female
        on male.ParentLocation = female.ParentLocation
        and female.Dim1 = "Female"
        where male.Dim1 = "Male"
        order by Regions
)
-- Step 3: Display
select *
from cross_table
order by Regions asc;

-- 2. **Find the top 5 countries with the highest average homicide rates over multiple years (if data for multiple years exists) and compare them across different sex dimensions.**
-- Step 1: Compute the average homicide rate for each country
with avgHR as ( select  
					Location, 
                    avg(FactValueNumeric) as averageHR
			  from homicide_per1lac
			  group by Location

),
-- Step 2: Identify the top 5 countries with the highest average homicide rates
	top5 as (
			select *
            from avgHR
			order by averageHR desc
            limit 5
    ),
    -- Step 3: Compare average homicide rates across different sex dimensions for the top 5 countries
    country_data as (
		select
				homicide_per1lac.Period,
				top5.Location,
                homicide_per1lac.Dim1,
                AVG(homicide_per1lac.FactValueNumeric) AS averageHomicideRate
        from homicide_per1lac 
        join top5
        on top5.Location = homicide_per1lac.Location
        group by top5.Location,
				homicide_per1lac.Period,
                homicide_per1lac.Dim1
        order by Location asc
    )
    
    select *
    from country_data;

-- 3. **Analyze the correlation between the homicide rates and the different dimensions (e.g., Sex, Region) to determine if any dimensions have a strong influence on the rate.**
-- Transforming categorical dimensions into numerical codes.
with transform as (
		select FactValueNumeric,
			case 
				when ParentLocation = "Africa" then 1
                when ParentLocation = "Americas" then 2
                when ParentLocation = "Eastern Mediterranean" then 3
                when ParentLocation = "Europe" then 4
                when ParentLocation = "South-East Asia" then 5
                when ParentLocation = "Western Pacific" then 6
                else 0
			end as ParentLocationCode,
            case
				when Dim1 = "Male" then 1
                when Dim1 = "Female" then 2
                when Dim1 = "Both Sexes" then 3
                else 0
			end as Dim1Code
        from homicide_per1lac
    ),
  
  -- Calculating required correlation statistics.
    correlation_stats as (
			select count(*) as n,
					sum(FactValueNumeric) as sum_x,
                    sum(ParentLocationCode) as sum_y,
                    sum(FactValueNumeric * ParentLocationCode) as sum_xy,
                    sum(FactValueNumeric * FactValueNumeric) as sum_xx,
                    sum(ParentLocationCode * ParentLocationCode) as sum_yy
            from transform
    ),
    
-- Computing Pearson correlation coefficient.
    correlation as (
			select 
				 (n * sum_xy - sum_x * sum_y) / 
				 (sqrt((n * sum_xx - sum_x * sum_x) * (n * sum_yy - sum_y * sum_y))) as correlation
            from correlation_stats
    )
    
--  Printing Final output
select *
from correlation;


-- 4. **Perform a clustering analysis to group countries with similar homicide rates and identify clusters with high or low rates.**
-- Just a simple demonstration
with ct as (select Location, 
					FactValueNumeric as avghr
			from homicide_per1lac
),
	cta as (
			select *,
					case
						when avghr between 0 and 5 then "A"
                        when avghr between 5 and 10 then "B"
                        when avghr between 10 and 15 then "C"	
                        when avghr between 15 and 20 then "D"
                        when avghr between 20 and 25 then "E"
                        when avghr between 25 and 30 then "F"
                        when avghr between 30 and 35 then "G"
                        when avghr between 35 and 40 then "H"
                        else "Anomaly"
					end as clustering
            from ct
    )
select *
from cta;

-- 5. **Identify patterns in homicide rates by looking at the changes in rates for each country over several years, if data is available, and classify the patterns into categories such as increasing, decreasing, or stable.**
-- Step 1: Compute previous year's homicide rate and current year's rate
with rate_patterns as (
    select period,
           location,
           factvaluenumeric,
           lag(factvaluenumeric) over (partition by location order by period) as previous_rate
    from homicide_per1lac
    order by location asc
),
-- Step 2: Classify the trends based on the changes in homicide rates
trend_classification as (
    select period,
           location,
           factvaluenumeric,
           previous_rate,
           case
               when previous_rate is null then "Not available"
               when factvaluenumeric > previous_rate then "Increasing"
               when factvaluenumeric < previous_rate then "Decreasing"
               else "Stable"
           end as trend
    from rate_patterns
)
-- Step 3: Display the trend classifications
select *
from trend_classification
order by location, period;


/* Conclusion: The analysis of homicide data has revealed key insights into crime patterns across different
			    regions and demographics. We identified regions with notably high and low homicide rates, 
                offering valuable guidance for targeted crime prevention efforts. By comparing homicide rates
                between male and female populations, we uncovered significant gender-based disparities that 
                could inform gender-specific interventions. The variability and trends in homicide rates 
                highlighted fluctuations over time, shedding light on areas of increasing or decreasing crime.
                Data discrepancies were flagged, pointing to potential issues with data accuracy that need addressing.
                Cross-tabulation showed how homicide rates vary by region and gender, while clustering analysis 
                categorized countries into meaningful groups, aiding in the development of focused strategies. 
                Overall, these insights provide a comprehensive understanding of homicide trends and can guide 
                more effective crime prevention and policy measures. */
