--Creating a table for the data
CREATE TABLE insurance(
id_number SERIAL PRIMARY KEY, --added an id_number as the primary key to keep track of each data unique to each individual person
age INTEGER NOT NULL,
sex VARCHAR(50) NOT NULL,
bmi DECIMAL(14,4) NOT NULL,
children SMALLINT NOT NULL,
smoker VARCHAR(50) NOT NULL,
region VARCHAR(250) NOT NULL,
charges DECIMAL(14,4) NOT NULL
);

-- Optional: Create a view to label BMI categories for later use
CREATE VIEW bmi_groups AS
SELECT *,
  CASE 
    WHEN bmi < 18.5 THEN 'Underweight'
    WHEN bmi < 25 THEN 'Normal'
    WHEN bmi < 30 THEN 'Overweight'
    ELSE 'Obese'
  END AS bmi_category
FROM insurance;

-- Optional: Create a function to summarize stats by region
CREATE OR REPLACE FUNCTION summarize_region(region_name TEXT)
RETURNS TABLE (
    avg_charge DECIMAL,
    median_charge DECIMAL,
    smoker_rate DECIMAL,
    obese_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    AVG(charges),
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY charges),
    ROUND(100.0 * COUNT(*) FILTER (WHERE smoker = 'yes') / COUNT(*), 2),
    COUNT(*) FILTER (WHERE bmi > 30)
  FROM insurance
  WHERE region = region_name;
END;
$$ LANGUAGE plpgsql;

--Starting with the basics, I will analyze some foundational patterns

--Question 1: What is the average BMI of smokers vs non-smokers?
SELECT
CASE
	WHEN smoker = 'yes' THEN 'smoker'
	WHEN smoker = 'no' THEN 'non-smoker'
	ELSE 'Other'
END AS smoker_categorized,
COUNT(*) AS num_patients,
AVG(bmi) AS avg_bmi
FROM insurance
GROUP BY smoker_categorized;

--Question 2: Do smokers have higher charges on average?
SELECT smoker, AVG(charges) AS avg_charge, COUNT(*) AS num_patients FROM insurance
GROUP BY smoker;

--Question 3: How many patients are there by region? Which region has the most patients?
SELECT COUNT(id_number) AS num_patients, region FROM insurance
GROUP BY region
ORDER BY num_patients DESC;

--Question 4: Which region tends to have the higher chargers on average?
SELECT region, AVG(charges) AS avg_charge, COUNT(*) AS num_patients FROM insurance
GROUP BY region;

--Question 5: What is the average charge by sex? Do females or males have higher charges on average?
SELECT sex, AVG(charges) AS avg_charge, COUNT(*) AS num_patients FROM insurance
GROUP BY sex;

--Question 6: What is the minimum, maximum, and average age in the dataset?
SELECT MIN(age) AS min_age, MAX(age) AS max_age, ROUND(AVG(age)) AS avg_age FROM insurance;

-- Add a risk index by normalizing the risk score
SELECT *,
  ROUND(1.0 * risk_score / 7, 2) AS risk_index
FROM (
  SELECT age, bmi, smoker,
    (CASE WHEN smoker = 'yes' THEN 3 ELSE 0 END) +
    (CASE WHEN bmi < 25 THEN 0 WHEN bmi < 30 THEN 1 ELSE 2 END) +
    (CASE WHEN age < 30 THEN 0 WHEN age < 50 THEN 1 ELSE 2 END) AS risk_score
  FROM insurance
) AS scored_data
ORDER BY risk_index DESC;

-- Use a window function to rank patients by regional charges
SELECT 
  id_number,
  region,
  charges,
  RANK() OVER (PARTITION BY region ORDER BY charges DESC) AS regional_rank
FROM insurance;

-- Identify edge cases with BMI = 0 or charges = 0
SELECT *
FROM insurance
WHERE bmi = 0 OR charges = 0 OR age < 13;

-- Now I am going more in depth to explore the dynamics of the dataset and finding relationships

--Question 1: How does average charge change by age groups of Teens (13-19), Adults (20-39), Middle Age Adults (40-59), Seniors (60+)?
SELECT
CASE
	WHEN age BETWEEN 13 AND 19 THEN 'Teens'
	WHEN age BETWEEN 20 AND 39 THEN 'Adults'
	WHEN age BETWEEN 40 AND 59 THEN 'Middle Age Adults'
	WHEN age >= 60 THEN 'Seniors'
	ELSE 'Child or Unknown'
END AS age_group,
COUNT (*) AS num_patients,
AVG(charges) AS avg_charge
FROM insurance
GROUP BY age_group;

--Question 2: Is there a correlation between BMI and charges?
SELECT ROUND(bmi) AS rounded_bmi, COUNT(*) AS num_patients, AVG(charges) AS avg_charge --rounded the bmi to whole numbers so it's easier to sort into one "age"
FROM insurance
GROUP BY ROUND(bmi)
ORDER BY rounded_bmi;

--Pearson Correlation Coefficient Calculation result: 0.588 indicating a moderate positive correlation
SELECT CORR(rounded_bmi, avg_charge) AS pearson_corr
FROM (
SELECT ROUND(bmi) AS rounded_bmi, AVG(charges) AS avg_charge
FROM insurance
GROUP BY ROUND(bmi)
) AS bmi_summary;

--Question 3: Which combinations of smoker status, BMI, and number of children result in the highest average medical charges?
SELECT smoker, ROUND(bmi) AS rounded_bmi, children, COUNT(*) AS num_patients, AVG(charges) AS avg_charge
FROM insurance
GROUP BY smoker, ROUND(bmi), children
HAVING COUNT(*) >= 3 --removes outliers with only one patient
ORDER BY avg_charge DESC, rounded_bmi
LIMIT 10;

--Question 4: Who has the higher charges on average: older smokers or obese non-smokers?
SELECT 
CASE
	WHEN age > 50 AND smoker = 'yes' THEN 'Older Smokers'
	WHEN bmi > 30 AND smoker = 'no' THEN 'Obese Non-smokers'
	ELSE 'Other'
END AS group_label,
COUNT(*) AS num_patients,
AVG(charges) AS avg_charge,
STDDEV(charges) AS standard_deviation_charge,
PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY charges) AS median_charge,
AVG(children) AS avg_children
FROM insurance
WHERE
	(age > 50 AND smoker = 'yes') OR
	(bmi > 30 AND smoker = 'no')
GROUP BY group_label;

--Question 5: Does being a smoker amplify charges more for older or younger adults?
SELECT 
  age_group,
  AVG(CASE WHEN smoker = 'yes' THEN charges END) AS avg_smoker_charge,
  AVG(CASE WHEN smoker = 'no' THEN charges END) AS avg_nonsmoker_charge,
  ROUND(
    AVG(CASE WHEN smoker = 'yes' THEN charges END) 
    - AVG(CASE WHEN smoker = 'no' THEN charges END), 2) AS smoker_charge_diff
	
FROM (
  SELECT *,
    CASE 
      WHEN age < 40 THEN 'Younger (<40)'
      ELSE 'Older (40+)' 
    END AS age_group
  FROM insurance
) AS age_split
GROUP BY age_group;


--Question 6: What percentage of the dataset's total charges come from the top 10% of patients?
WITH charge_threshold AS (
    SELECT PERCENTILE_CONT(0.9) 
	WITHIN GROUP (ORDER BY charges ASC) AS threshold
    FROM insurance
)
SELECT
    ROUND(100.0 * SUM(CASE WHEN charges >= threshold THEN charges ELSE 0 END) / SUM(charges), 2) AS pct_total_charges_top_10
FROM insurance, charge_threshold;

--Question 7: What is the median charge?
SELECT 
	PERCENTILE_CONT(0.5)WITHIN GROUP(ORDER BY charges) AS median_charge FROM insurance

--Question 8: What's the median charge for each region?
SELECT region,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY charges) AS median_charge FROM insurance
	GROUP BY region;

--Question 9: Creating a risk label (Low, Medium, High) based on age and smoker status
SELECT age, smoker, bmi, charges,
CASE
	WHEN smoker = 'yes' AND age >= 50 THEN 'High'
	WHEN smoker = 'yes' AND age < 50 THEN 'Medium'
	WHEN smoker = 'no' AND age >= 50 THEN 'Medium'
	ELSE 'Low'
END AS risk_label
FROM insurance
ORDER BY risk_label







--Next, I decided to focus on some business related questions for real world applications


--Question 1: What region has the highest concentration of high-cost patients (those whose charges are above the 90th percentile)?
WITH charge_threshold AS (
    SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY charges) AS threshold
    FROM insurance
),
high_cost_counts AS (
    SELECT 
        region,
        COUNT(*) FILTER (WHERE charges >= threshold) AS high_cost_patients,
        COUNT(*) AS total_patients
    FROM insurance, charge_threshold
    GROUP BY region
)
SELECT 
    region,
    ROUND(100.0 * high_cost_patients::decimal / total_patients, 2) AS pct_high_cost
FROM high_cost_counts
ORDER BY pct_high_cost DESC
LIMIT 1;

--Question 2: Do males or females pay more on average in each region?
SELECT
region,
AVG(CASE WHEN sex = 'male' THEN charges END) AS avg_charge_male,
AVG(CASE WHEN sex = 'female' THEN charges END) AS avg_charge_female
FROM insurance
GROUP BY region
ORDER BY region

--Question 3: Building a risk score using smoker status, BMI, and age
--Defining a scoring system: Smoker (3pts), Non-smoker(0pts), BMI < 25(0pts), 25<=BMI<30 (1 pts), BMI > 30(2 pts), Age<30 (0 pts), 30<=Age<50(1 pts), Age >= 50(2 pts)

SELECT age, bmi, smoker, charges,
--Risk Score calculation
(CASE WHEN smoker = 'yes' THEN 3 ELSE 0 END) +
(CASE
	WHEN bmi < 25 THEN 0
	WHEN bmi < 30 THEN 1
	ELSE 2
END) +
(CASE
	WHEN age < 30 THEN 0
	WHEN age < 50 THEN 1
	ELSE 2
END) AS risk_score
FROM insurance
ORDER BY risk_score DESC, charges;

--Question 4: If non-smoking families got a 10% discount cut, how much revene would be lost?
SELECT ROUND(SUM(charges) * 0.10, 2) AS revenue_lost
FROM insurance
WHERE smoker = 'no' AND children > 0;

--Question 5: If smoking families got a 10% discount cut, how much revenue would be lost?

SELECT ROUND(SUM(charges) * 0.10,2) AS revenue_lost
FROM insurance
WHERE smoker = 'yes' AND children > 0;

--Question 6: If all obsese patients (BMI >30) reduced their BMI by 5 units, how would average charges change?
-- Since SQL can't directly model healthcare outcomes, I will approximate the impact using a linear assumption that if BMI goes down, charges go down in proportion
SELECT 
  ROUND(AVG(charges), 2) AS original_avg_charge,
  ROUND(AVG(charges * ((bmi - 5) / bmi)), 2) AS simulated_avg_charge_after_BMI_drop,
  ROUND(
    AVG(charges) - AVG(charges * ((bmi - 5) / bmi)),
    2
  ) AS avg_charge_reduction
FROM insurance
WHERE bmi > 30;

--Question 7: What is the distribution of high-cost patients across age, region, and smoker status?
WITH charge_threshold AS (
    SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY charges) AS threshold
    FROM insurance
),

labeled_data AS (
    SELECT 
        region,
        smoker,
        CASE
			WHEN age BETWEEN 13 AND 19 THEN 'Teens'
			WHEN age BETWEEN 20 AND 39 THEN 'Adults'
			WHEN age BETWEEN 40 AND 59 THEN 'Middle Age Adults'
			WHEN age > 60 THEN 'Seniors'
			ELSE 'Unknown' --WHERE age >=13
		END AS age_group,
        charges
    FROM insurance
),

summary AS (
    SELECT 
        region,
        smoker,
        age_group,
        COUNT(*) AS total_patients,
        COUNT(*) FILTER (WHERE charges >= (SELECT threshold FROM charge_threshold)) AS high_cost_patients
    FROM labeled_data
    GROUP BY region, smoker, age_group
)

SELECT 
    region,
    smoker,
    age_group,
    total_patients,
    high_cost_patients,
    ROUND(100.0 * high_cost_patients::decimal / total_patients, 2) AS pct_high_cost
FROM summary
ORDER BY region, smoker, age_group;


--Question 8: What percent of total revenue comes from families(patients with children)?
SELECT ROUND(100.0 * SUM(CASE WHEN children > 0 THEN charges ELSE 0 END)/SUM(charges),2) AS percent_revenue_from_families FROM insurance


--Question 9: Compare total charges if the insurance switched from flat rate to age-tiered pricing
WITH age_tiers AS(
	SELECT *,
	CASE
	WHEN age BETWEEN 13 AND 19 THEN 5000
	WHEN age BETWEEN 20 AND 29 THEN 8000
	WHEN age BETWEEN 40 AND 59 THEN 12000
	WHEN age > 60 THEN 15000
	ELSE charges
	END AS tiered_price
FROM insurance
)

SELECT
	ROUND(SUM(charges),2) AS total_flat_rate_charges,
	ROUND(SUM(tiered_price),2) AS total_age_tiered_charges,
	ROUND(SUM(charges) - SUM(tiered_price),2) AS revenue_difference
FROM age_tiers;

