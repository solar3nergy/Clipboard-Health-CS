# Clipboard-Health-CS : A Case Study for Addressing Churn Rate due to HCP cancellations

Clipboard Health Marketplace Reliability Analysis

Project Overview:

This repository contains a comprehensive data analysis project examining marketplace reliability issues in a two-sided healthcare staffing platform. The analysis identifies root causes of late cancellations and no-call-no-shows (NCNS), quantifies their business impact, and proposes data-driven solutions to improve platform reliability and reduce facility churn.

Business Context: 

Healthcare facilities rely on the platform to fill critical staffing needs. When healthcare professionals cancel shifts at the last minute or fail to show up, it creates operational chaos and drives facility churn. This project analyzes 127,005 bookings and 78,073 cancellations to uncover patterns and propose actionable interventions.

Key Findings:

Through systematic SQL analysis of Cleveland market data (Aug 2021 - Apr 2022), I discovered:

Root Cause Identified: 

Healthcare professionals who book shifts within 6 hours of start time represent only 3.25% of bookings but account for 5.1% of all late cancellations—punching 57% above their weight in creating reliability problems.

Financial Impact: 54 facilities experiencing multiple reliability incidents represent $5.55M in annual GMV at elevated churn risk (35% monthly churn vs. 8-15% baseline).

Recommended Solution: 

Implement a 6-hour minimum booking window to prevent last-minute bookings while preserving flexibility for 96.75% of current booking behavior.
Projected ROI: $1.16M in incremental annual net revenue at 32x first-year ROI.

Repository Contents

SQL Analysis Files
01_data_exploration.sql

Basic dataset profiling and validation
Shift characteristics analysis by type, length, and pay rate
Overall marketplace health metrics
Foundation for deeper analysis
02_cancellation_analysis.sql

Categorization of cancellations by lead time and severity
Financial impact calculation (GSV at risk)
Cancellation distribution analysis
Identifies magnitude of the reliability problem
03_hcp_behavior_analysis.sql

HCP cancellation frequency distribution
Repeat offender concentration analysis (80/20 rule testing).
Reliability rate calculations by booking volume
Tests "bad actor" hypothesis.
04_booking_leadtime_analysis.sql 

⭐ CRITICAL ANALYSIS

Correlation between booking lead time and cancellation behavior
Cancellation rates by booking window
Source analysis: Where do late cancellations originate?
This analysis revealed the core insight that drove the solution.
05_facility_impact_analysis.sql

Identification of affected facilities (2+ incidents).
GMV at risk calculation.
Facility-level cancellation patterns.
Quantifies business impact for ROI modeling.
06_shift_characteristics_analysis.sql

Cancellation rates by shift type (AM/PM/NOC/CUSTOM).
Analysis by shift length and charge rate.
Day-of-week patterns.
Rules out alternative hypotheses.
07_comprehensive_summary.sql

End-to-end marketplace health dashboard query.
Aggregates all key metrics.
Production-ready monitoring query.
Technical Approach

Data Architecture

The analysis leverages three primary datasets:

Cleveland_shifts_logs (41,040 shifts)
Shift-level data: timing, type, rates, completion status
Primary table for GMV calculations and facility activity
Booking_logs v1 (127,005 bookings)
HCP booking events with lead times
Critical for behavioral pattern analysis
Cancel_logs v1 (78,073 cancellations)
Cancellation events with action types and lead times
Core dataset for reliability analysis

Analytical Methodology
Phase 1: Problem Quantification

Established baseline metrics and financial exposure
Categorized cancellations by severity (NCNS, Call-Off, Late Cancel)
Identified 25,184 problematic incidents affecting facility relationships

Phase 2: Root Cause Analysis

Tested multiple hypotheses through SQL analysis:
Repeat offender HCPs (concentration analysis)
Shift characteristics (type, length, pay rate)
Temporal patterns (day of week, time of day)
Booking lead time ← Primary driver identified
Used JOIN operations to correlate booking behavior with cancellation outcomes

Phase 3: Solution Design

Threshold sensitivity analysis (2hr, 4hr, 6hr, 12hr, 24hr cutoffs)
Selected 6-hour minimum as optimal balance
Modeled financial impact using conservative assumptions

Phase 4: Impact Modeling

Calculated GMV retention from reduced facility churn
Estimated implementation costs
Projected national extrapolation (Cleveland = 8% of marketplace)
Result: $1.16M annual net revenue at 32x ROI

SQL Techniques Demonstrated
Advanced Query Patterns
Window Functions:

sql
-- Percentage calculations and running totals
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_total

-- Cumulative concentration analysis
SUM(total_cancels) OVER (ORDER BY total_cancels DESC 
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as cumulative_sum
Common Table Expressions (CTEs):

sql
-- Multi-stage analysis pipeline
WITH booking_cancel_join AS (
    SELECT ... FROM bookings b
    LEFT JOIN cancels c ON b.shift_id = c.shift_id
),
categorized_bookings AS (
    SELECT ... FROM booking_cancel_join
)
SELECT ... FROM categorized_bookings;
Complex JOINs:

sql
-- Matching bookings to cancellations on multiple keys
FROM [Booking_logs v1] b
LEFT JOIN [Cancel_logs v1] c 
    ON b.shift_id = c.shift_id 
    AND b.worker_id = c.worker_id
Dynamic Segmentation:

sql
-- Flexible bucketing with CASE statements
CASE 
    WHEN booking_lead_time < 2 THEN '<2 hours'
    WHEN booking_lead_time < 4 THEN '2-4 hours'
    WHEN booking_lead_time < 6 THEN '4-6 hours'
    -- Additional buckets...
END as booking_lead_time_bucket
Aggregation with Conditional Logic:

sql
-- Multiple metrics in single query
SUM(CASE WHEN cancel_action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
SUM(CASE WHEN cancel_lead_time < 24 THEN 1 ELSE 0 END) as late_cancels,
ROUND(SUM(was_canceled) * 100.0 / COUNT(*), 2) as cancel_rate
Key Insights from Analysis
1. Booking Lead Time as Primary Predictor
Booking Window	Bookings	Cancel Rate	Late Cancel Rate	NCNS Rate
<2 hours	4,824	8.0%	7.7%	5.5%
2-4 hours	1,266	11.6%	11.0%	3.8%
4-6 hours	1,122	15.0%	14.5%	4.7%
>24 hours	110,353	21.8%	11.2%	3.8%
Insight: While longer lead times show higher overall cancellation rates (more time for circumstances to change), the <6 hour window shows distinctly problematic late cancellation and NCNS patterns that damage facility relationships.

2. Concentration of Impact
<6 hour bookings: 3.25% of volume → 5.1% of late cancellations (57% overweight)
Top 23% of HCPs: Account for 63.4% of all cancellations
54 facilities: (representing $5.55M GMV) experiencing multiple incidents
3. Financial Materiality
Total GSV at risk: $2.17M in Cleveland alone (8% of national marketplace)
Facility churn premium: 22 percentage points for affected facilities
Projected savings: $1.16M annual net revenue from 6-hour minimum booking window
Business Impact
This analysis directly informed a strategic recommendation to executive leadership with:

Clear ROI: 32x first-year return on $36K implementation investment
Measurable metrics: North star metric (facility churn rate) with supporting KPIs
Pilot approach: 12-week Cleveland pilot with defined success criteria
Risk mitigation: Manual override for emergency staffing, HCP adaptation monitoring
The solution balances marketplace health with HCP flexibility—removing the most problematic 3.25% of bookings while preserving flexibility for the remaining 96.75%.

Technical Skills Demonstrated
SQL & Data Analysis
✅ Complex multi-table JOINs with multiple keys
✅ Window functions for running calculations
✅ Common Table Expressions (CTEs) for readable query structure
✅ Conditional aggregation with CASE statements
✅ Data type handling (CAST operations for numeric analysis)
✅ Subqueries for hierarchical analysis
✅ NULL handling and edge case management
Business Analysis
✅ Root cause analysis methodology
✅ Hypothesis testing through data exploration
✅ Financial impact modeling (GMV, net revenue, ROI)
✅ Sensitivity analysis and scenario planning
✅ Trade-off evaluation (completion loss vs. retention benefit)
✅ Metric design (leading vs. lagging indicators)
Strategic Thinking
✅ First principles reasoning from data patterns
✅ Identification of leverage points (6-hour threshold)
✅ Alternative solution evaluation
✅ Implementation planning with guardrails
✅ Risk mitigation strategies

How to Use This Repository
Running the Analysis

Set up your database:
Import the three CSV files (shifts, bookings, cancellations)
Ensure table names match: Cleveland_shifts_logs, Booking_logs v1, Cancel_logs v1
Execute queries in sequence:
Start with 01_data_exploration.sql to validate data
Run 04_booking_leadtime_analysis.sql for the core insight
Execute remaining files to build complete picture
Adapt for your database:
Queries written for SQL Server syntax
May need to adjust date functions for PostgreSQL/MySQL
Window function syntax is ANSI SQL (broadly compatible)
Key Queries to Highlight
Most Important Query: 04_booking_leadtime_analysis.sql - Query 4.2

This reveals the core insight that drives the entire recommendation
Shows booking lead time as primary predictor of cancellation behavior
Forms the analytical foundation for the 6-hour threshold
Best Complexity Example: 05_facility_impact_analysis.sql - Query 5.2

Multi-level CTEs with HAVING clause filtering
JOINs across aggregated subqueries
Demonstrates production-grade SQL for business metrics
Results & Deliverables
This SQL analysis supported a comprehensive business case that included:

5-page executive narrative - Problem, root cause, solution, ROI
15-page technical appendix - Data visualizations, methodology, sensitivity analysis
Financial model - Conservative projections with assumption transparency
Implementation roadmap - 12-week pilot-to-scale timeline with success metrics
Outcome: Analysis-driven recommendation for $1.16M annual net revenue improvement through targeted behavioral intervention.

Project Context
This analysis was completed as part of a case study assessment for a Finance team role. The dataset represents real marketplace dynamics from 202X, and all analysis was performed independently using SQL, with visualizations created separately.

Time Investment: >12 hours of SQL analysis + 8 hours of narrative writing + 4 hours of visualization

Tools Used:

SQL Server for query execution
Excel for initial data exploration
Chart.js for data visualizations
Markdown for documentation

Lessons Learned:

Simple solutions often emerge from complex data: The 6-hour threshold is elegant because it's a simple rule that solves a complex behavioral problem.
Concentration analysis reveals leverage points: Looking for 80/20 patterns helps identify where small interventions create large impacts.
Multiple hypotheses testing is essential: I tested 6+ different root cause hypotheses before booking lead time emerged as the primary driver.
Financial modeling requires conservative assumptions: The difference between $40M projections and $1.16M projections is assumption discipline.
SQL is a strategic tool: Good SQL analysis directly informs multi-million dollar business decisions.
Connect With Me
If you found this analysis valuable or want to discuss the approach:

LinkedIn: https://www.linkedin.com/in/oluwaseun-mustapha/
Email: mroluwaseunmustapha@gmail.com

This project demonstrates end-to-end analytical capabilities: from SQL data exploration through insight generation to strategic business recommendations with measurable financial impact.

