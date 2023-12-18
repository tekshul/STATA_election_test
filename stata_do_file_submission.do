
*SECTION 1 - DATA CLEANING 

*QUESTION 1: import the dataset provided. 
*Since I am using STATA 11 the data is converted to csv file before importing
insheet using "C:\Users\AnshulRaiSharma\OneDrive - Azim Premji Foundation\Desktop\IFMR\Data for Stata Test_2018.csv", comma
*overview of the dataset

*QUESTION 2: merge files 
describe
*I imported the other data file 'Town Names for Stata Test 2018' into STATA and names it Townname.dta
*Since I need to import Town Names data here, I rename town_id variable so that the key variable matches in both files. 
rename town_id townid
merge m:1 townid using Townname.dta

*find the right directory for the file
cd "C:\Users\AnshulRaiSharma\Downloads\S11-20231118T131352Z-001\S11"
merge m:1 townid using Townname.dta
keep if _merge == 3 
*52 observations deleted
describe
*remove the variable _merge
drop _merge
save stata_submission1.dta, replace

*QUESTION 3: create a district variable as numerical

*check the townid variable and data
tabulate townid, nolabel

*convert the string variable district into a numeric variable, creating a new variable called district_num 
*each unique string value in district is assigned a unique numeric code.
encode district, gen(district_num)

*Now I show the show the correspondence between the numeric values and the original string values of the district variable.
label list district_num

*QUESTION 4: Unique ID for each observation

*creates a new variable townid_str by converting the numeric townid variable into a string format
*The format "%03.0f" ensures that the numeric values are formatted as strings with at least three digits 

gen townid_str = string(townid, "%03.0f")

*Now, since we have almost 7,000 observations, I add four digits to the above created string. 
gen obs_num = string(_n, "%04.0f")
gen unique_id = townid_str + obs_num

describe
*Since I have unique_id for each obeservation, with the first three digits as townid, I now delete all the intermediate variables
drop townid_str obs_num

*QUESTION 5: Handling missing data

*As mentioned in the instructions, I parse through the values to check for '-999' and list them out. 
*Based on the nature and scale of missing data, I will approach the problem 
foreach var of varlist _all {

    count if `var' == -999

    if r(N) > 0 {

        display "`var' has " r(N) " missing values represented as -999"

     }

 }

list townid if registered_total == -999 | registered_male == -999 | registered_female == -999
* A total of 20 observations have the above three variables listed as -999. These are 20 obervations out of 6,970 observations. 
* I could ignore these values since it is a small number, but I need to ensure that all of them do not belong to one townid which might skew the analysis
* And so I list the missing values and their townids. 
local townids 173 175 177 195 198 200 211 213 235 236 237 238
 foreach id of local townids {
 count if townid == `id'
  local num_obs = r(N)
    display "townid `id': `num_obs' observations"
 }
 *Now its clear that each of these towns has over 200 observations and out of that only one is -999 in each case, so I delete these observations. 
foreach var of varlist _all {
  drop if `var' == -999
  }
  
 *while I am  check for missing data, it is also useful to account for negative values. 
foreach var of varlist _all {
  drop if `var' < 0
  }
  *QUESTION 6: Dummy variable 
  
  *Create a dummy indicator variable based on townid variable. 
  *Each dummy variable corresponds to a unique value of townid, with the variable name prefixed by townid_dumvar
tabulate townid, generate(townid_dumvar)
describe townid_dumvar*



*QUESTION 7: Adding labels 

*Here, based on the variable set I have as of now, I enlist each variable in one of the three labels provided.
describe

local id_vars "townid townname district district_num unique_id"
 foreach var in `id_vars' {
    label variable `var' "ID variable"
 }
local electoral_vars "turnout_total turnout_male turnout_female registered_total registered_male registered_female"
 foreach var in `electoral_vars' {
     label variable `var' "Electoral data" 
	 }
	 
local intervention_vars "treatment treatment_phase"

*Here I run into an unclosed loop that causes errors. I use 'end' command to break 
*and carry on the analysis

foreach var in `intervention_vars' {
    label variable `var' "Intervention"

 }
describe

*Question 8: Labels for treatment variables
label define treatment_labels 0 "Control" 1 "Treatment"
label values treatment treatment_labels
describe
save stata_submission1.dta, replace

*SECTION 2: Descriptive statistics 

*QUESTION 9  : average turnout rate. I create a new variable turnout_rate and find its average value across the observations. 
summarize turnout_total
*average turnout rate is 57.37 % from the table. 
gen turnout_rate = turnout_total/registered_total
drop if registered_total ==0

summarize turnout_rate
*I notice that the highest turnout_rate is 1 (100% turnout)

count if turnout_rate == 1
*A total of 20 observations have 100 % turnout, I list them out and check some of these manually in the dataset

list townid district unique_id if turnout_rate == 1

*I also list out the observations that have zero turnout
list townid district unique_id if turnout_rate == 0

*QUESTION 10: number of booths in across phases in each group. 
tabulate treatment treatment_phase
*from the table, I gather that the number of booths are evenly distributed across the two phases and groups. 

*QUESTION 11: average turnout rate for females for each district which has a total turnout rate of 75% or above

*I first need to check which are the districts which qualify under the above conditions. 
*sum up turnout_total and registered_total for each district to calculate turnout_rate_district
egen turnout_total_sum = sum(turnout_total), by (district)
egen registered_total_sum = sum(registered_total), by (district)
gen turnout_rate_district = (turnout_total_sum/registered_total_sum)*100

sort district
*Since I calculate each district's turnout_rate, I list out each turnout_rate when it appears the first time (to avoid a longer list). 
by district: list district turnout_total_sum registered_total_sum turnout_rate_district if _n==1
*Here, I notice that none of the districts have a total turnout_rate higher of 75% or above. 
*Therefore, the average turnout rate for females asked in the question is a null set. 

*QUESTION 11: Average turnout rate for women. 

*First, I create a table to view the changes in mean values across genders by treatment
table treatment, contents (mean turnout_male mean turnout_female mean turnout_total)
*from the table, it is clear that the female turnout rises from 207 to 215 and total turnout rises from 461 to 469 betwee control group and treatment group. 

*I create a new variable to account for average turnout_rate of female
gen turnout_rate_female = turnout_female / registered_female

*Here my intention is to check if the increase is significant. 
*I seek to do a t-test here since these two groups (control and treatment) are indepedent of each other (condition of RCT)
*They are also large groups as seen in the table for question 10, and therefore the condition of normality is satisfied. 
*However, the condition for equalance of variance still needs to be accounted for. I check this condition using levene's test. Source: https://www.statology.org/levenes-test-stata/ 

robvar turnout_rate_female, by (treatment)
*The p-values for the Levene's test (or its robust variants) are all below 0.05, indicating that there is a statistically significant difference in the variances of female turnout between the treatment and control groups. 
*This means that the assumption of equal variances, which is required for a standard independent samples t-test, is violated.
*To account for this difference of variance, I use welch's ttest for STATA. Source: https://www.statology.org/welchs-t-test-stata/

ttest turnout_rate_female, by(treatment) unequal
*negative sign of the mean difference (-0.0139117) indicates that the turnout rate for females is lower in the control group 
*compared to the treatment group.

*p-value for a two-tailed test is 0.0384, which is less than the conventional alpha level of 0.05. 
*This suggests that the difference in mean turnout rates between the two groups is statistically significant.

save stata_submission1.dta, replace

*QUESTION 13: Bar graph to show difference across treatment and gender

*I am using a make-shift approach in making graphs due to time-constraints.
*I essentially create mean variables for each gender and turnout_total, plot them separately and then combine those graphs. 
*if I had more time, I would think of different ways (densities?) of representing the rise in average turnout and total turnout, rather than comparing absolute mean values. 
collapse (mean) turnout_male turnout_female turnout_total, by(treatment)
bysort treatment: egen mean_turnout_male = mean(turnout_male)
bysort treatment: egen mean_turnout_female = mean(turnout_female)
 bysort treatment: egen mean_turnout_total = mean(turnout_total)
graph bar mean_turnout_male, over(treatment) title("Male Turnout by Treatment") name(maleTurnout, replace)
graph bar mean_turnout_female, over(treatment) title("Female Turnout by Treatment") name(femaleTurnout, replace)
graph bar mean_turnout_total, over(treatment) title("Total Turnout by Treatment") name(totalTurnout, replace)
graph combine maleTurnout femaleTurnout totalTurnout, ycommon xsize(15) ysize(10) title("Turnout by Gender and Treatment Group")
graph save Graph "C:\Users\AnshulRaiSharma\OneDrive - Azim Premji Foundation\Desktop\IFMR\submission\stata_submission_graph.gph"

*
use stata_submission1.dta, clear

ssc install outreg2
regress turnout_total treatment registered_male registered_female registered_total townid_dumvar*

*Question 14:The regression results document is attached separately in my submission in a word doc.
*Question 15: Mean turnout of control group: 461.281 
*Question 16: Dependedent Variable: turnout_total
*Question 17 and 18: 
* The key variable is 'treatment' which has coefficient = 8.251 and p value = 0.018
*The treatment increases the total turnout by approximately 8.25 voters, controlling for other variables. 
*The effect is statistically significant (p < 0.05).
*The model explains approximately 11.02% of the variance in total voter turnout (the R-squared value = 0.1102 ).
*Question 18: From the above coefficient and p-value, it is clear that the intervention 
*associated with the treatment booths had a statistically significant effect on increasing voter turnout compared to the control booths, 



outreg2 using results.doc, replace word ctitle("Regression Results") title("Effects of Treatment on Total Turnout") keep(treatment registered_male registered_female registered_total) noobs dec(3)
log close
