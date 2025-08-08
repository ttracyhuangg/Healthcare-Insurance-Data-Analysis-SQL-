# Insurance Data Analysis (SQL Project)

This project is a full-scale SQL analysis of an insurance dataset focused on uncovering trends in medical charges, risk factors, and demographic patterns. I built it to strengthen my SQL skills while applying real-world thinking to healthcare data from identifying cost drivers to simulating pricing models.

I treated this as if I were a data analyst at an insurance company trying to answer tough questions that impact both patient outcomes and company revenue.
The Dataset I used is from Kaggle: https://www.kaggle.com/datasets/mirichoi0218/insurance

---

## Goals

- Analyze how age, BMI, smoking, and region impact insurance charges
- Identify high-cost patients and understand what drives their expenses
- Build a risk scoring system using health and lifestyle factors
- Simulate pricing scenarios and estimate financial impact
- Practice using SQL features like CTEs, window functions, and stored procedures

---

## Tools & Skills Used

- **PostgreSQL / PLpgSQL**
- SQL views, window functions, and CASE statements
- Common Table Expressions (CTEs)
- Percentile-based stats (PERCENTILE_CONT)
- Business modeling with SQL logic
- Risk stratification and demographic segmentation

---

## Key Questions I Explored

| Category | Question |
|---------|----------|
| **Health Trends** | Do smokers really pay more? Which BMI ranges are most costly? |
| **Demographics** | Which regions or age groups drive the most spending? |
| **Risk Modeling** | Can I build a simple but effective risk score using age, BMI, and smoking status? |
| **Business Strategy** | What happens to revenue if obese patients reduce BMI? Or if families get discounts? |
| **Equity & Access** | Are costs distributed fairly by region, age, or gender? |

---

## Sample Analyses

- **Correlation:** Found a moderate positive correlation (r = 0.59) between BMI and medical charges
- **Risk Scoring:** Created a custom index based on smoking, age, and BMI levels
- **Simulation:** Modeled a 10% discount for non-smoking families and projected revenue loss
- **Regional Insights:** Identified the region with the highest concentration of high-cost patients
- **Scenario Planning:** Compared flat-rate vs. age-tiered pricing systems to evaluate revenue shifts

---

## Project Structure

- `insurance.sql`: Main script with schema, queries, views, functions, and simulations
- All queries are labeled, grouped, and commented for clarity
- Ready to run on any PostgreSQL database with a compatible dataset

---

## Notes on the Data

- The dataset contains fields like: `age`, `sex`, `bmi`, `children`, `smoker`, `region`, and `charges`
- Data is anonymized/synthetic and used for educational purposes only.
