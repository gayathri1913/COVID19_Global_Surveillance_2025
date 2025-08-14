[README.md](https://github.com/user-attachments/files/21765316/README.md)
# COVID-19 Global Surveillance Analysis — SAS Project

A reproducible SAS workflow analyzing a January 2025 country-level COVID-19 dataset.  
It showcases **SQL-based exploration, descriptive statistics, Spearman rank correlation, and logistic regression** (with basic feature engineering), plus automated **ODS Excel** reporting.

---

##  Repository Contents
- `Project.sas` — main SAS script (import → EDA → correlation → modeling → ODS export).
- `data/` — place your input CSV here (e.g., `Covid_stats_Jan2025.csv`).
- `outputs/` — optional folder for Excel exports/screenshots (created by you).

> **Note:** The script uses a SAS library path under your home directory. Update paths as needed.

---

##  Data
- **Expected file:** `Covid_stats_Jan2025.csv`
- **Unit of analysis:** Country
- **Key columns used in the script:**
  - `Country`, `Continent`, `Population`
  - `TotalCases`, `TotalDeaths`, `TotalTests`
  - Optional per‑million fields (if present): `TotalCases_per1M_pop`, `Deaths_per1M_pop`, `Tests_per1M_pop`

The script also derives:
- `log_pop = log(Population + 1)` to reduce skew (avoids log(0)).
- `CFR = TotalDeaths / TotalCases` (basic ratio; rows with invalid denominators are filtered).
- `HighTesting` — a binary flag using the **median of TotalTests** as the cutoff (median observed in code: `2011641.00`).

---

##  Workflow Overview

### 1) Library & Import
Defines a SAS library and imports the CSV into `project.covid` via `PROC IMPORT`.

### 2) SQL Exploration (`PROC SQL`)
Examples implemented in the script include:
- **Continental aggregates** of cases/deaths (and averages per million when present).
- **Top/Bottom lists** such as *Tests per Million* using a safe fallback:
  ```sql
  coalesce(Tests_per1M_pop, (TotalTests / Population) * 1e6)
  ```
- **Global comparison views** (e.g., country values vs global means).

### 3) Descriptives & Distributions
- `PROC MEANS` for summary statistics (N, mean, std, median, min, max).
- `PROC UNIVARIATE` with histograms via a small macro to examine variable distributions.
- `PROC FREQ` for categorical summaries (e.g., `Continent`).

### 4) **Spearman Rank Correlation** (`PROC CORR … spearman`)
Evaluates the **monotonic association** (non‑parametric) between **`TotalDeaths`** and **`TotalTests`** using:
```sas
proc corr data=project.covid_clean spearman;
    var TotalDeaths TotalTests;
run;
```
> This is **Spearman’s correlation (ρ)** — appropriate when the relationship may be non‑linear or when outliers could impact Pearson’s r.

### 5) **Binary Classification Setup** (HighTesting)
- Calculates the **median** of `TotalTests`.
- Creates `HighTesting = (TotalTests > median)`; missing values handled explicitly.

### 6) **Logistic Regression** (`PROC LOGISTIC`)
Predicts **HighTesting (event='1')** from **`CFR`** and **`log_pop`**:
```sas
proc logistic data=project.logistic_cfr;
    model HighTesting (event='1') = CFR log_pop;
    title "Logistic Regression: CFR and log(Pop)";
run;
```
Rationale:
- `CFR` represents observed severity; in many surveillance contexts, higher severity associates with increased testing activity.
- `log_pop` captures population scale without skew dominance.

> The script prepares an analysis table (`project.logistic_cfr`) by filtering valid rows, computing `CFR`, and carrying forward `log_pop` from the prior step.

### 7) **Automated Reporting** (ODS Excel)
Exports key views/results into an Excel workbook (`ODS EXCEL`), including sheets such as:
- **Cases > 100k**
- **Continent Summary**
- **Cases vs Global Avg**
- **Spearman’s correlation**
- **Logistic CFR**

You can adjust `ods excel file="..."` to point to your own outputs directory.

---

## Interpreting the Models (at a glance)
- **Spearman (TotalDeaths vs TotalTests):**
  - ρ (rho) > 0 → countries with more deaths also tend to report more tests (consistent with greater surveillance load or epidemic scale).
  - ρ ≈ 0 → little monotonic association after rank‑transform.
- **Logistic Regression (HighTesting ~ CFR + log_pop):**
  - **OR > 1 for CFR** → higher CFR associated with **greater odds** of being high‑testing.
  - **OR > 1 for log_pop** → larger populations associated with **greater odds** of being high‑testing.
  - Include AUC / c‑statistic and LR chi‑square from your run to summarize fit and discrimination.

> Keep in mind: associations here are **observational** and can reflect surveillance intensity, data completeness, and confounding (e.g., health system capacity).

---

## ▶ How to Run
1. **Place the CSV** in a known path (e.g., `data/Covid_stats_Jan2025.csv`).
2. **Open `Project.sas`** in SAS (SAS 9.4 or SAS OnDemand).
3. **Update paths** in:
   - `libname project '...';`
   - `proc import datafile=".../Covid_stats_Jan2025.csv";`
   - `ods excel file=".../COVID_SQL_SUMMARY.xlsx";` (optional output path)
4. **Submit the script** top‑to‑bottom.
5. Review the **ODS Excel** workbook for aggregated tables, correlation output, and logistic results.

---

##  Macros Included
- `%covid_filter(var, threshold)` — prints countries where `var > threshold`.
- `%above_avg(var)` — lists countries where `var` exceeds the **global mean**.
- `%histogram(var)` — quick distribution plot via `PROC UNIVARIATE`.
- `%compare_vars(var1, var2)` — pulls side‑by‑side pairs with non‑missing values.

These small utilities make it easy to repeat the same checks across multiple fields.

---

##  Suggested Folder Layout
```
/project-root
├─ Project.sas
├─ data/
│  └─ Covid_stats_Jan2025.csv
└─ outputs/
   └─ COVID_SQL_SUMMARY.xlsx   (generated by ODS EXCEL)
```

---

## Notes & Assumptions
- The script tolerates missingness by **checking non‑missing inputs** before ratios and by using `coalesce(...)` for per‑million metrics when needed.
- The `HighTesting` threshold uses the dataset **median** of `TotalTests`. You can switch to a percentile or policy target if desired.
- `log_pop` uses a **+1 offset** to avoid log(0).

---

##  Author
**Gayathri Karthikeyan** — MPH (Epi & Biostats)  
- SAS / SQL / Tableau | Epidemiology & Public Health Analytics
- Email: gk1998@bu.edu

---
