/*Creating a library named "covid_project"*/ 
libname project '/home/u63752988/INTERVIEW';

/*Importing csv file*/ 
proc import out= project.covid
datafile="/home/u63752988/INTERVIEW/Covid_stats_Jan2025.csv"
DBMS= csv replace; 
getnames=yes; 
run; 

/*------------------------------------------------
SECTION: DATA CLEANING & MISSING DATA HANDLING
--------------------------------------------------*/

/*Viewing Missing Summary */
proc means data=project.covid n nmiss;
    var TotalCases TotalDeaths TotalRecovered Deaths_per1M_pop Population;
    title "Missing Values Check: Key Variables";
run; 

/*Creating a cleaned version of the dataset by excluding rows with missing values 
           ONLY where required for downstream analysis*/

data project.covid_clean;
    set project.covid;

    /* Exclude if TotalCases or TotalDeaths is missing for CFR calculation */
    if missing(TotalCases) or missing(TotalDeaths) then CFR_flag = 0; else CFR_flag = 1;

    /* Exclude if TotalCases or TotalRecovered is missing for Recovery Rate */
    if missing(TotalCases) or missing(TotalRecovered) then RR_flag = 0; else RR_flag = 1;

    /* Flag rows with missing Deaths_per1M_pop for HighRisk assignment */
    if missing(Deaths_per1M_pop) then HR_flag = 0; else HR_flag = 1;

    /* Keep log_pop only when Population is not missing */
    if not missing(Population) then log_pop = log(Population + 1);
run;

/* creating filtered datasets for specific models*/ 

data project.cfr_model_data;
    set project.covid_clean;
    if CFR_flag = 1;
run;

data project.rr_model_data;
    set project.covid_clean;
    if RR_flag = 1;
run;

data project.highrisk_data;
    set project.covid_clean;
    if HR_flag = 1;
run;


/*--------------------------------------------
SECTION: SAS SQL
----------------------------------------------*/ 

/* Aggregating total cases, total deaths, and average deaths per million population for each continent */
proc sql;
    select Continent,
           sum(TotalCases) as Total_Cases,
           sum(TotalDeaths) as Total_Deaths,
           mean(Deaths_per1M_pop) as Avg_Deaths_per_1M
    from project.covid 
    group by Continent
    order by Total_Cases desc; 
     
/* top 10 countries with highest cases per 1 million population */
proc sql outobs=10;
  select Country, TotalCases_per1M _pop
  from project.covid
  where not missing(TotalCases_per1M _pop)
  order by TotalCases_per1M _pop desc;  

/* top 10 countries with highest deaths per 1 million population */
proc sql outobs=10;
    select Country, Deaths_per1M_pop
    from project.covid
    where not missing(Deaths_per1M_pop)
    order by Deaths_per1M_pop desc; 
  
 /* TOP 5 CFR */
proc sql outobs=5;
    select Country, TotalCases, TotalDeaths,
           (TotalDeaths / TotalCases) * 100 as CFR_Percent format=6.2
    from project.covid
    where TotalCases > 0
    order by calculated CFR_Percent desc;

/* BOTTOM 5 CFR */
proc sql outobs=5;
    select Country, TotalCases, TotalDeaths,
           (TotalDeaths / TotalCases) * 100 as CFR_Percent format=6.2
    from project.covid
    order by CFR_Percent asc; 
    
/* TOP 5 Recovery Rate */
proc sql outobs=5;
    select Country, TotalCases, TotalRecovered,
           (TotalRecovered / TotalCases) * 100 as RecoveryRate format=6.2
    from project.covid
    where TotalCases > 0 and not missing(TotalRecovered)
    order by calculated RecoveryRate desc;

/* BOTTOM 5 Recovery Rate (with basic quality filter) */
proc sql outobs=5;
    select Country, TotalCases, TotalRecovered,
           (TotalRecovered / TotalCases) * 100 as RecoveryRate format=6.2
    from project.covid
    where TotalCases >= 100000 and not missing(TotalRecovered)
    order by calculated RecoveryRate asc;

/* TOP 5 Tests per Million (uses existing column if present, else computes) */
proc sql outobs=5;
    select Country,
           /* use existing per-million if available, else compute */
           coalesce(Tests_per1M_pop, (TotalTests / Population) * 1e6)
               as Tests_per_Million format=comma12.0
    from project.covid
    where (not missing(Tests_per1M_pop) or (TotalTests > 0 and Population > 0))
    order by calculated Tests_per_Million desc;


/* BOTTOM 5 Tests per Million (exclude missing/zero pop) */
proc sql outobs=5;
    select Country,
           coalesce(Tests_per1M_pop, (TotalTests / Population) * 1e6)
               as Tests_per_Million format=comma12.0
    from project.covid
    where (not missing(Tests_per1M_pop) or (TotalTests > 0 and Population > 0))
    order by calculated Tests_per_Million asc;

/*---------------------------------------------
SECTION: SAS MACRO
-----------------------------------------------*/ 

/*-----------------------------------------------------------------------------------------
 Macro Name   : covid_filter
 Purpose      : Filters the COVID dataset based on a user-defined variable and threshold.
                This macro allows dynamic selection of any numeric variable (e.g., TotalCases,
                Diff_from_Avg) and prints countries where the variable exceeds the threshold.
 Parameters   :
     - var        : Name of the variable to apply the threshold on (e.g., TotalCases)
     - threshold  : Numeric cutoff value for filtering
-----------------------------------------------------------------------------------------*/   
%macro covid_filter(var, threshold);

data covid_filtered;
    set project.covid;
    if &var > &threshold;
run;

proc print data=covid_filtered;
    title "Countries with &var > &threshold";
run;

%mend; 

%covid_filter(TotalCases, 1000000); 
/*-----------------------------------------------------------------------------------------
 Macro Name   : above_avg
 Purpose      : Displays all countries from the COVID dataset where the specified variable 
                is greater than the global average of that variable.
                Useful for identifying countries with higher-than-average metrics such as 
                TotalCases, TotalDeaths, or any other numeric variable.
 Parameters   :
     - var        : Name of the numeric variable to compare against its mean 
-----------------------------------------------------------------------------------------*/
%macro above_avg(var);

proc sql;
    select Country,&var
    from project.covid
   where not missing(&var)
      and &var > (select mean(&var) from project.covid);
%mend above_avg;

%above_avg(TotalCases);


/*-----------------------------------------------------------------------------------------
 Macro Name   : histogram
 Purpose      : Generates a histogram and summary statistics for a specified numeric 
                variable from the COVID dataset. This macro provides a visual distribution 
                along with key descriptive measures for the variable of interest.
 Parameters   :
     - var        : Name of the numeric variable to analyze (e.g., TotalCases)
-----------------------------------------------------------------------------------------*/

%macro histogram(var);

proc univariate data=project.covid;
     var &var;
    histogram;
    inset mean std / position=ne;
    title "Distribution Analysis for &var";
run;

%mend; 

/*-----------------------------------------------------------------------------------------
 Macro Name   : compare_vars
 Purpose      : Compares two numeric variables in the COVID dataset and lists countries 
                where the first variable exceeds the second.
 Parameters   :
     - var1 : The first numeric variable to compare (e.g., TotalCases)
     - var2 : The second numeric variable to compare (e.g., TotalDeaths)
     
 Output       : Prints a table of countries where var1 > var2
------------------------------------------------------------------------------------------*/
%macro compare_vars(var1, var2);

proc sql;
    select Country, &var1, &var2
    from project.covid
    where not missing(&var1) 
      and not missing(&var2)
      and &var1 > &var2;
%mend;

%compare_vars(TotalCases, TotalDeaths);

/*-------------------------------------------
SECTION: SAS STAT 
----------------------------------------------*/ 

/* Displaying descriptive statistics (mean, median, min, max, std) for all numeric variables*/

proc means data=project.covid n mean std median min max;
    var _numeric_;
    title "Descriptive Statistics for All Numeric Variables in COVID Dataset";
run;

/* Generates frequency tables for all categorical variables in the COVID dataset */

proc freq data=project.covid;
    tables Continent;
run; 
 
/*-----------------------------------------------------------------------------------------
 Test Type    : Wilcoxon Rank-Sum Test (non-parametric alternative to t-test)
 Purpose      : To compare whether there is a significant difference in 'Deaths_per1M_pop'
                between two groups — High-risk vs Low-risk countries, defined by TotalCases.
 Reason       : We are using this test instead of a t-test because 'Deaths_per1M_pop' is
                not normally distributed, making the Wilcoxon test more appropriate.
------------------------------------------------------------------------------------------*/

/* Creating a binary group variable: HighRisk */ 
/* Getting the median of Deaths_per1M_pop */
proc means data=project.covid mean median std min max;
    var Deaths_per1M_pop;
run;

/*Using Median (869) as Cutoff*/ 
data project.covid_tests;
    set project.covid_clean;
    if HR_flag = 1 then do;
        if Deaths_per1M_pop > 869 then HighRisk = 1;
        else HighRisk = 0;
    end;
run;

/* Wilcoxon rank-sum test */
proc npar1way data=project.covid_tests wilcoxon;
    class HighRisk;
    var Deaths_per1M_pop;
run;  

/* Creating a new variable: log of Population */
data project.covid_simplified;
    set project.covid_tests;
    log_pop = log(Population + 1);  /* +1 to avoid log(0) */
run; 

/*-----------------------------------------------------------------------------------------
 Test Type    : Logistic Regression
 Purpose      : To predict whether a country is high-risk based on how deadly COVID is 
                (i.e., what proportion of infected individuals have died), controlling for 
                population size.
 Variables    : 
   - CFR: Case Fatality Rate (TotalDeaths / TotalCases)
   - log_pop: Log-transformed population to reduce skewness
------------------------------------------------------------------------------------------*/
data project.logistic_cfr;
    set project.covid_clean;
    if CFR_flag = 1 and HR_flag = 1 and not missing(log_pop);
    
    /* Derived variable */
    CFR = TotalDeaths / TotalCases;

    /* HighRisk assignment */
    if Deaths_per1M_pop > 869 then HighRisk = 1;
    else HighRisk = 0;
run;
/* Running logistic regression */
proc logistic data=project.logistic_cfr;
    model HighRisk(event='1') = CFR log_pop;
    title "Logistic Regression: CFR and log(Pop)";
run;

/*-----------------------------------------------------------------------------------------
 Test Type    : Logistic Regression
 Purpose      : To predict whether a country is high-risk based on how well patients recover 
                from COVID-19, controlling for population size.
 Variables    : 
   - RecoveryRate: Proportion of recovered cases out of total confirmed cases 
                   (TotalRecovered / TotalCases)
   - log_pop: Log-transformed population to reduce skewness
------------------------------------------------------------------------------------------*/
data project.logistic_rr;
    set project.covid_clean;
    if RR_flag = 1 and HR_flag = 1 and not missing(log_pop);

    /* Derived variable */
    RecoveryRate = TotalRecovered / TotalCases;

    /* HighRisk assignment */
    if Deaths_per1M_pop > 869 then HighRisk = 1;
    else HighRisk = 0;
run;

/* Running logistic regression */
proc logistic data=project.logistic_rr;
    model HighRisk(event='1') = RecoveryRate log_pop;
    title "Logistic Regression: Recovery Rate and log(Pop)";
run;

/*-------------------------------------------
SECTION: ODS EXPORT  
----------------------------------------------*/ 

/* ODS settings: Exporting to Excel */
ods excel file="/home/u63752988/INTERVIEW/COVID_SQL_SUMMARY.xlsx" 
    style=statistical options(sheet_interval="proc");
    
/*------------------------------------------
Sheet 1: Countries with >100,000 cases
-------------------------------------------*/
ods excel options(sheet_name="Cases > 100k");
proc sql;
    select Country, TotalCases
    from project.covid
    where TotalCases > 100000
    order by TotalCases desc;
quit;

/*------------------------------------------
Sheet 2: Continent-wise Aggregates
-------------------------------------------*/
ods excel options(sheet_name="Continent Summary");
proc sql;
    select Continent,
           sum(TotalCases) as Total_Cases,
           sum(TotalDeaths) as Total_Deaths,
           mean(Deaths_per1M_pop) as Avg_Deaths_per_1M
    from project.covid 
    group by Continent
    order by Total_Cases desc;
quit;

/*------------------------------------------
Sheet 3: Top 10 Countries by Deaths/1M
-------------------------------------------*/
ods excel options(sheet_name="Top 10 Deaths per 1M");
proc sql outobs=10;
    select Country, Deaths_per1M_pop
    from project.covid
    where not missing(Deaths_per1M_pop)
    order by Deaths_per1M_pop desc;
quit;

/*------------------------------------------
Sheet 4: Cases vs Global Average
-------------------------------------------*/
ods excel options(sheet_name="Cases vs Global Avg");
proc sql;
    select 
        Country, 
        TotalCases,
        (select avg(TotalCases) from project.covid) as GlobalAvg,
        abs(TotalCases - (select avg(TotalCases) from project.covid)) as Diff_from_Avg
    from project.covid;
quit;

/*------------------------------------------
Sheet 5: Wilcoxon Test (HighRisk vs Deaths/1M)
-------------------------------------------*/
ods excel options(sheet_name="Wilcoxon Test");
proc npar1way data=project.covid_tests wilcoxon;
    class HighRisk;
    var Deaths_per1M_pop;
run;

/*------------------------------------------
Sheet 6: Logistic Regression - CFR
-------------------------------------------*/
ods excel options(sheet_name="Logistic CFR");
proc logistic data=project.logistic_cfr;
    model HighRisk(event='1') = CFR log_pop;
run;

/*------------------------------------------
Sheet 7: Logistic Regression - Recovery Rate
-------------------------------------------*/
ods excel options(sheet_name="Logistic RR");
proc logistic data=project.logistic_rr;
    model HighRisk(event='1') = RecoveryRate log_pop;
run;

/* Closing ODS output */
ods excel close;


