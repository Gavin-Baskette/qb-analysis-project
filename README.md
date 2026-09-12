# QB Analysis Project: What Drives Winning?

## Overview

Which quarterback statistics are most strongly related to winning?

This project examines the relationship between QB performance metrics and team winning percentage using NFL regular-season data from **2021–2025**.

I analyzed **183 QB-seasons** with at least 200 dropbacks and compared three advanced metrics with five traditional quarterback statistics.

## Research Questions

* Which QB metrics have the strongest relationship with team winning percentage?
* Do advanced metrics provide a stronger relationship with winning than traditional statistics?

## Key Findings

| Metric          | Correlation with Winning |
| --------------- | -----------------------: |
| EPA / Dropback  |                **0.692** |
| Passer Rating   |                **0.629** |
| Success Rate    |                **0.623** |
| Yards / Attempt |                **0.575** |
| TD %            |                **0.574** |
| CPOE            |                **0.468** |
| Completion %    |                **0.412** |
| INT %           |               **−0.240** |

* **EPA per dropback** had the strongest relationship with winning among the eight metrics examined.
* EPA was significantly more strongly correlated with winning than passer rating (**r = 0.692 vs. 0.629, p = 0.017**).
* EPA explained **47.9%** of the variation in team winning percentage, compared with **39.6%** for passer rating.
* Adding passer rating to EPA increased R² only slightly, from **0.479 to 0.481**.
* Success Rate and CPOE also had stronger numerical relationships with winning than their selected traditional counterparts, although those differences were not statistically significant.

## Data & Methodology

NFL regular-season play-by-play and schedule data from **2021–2025** were obtained using `nflfastR` and `nflreadr`.

The unit of analysis is the **QB-season**, with a minimum of 200 dropbacks.

**PostgreSQL** was used to transform the play-by-play data into QB-season statistics and join them with team records. **R** was used for correlation analysis, statistical testing, regression modeling, and visualization.

## Tools

**R · PostgreSQL · DBeaver · nflfastR · nflreadr · dplyr · ggplot2 · cocor**

## Files

* `qb_analysis.R` — R analysis, statistical tests, regressions, and visualizations
* `qb_analysis.sql` — PostgreSQL data transformation and analysis workflow

## Author

**Gavin Baskette**

