# COVID19_Global_Surveillance_2025
COVID-19 high-risk country analysis using SAS and Tableau

**Author:** Gayathri Karthikeyan, BDS, MPH  
**Tools:** SAS (Data Cleaning, SQL, Macros, Statistical Analysis), Tableau (Visualization)  
**Date:** 12th August 2025  

---

##  Overview
This project analyzes global COVID-19 epidemiologic data to identify **high-risk countries in 2025** using descriptive statistics, non-parametric tests, and predictive modeling.  
The workflow integrates **SAS** for data processing and statistical analysis, and **Tableau** for interactive visualization.

**Objective:**  
- Identify high-risk countries for COVID-19 in 2025  
- Explore epidemiologic metrics such as **Case Fatality Rate (CFR)**, **Recovery Rate**, **Deaths per 1M population**, and **Testing Rates**  
- Develop reproducible analysis pipelines using SAS and create an interactive Tableau dashboard for insights

---

## Data Source
- **Dataset:** Kaggle Open Data Repository (COVID-19 Statistics 2025 snapshot)  
- **Coverage:** Global data, country-level records  
- **Variables Used:**
  - TotalCases, TotalDeaths, TotalRecovered
  - Deaths_per1M_pop, Tests_per1M_pop
  - Population, Continent
  - Derived variables: CFR, RecoveryRate, log(Population)

---

##  Workflow
### 1. Data Cleaning (SAS)
- Renamed variables to be SAS-compatible
- Corrected country names and missing entries
- Converted all numeric fields to proper numeric types
- Standardized missing values (`.` in SAS)
- Feature engineering:
  - `log_pop = log(Population + 1)` to handle skewness

### 2. SQL Analysis (SAS PROC SQL)
- Continent-level summaries
- Top/Bottom rankings for:
  - Cases per 1M
  - Deaths per 1M
  - CFR and Recovery Rate
  - Testing rates

### 3. SAS Macros
- `%covid_filter(var, threshold)`
- `%above_avg(var)`
- `%histogram(var)`
- `%compare_vars(var1, var2)`

### 4. Statistical Analysis
- **Wilcoxon Rank-Sum Test**: Compared Deaths_per1M_pop between high- and low-risk countries  
- **Logistic Regression Models**:
  - Model 1: `HighRisk ~ CFR + log_pop`
  - Model 2: `HighRisk ~ RecoveryRate + log_pop`

### 5. ODS Export
- Automated export of analysis outputs to Excel for reporting

### 6. Tableau Visualization
- Created interactive dashboard highlighting:
  - High case burden countries
  - High mortality countries
  - CFR & Recovery Rate extremes
  - Testing disparities
  - Continental patterns

---

## Key Insights
- **Europe** dominated in high case and high death lists.
- **Small population countries** often ranked high in per-capita metrics.
- **High CFR countries** (e.g., Yemen, Sudan) often had low testing rates and limited healthcare access.
- **High Recovery Rate countries** had strong healthcare systems or early containment measures.
- **Testing rates** varied widely, indicating surveillance disparities.

---

##  Contact
- **Email:** gk1998@bu.edu  
