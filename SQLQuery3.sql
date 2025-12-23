-- ============================================================================
-- PHASE 1: BASIC DATA EXPLORATION & VALIDATION
-- ============================================================================

-- 1.1: Understand the shifts dataset
SELECT 
    COUNT(*) as total_shifts,
    COUNT(DISTINCT shift_id) as unique_shifts,
    COUNT(DISTINCT worker_id) as unique_hcps,
    COUNT(DISTINCT facility_id) as unique_facilities,
    MIN(start) as earliest_shift,
    MAX(start) as latest_shift,
    SUM(CASE WHEN verified = 1 THEN 1 ELSE 0 END) as verified_shifts,
    SUM(CASE WHEN deleted = 'TRUE' THEN 1 ELSE 0 END) as deleted_shifts
FROM cleveland_shifts_logs;

-- 1.2: Understand shift characteristics
SELECT 
    shift_type,
    COUNT(*) as shift_count,
    ROUND(AVG(CONVERT(FLOAT, charge)), 2) as avg_charge_rate,
    ROUND(AVG(CONVERT(FLOAT, time)), 2) as avg_shift_hours,
    ROUND(AVG(CONVERT(FLOAT, charge) * CONVERT(FLOAT, time)), 2) as avg_shift_revenue
FROM [Cleveland_shifts_logs]
GROUP BY shift_type
ORDER BY shift_count DESC;

-- 1.3: Understand booking logs
SELECT 
    COUNT(*) as total_bookings,
    COUNT(DISTINCT action_id) as unique_actions,
    COUNT(DISTINCT shift_id) as unique_shifts_booked,
    COUNT(DISTINCT worker_id) as unique_hcps_booking,
    MIN(created_at) as earliest_booking,
    MAX(created_at) as latest_booking
FROM [Booking_logs v1];

-- 1.4: Understand cancellation logs
SELECT 
    action,
    COUNT(*) as cancel_count,
    ROUND(AVG(lead_time), 2) as avg_lead_time_hours,
    COUNT(DISTINCT worker_id) as unique_hcps,
    COUNT(DISTINCT facility_id) as unique_facilities_affected
FROM [Cancel_logs v1]
GROUP BY action;

-- ============================================================================
-- PHASE 2: CANCELLATION ANALYSIS
-- ============================================================================

-- 2.1: Categorize cancellations by lead time

SELECT 
    cancel_cat,
    cancel_count,
    ROUND(cancel_count * 100.0 / SUM(cancel_count) OVER (), 2) as pct_of_cancels,
    avg_lead_time
FROM (
    SELECT 
        CASE
            WHEN Action = 'NO_CALL_NO_SHOW' THEN 'NCNS'
            WHEN lead_time < 4 THEN 'Call-Off (<4hrs)'
            WHEN lead_time >= 4 AND lead_time < 24 THEN 'Late Cancel (4-24hrs)'
            WHEN lead_time >= 24 AND lead_time < 72 THEN 'Standard Cancel (24-72hrs)'
            ELSE 'Early Cancel (>72hrs)'
        END as cancel_cat,
        COUNT(*) as cancel_count,
        AVG(lead_time) as avg_lead_time
    FROM [Cancel_logs v1]
    GROUP BY 
        CASE
            WHEN Action = 'NO_CALL_NO_SHOW' THEN 'NCNS'
            WHEN lead_time < 4 THEN 'Call-Off (<4hrs)'
            WHEN lead_time >= 4 AND lead_time < 24 THEN 'Late Cancel (4-24hrs)'
            WHEN lead_time >= 24 AND lead_time < 72 THEN 'Standard Cancel (24-72hrs)'
            ELSE 'Early Cancel (>72hrs)'
        END
) subquery
ORDER BY cancel_count DESC;

-- 2.2: Analyze cancellation distribution by lead time buckets

SELECT 
    CASE 
        WHEN lead_time < 0 THEN 'NCNS (negative lead time)'
        WHEN lead_time < 2 THEN '0-2 hours'
        WHEN lead_time < 4 THEN '2-4 hours'
        WHEN lead_time < 8 THEN '4-8 hours'
        WHEN lead_time < 24 THEN '8-24 hours'
        WHEN lead_time < 48 THEN '24-48 hours'
        WHEN lead_time < 72 THEN '48-72 hours'
        ELSE '>72 hours'
    END as lead_time_bucket,
    COUNT(*) as cancellations,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_total
FROM [Cancel_logs v1]
WHERE action = 'WORKER_CANCEL'
GROUP BY 
    CASE 
        WHEN lead_time < 0 THEN 'NCNS (negative lead time)'
        WHEN lead_time < 2 THEN '0-2 hours'
        WHEN lead_time < 4 THEN '2-4 hours'
        WHEN lead_time < 8 THEN '4-8 hours'
        WHEN lead_time < 24 THEN '8-24 hours'
        WHEN lead_time < 48 THEN '24-48 hours'
        WHEN lead_time < 72 THEN '48-72 hours'
        ELSE '>72 hours'
    END
ORDER BY MIN(lead_time);

-- 2.3: Calculate financial impact of cancellations
SELECT 
    c.action,
    COUNT(*) as cancel_count,
    ROUND(AVG(s.charge * s.time), 2) as avg_shift_value,
    ROUND(SUM(s.charge * s.time), 2) as total_gsv_at_risk,
    ROUND(SUM(s.charge * s.time) * 0.19, 2) as estimated_net_revenue_at_risk
FROM [Cancel_logs v1] c
JOIN cleveland_shifts_logs s ON c.shift_id = s.shift_id
GROUP BY c.action;

-- ============================================================================
-- PHASE 3: HCP BEHAVIOR ANALYSIS
-- ============================================================================

WITH hcp_cancels AS (
    SELECT 
        worker_id,
        COUNT(*) as total_cancels,
        SUM(CASE WHEN action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
        SUM(CASE WHEN lead_time < 4 THEN 1 ELSE 0 END) as calloff_count,
        SUM(CASE WHEN lead_time >= 4 AND lead_time < 24 THEN 1 ELSE 0 END) as late_cancel_count
    FROM [Cancel_logs v1]
    GROUP BY worker_id
)
SELECT 
    CASE 
        WHEN total_cancels = 1 THEN '1 cancel'
        WHEN total_cancels = 2 THEN '2 cancels'
        WHEN total_cancels BETWEEN 3 AND 5 THEN '3-5 cancels'
        WHEN total_cancels BETWEEN 6 AND 10 THEN '6-10 cancels'
        ELSE '>10 cancels'
    END as cancel_frequency,
    COUNT(*) as num_hcps,
    SUM(total_cancels) as total_cancels_from_group,
    ROUND(SUM(total_cancels) * 100.0 / (SELECT SUM(total_cancels) FROM hcp_cancels), 2) as pct_of_all_cancels
FROM hcp_cancels
GROUP BY 
    CASE 
        WHEN total_cancels = 1 THEN '1 cancel'
        WHEN total_cancels = 2 THEN '2 cancels'
        WHEN total_cancels BETWEEN 3 AND 5 THEN '3-5 cancels'
        WHEN total_cancels BETWEEN 6 AND 10 THEN '6-10 cancels'
        ELSE '>10 cancels'
    END
ORDER BY MIN(total_cancels);

-- 3.2: Top repeat offenders (concentration analysis)
WITH hcp_cancel_stats AS (
    SELECT 
        worker_id,
        COUNT(*) as total_cancels,
        SUM(CASE WHEN action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
        SUM(CASE WHEN lead_time < 24 THEN 1 ELSE 0 END) as late_cancel_count
    FROM [Cancel_logs v1]
    GROUP BY worker_id
)
SELECT TOP 50
    worker_id,
    total_cancels,
    ncns_count,
    late_cancel_count,
    ROUND(total_cancels * 100.0 / SUM(total_cancels) OVER (), 2) as pct_of_all_cancels,
    ROUND(SUM(total_cancels) OVER (ORDER BY total_cancels DESC 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 / 
        SUM(total_cancels) OVER (), 2) as cumulative_pct
FROM hcp_cancel_stats
ORDER BY total_cancels DESC;


-- 3.3: HCP reliability rate (need to join bookings and cancellations)

WITH hcp_activity AS (
    SELECT 
        b.worker_id,
        COUNT(DISTINCT b.shift_id) as shifts_booked,
        COUNT(DISTINCT c.shift_id) as shifts_canceled,
        SUM(CASE WHEN c.action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
        SUM(CASE WHEN c.lead_time < 24 THEN 1 ELSE 0 END) as late_cancel_count
    FROM [Booking_logs v1] b
    LEFT JOIN [Cancel_logs v1] c ON b.shift_id = c.shift_id AND b.worker_id = c.worker_id
    GROUP BY b.worker_id
)
SELECT 
    CASE 
        WHEN shifts_booked < 5 THEN '1-4 bookings'
        WHEN shifts_booked < 10 THEN '5-9 bookings'
        WHEN shifts_booked < 20 THEN '10-19 bookings'
        WHEN shifts_booked < 50 THEN '20-49 bookings'
        ELSE '50+ bookings'
    END as booking_volume,
    COUNT(*) as num_hcps,
    ROUND(AVG(shifts_canceled * 100.0 / NULLIF(shifts_booked, 0)), 2) as avg_cancel_rate,
    ROUND(AVG(late_cancel_count * 100.0 / NULLIF(shifts_booked, 0)), 2) as avg_late_cancel_rate,
    ROUND(AVG(ncns_count * 100.0 / NULLIF(shifts_booked, 0)), 2) as avg_ncns_rate
FROM hcp_activity
GROUP BY 
    CASE 
        WHEN shifts_booked < 5 THEN '1-4 bookings'
        WHEN shifts_booked < 10 THEN '5-9 bookings'
        WHEN shifts_booked < 20 THEN '10-19 bookings'
        WHEN  shifts_booked < 50 THEN '20-49 bookings'
        ELSE '50+ bookings'
    END
ORDER BY MIN(shifts_booked);

-- ============================================================================
-- PHASE 4: BOOKING LEAD TIME ANALYSIS (CRITICAL!)
-- ============================================================================

-- 4.1: Booking lead time distribution

SELECT 
    CASE 
        WHEN lead_time < 1 THEN '<1 hour'
        WHEN lead_time < 2 THEN '1-2 hours'
        WHEN lead_time < 4 THEN '2-4 hours'
        WHEN lead_time < 6 THEN '4-6 hours'
        WHEN lead_time < 12 THEN '6-12 hours'
        WHEN lead_time < 24 THEN '12-24 hours'
        WHEN lead_time < 48 THEN '24-48 hours'
        WHEN lead_time < 72 THEN '48-72 hours'
        ELSE '>72 hours'
    END as booking_lead_time_bucket,
    COUNT(*) as num_bookings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_bookings
FROM [Booking_logs v1]
GROUP BY 
    CASE 
        WHEN lead_time < 1 THEN '<1 hour'
        WHEN lead_time < 2 THEN '1-2 hours'
        WHEN lead_time < 4 THEN '2-4 hours'
        WHEN lead_time < 6 THEN '4-6 hours'
        WHEN lead_time < 12 THEN '6-12 hours'
        WHEN lead_time < 24 THEN '12-24 hours'
        WHEN lead_time < 48 THEN '24-48 hours'
        WHEN lead_time < 72 THEN '48-72 hours'
        ELSE '>72 hours'
    END
ORDER BY MIN(lead_time);

-- 4.2: KEY ANALYSIS - Cancellation rate by booking lead time

WITH booking_cancel_join AS (
    SELECT 
        b.shift_id,
        b.worker_id,
        b.lead_time as booking_lead_time,
        c.action as cancel_action,
        c.lead_time as cancel_lead_time,
        CASE WHEN c.shift_id IS NOT NULL THEN 1 ELSE 0 END as was_canceled
    FROM [Booking_logs v1] b
    LEFT JOIN [Cancel_logs v1] c ON b.shift_id = c.shift_id AND b.worker_id = c.worker_id
)
SELECT 
    CASE 
        WHEN booking_lead_time < 2 THEN '<2 hours'
        WHEN booking_lead_time < 4 THEN '2-4 hours'
        WHEN booking_lead_time < 6 THEN '4-6 hours'
        WHEN booking_lead_time < 12 THEN '6-12 hours'
        WHEN booking_lead_time < 24 THEN '12-24 hours'
        WHEN booking_lead_time < 48 THEN '24-48 hours'
        WHEN booking_lead_time < 72 THEN '48-72 hours'
        ELSE '>72 hours'
    END as booking_lead_time_bucket,
    COUNT(*) as total_bookings,
    SUM(was_canceled) as total_cancels,
    ROUND(SUM(was_canceled) * 100.0 / COUNT(*), 2) as cancel_rate,
    SUM(CASE WHEN cancel_action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
    ROUND(SUM(CASE WHEN cancel_action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as ncns_rate,
    SUM(CASE WHEN cancel_lead_time < 24 THEN 1 ELSE 0 END) as late_cancels,
    ROUND(SUM(CASE WHEN cancel_lead_time < 24 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as late_cancel_rate
FROM booking_cancel_join
GROUP BY 
    CASE 
        WHEN booking_lead_time < 2 THEN '<2 hours'
        WHEN booking_lead_time < 4 THEN '2-4 hours'
        WHEN booking_lead_time < 6 THEN '4-6 hours'
        WHEN booking_lead_time < 12 THEN '6-12 hours'
        WHEN booking_lead_time < 24 THEN '12-24 hours'
        WHEN booking_lead_time < 48 THEN '24-48 hours'
        WHEN booking_lead_time < 72 THEN '48-72 hours'
        ELSE '>72 hours'
    END
ORDER BY MIN(booking_lead_time);

-- 4.3: What % of late cancellations come from short booking lead times?

WITH booking_cancel_join AS (
    SELECT 
        b.shift_id,
        b.worker_id,
        b.lead_time as booking_lead_time,
        c.action as cancel_action,
        c.lead_time as cancel_lead_time
    FROM [Booking_logs v1] b
    INNER JOIN [Cancel_logs v1] c ON b.shift_id = c.shift_id AND b.worker_id = c.worker_id
    WHERE c.lead_time < 24 OR c.action = 'NO_CALL_NO_SHOW'  -- Late cancels only
)
SELECT 
    CASE 
        WHEN booking_lead_time < 6 THEN '<6 hours (problematic)'
        WHEN booking_lead_time < 24 THEN '6-24 hours'
        ELSE '>24 hours'
    END as booking_lead_time_category,
    COUNT(*) as late_cancel_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_late_cancels
FROM booking_cancel_join
GROUP BY 
    CASE 
        WHEN booking_lead_time < 6 THEN '<6 hours (problematic)'
        WHEN booking_lead_time < 24 THEN '6-24 hours'
        ELSE '>24 hours'
    END;

-- ============================================================================
-- PHASE 5: FACILITY IMPACT ANALYSIS
-- ============================================================================

-- 5.1: Facilities affected by late cancellations/NCNS

WITH facility_incidents AS (
    SELECT 
        facility_id,
        COUNT(*) as total_incidents,
        SUM(CASE WHEN action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
        SUM(CASE WHEN lead_time < 24 THEN 1 ELSE 0 END) as late_cancel_count
    FROM [Cancel_logs v1]
    WHERE action = 'NO_CALL_NO_SHOW' OR lead_time < 24
    GROUP BY facility_id
)
SELECT 
    CASE 
        WHEN total_incidents = 1 THEN '1 incident'
        WHEN total_incidents = 2 THEN '2 incidents'
        WHEN total_incidents BETWEEN 3 AND 5 THEN '3-5 incidents'
        WHEN total_incidents BETWEEN 6 AND 10 THEN '6-10 incidents'
        ELSE '>10 incidents'
    END as incident_frequency,
    COUNT(*) as num_facilities,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT facility_id) FROM [Cleveland_shifts_logs]), 2) as pct_of_all_facilities
FROM facility_incidents
GROUP BY 
    CASE 
        WHEN total_incidents = 1 THEN '1 incident'
        WHEN total_incidents = 2 THEN '2 incidents'
        WHEN total_incidents BETWEEN 3 AND 5 THEN '3-5 incidents'
        WHEN total_incidents BETWEEN 6 AND 10 THEN '6-10 incidents'
        ELSE '>10 incidents'
    END
ORDER BY MIN(total_incidents);

-- 5.2: Calculate GMV at risk from affected facilities

WITH facility_incidents AS (
    SELECT 
        c.facility_id,
        COUNT(*) as incident_count
    FROM [Cancel_logs v1] c
    WHERE c.action = 'NO_CALL_NO_SHOW' OR c.lead_time < 24
    GROUP BY c.facility_id
    HAVING COUNT(*) >= 2  -- Facilities with 2+ incidents
),
facility_gmv AS (
    SELECT 
        s.facility_id,
        SUM(s.charge * s.time) as total_gmv,
        COUNT(*) as total_shifts
    FROM cleveland_shifts_logs s
    WHERE s.verified = 1  -- Only completed shifts
    GROUP BY s.facility_id
)
SELECT 
    COUNT(DISTINCT fi.facility_id) as affected_facilities,
    ROUND(SUM(fg.total_gmv), 2) as total_gmv_at_risk,
    ROUND(AVG(fg.total_gmv), 2) as avg_gmv_per_facility,
    SUM(fg.total_shifts) as total_shifts_from_affected_facilities
FROM facility_incidents fi
JOIN facility_gmv fg ON fi.facility_id = fg.facility_id;

-- 5.3: Which facilities are getting hit the hardest?

WITH facility_stats AS (
    SELECT 
        s.facility_id,
        COUNT(DISTINCT s.shift_id) as total_shifts,
        SUM(s.charge * s.time) as total_gmv,
        COUNT(DISTINCT c.shift_id) as cancellations,
        SUM(CASE WHEN c.action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
        SUM(CASE WHEN c.lead_time < 24 THEN 1 ELSE 0 END) as late_cancel_count
    FROM cleveland_shifts_logs s
    LEFT JOIN [Cancel_logs v1] c ON s.shift_id = c.shift_id
    GROUP BY s.facility_id
)
SELECT 
    facility_id,
    total_shifts,
    ROUND(total_gmv, 2) as total_gmv,
    cancellations,
    ncns_count,
    late_cancel_count,
    ROUND(cancellations * 100.0 / total_shifts, 2) as cancel_rate,
    ROUND((ncns_count + late_cancel_count) * 100.0 / total_shifts, 2) as problematic_rate
FROM facility_stats
WHERE (ncns_count + late_cancel_count) >= 2
ORDER BY (ncns_count + late_cancel_count) DESC;

-- ============================================================================
-- PHASE 6: SHIFT CHARACTERISTICS ANALYSIS
-- ============================================================================

-- 6.1: Cancellation rate by shift type

WITH shift_cancel_join AS (
    SELECT 
        s.shift_id,
        s.shift_type,
        s.charge,
        s.time,
        CASE WHEN c.shift_id IS NOT NULL THEN 1 ELSE 0 END as was_canceled,
        c.action as cancel_action,
        c.lead_time as cancel_lead_time
    FROM cleveland_shifts_logs s
    LEFT JOIN [Cancel_logs v1] c ON s.shift_id = c.shift_id
    WHERE s.worker_id IS NOT NULL  -- Only shifts that were assigned
)
SELECT 
    shift_type,
    COUNT(*) as total_shifts,
    SUM(was_canceled) as cancellations,
    ROUND(SUM(was_canceled) * 100.0 / COUNT(*), 2) as cancel_rate,
    SUM(CASE WHEN cancel_action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
    ROUND(SUM(CASE WHEN cancel_action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as ncns_rate
FROM shift_cancel_join
GROUP BY shift_type
ORDER BY cancel_rate DESC;

-- 6.2: Cancellation rate by shift length

WITH shift_cancel_join AS (
    SELECT 
        s.shift_id,
        s.time as shift_hours,
        CASE WHEN c.shift_id IS NOT NULL THEN 1 ELSE 0 END as was_canceled,
        c.lead_time as cancel_lead_time
    FROM [Cleveland_shifts_logs] s
    LEFT JOIN [Cancel_logs v1] c ON s.shift_id = c.shift_id
    WHERE s.worker_id IS NOT NULL
)
SELECT 
    CASE 
        WHEN shift_hours < 4 THEN '<4 hours'
        WHEN shift_hours < 8 THEN '4-8 hours'
        WHEN shift_hours < 12 THEN '8-12 hours'
        ELSE '12+ hours'
    END as shift_length,
    COUNT(*) as total_shifts,
    SUM(was_canceled) as cancellations,
    ROUND(SUM(was_canceled) * 100.0 / COUNT(*), 2) as cancel_rate,
    ROUND(SUM(CASE WHEN cancel_lead_time < 24 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as late_cancel_rate
FROM shift_cancel_join
GROUP BY 
    CASE 
        WHEN shift_hours < 4 THEN '<4 hours'
        WHEN shift_hours < 8 THEN '4-8 hours'
        WHEN shift_hours < 12 THEN '8-12 hours'
        ELSE '12+ hours'
    END
ORDER BY MIN(shift_hours);

-- 6.3: Cancellation rate by charge rate (shift value)

WITH shift_cancel_join AS (
    SELECT 
        s.shift_id,
        CAST(s.charge AS FLOAT) as charge,
        CASE WHEN c.shift_id IS NOT NULL THEN 1 ELSE 0 END as was_canceled
    FROM [Cleveland_shifts_logs] s
    LEFT JOIN [Cancel_logs v1] c ON s.shift_id = c.shift_id
    WHERE s.worker_id IS NOT NULL
)
SELECT 
    CASE 
        WHEN charge < 30 THEN '<$30/hr'
        WHEN charge < 40 THEN '$30-40/hr'
        WHEN charge < 50 THEN '$40-50/hr'
        ELSE '$50+/hr'
    END as charge_bracket,
    COUNT(*) as total_shifts,
    SUM(was_canceled) as cancellations,
    ROUND(SUM(was_canceled) * 100.0 / COUNT(*), 2) as cancel_rate
FROM shift_cancel_join
GROUP BY 
    CASE 
        WHEN charge < 30 THEN '<$30/hr'
        WHEN charge < 40 THEN '$30-40/hr'
        WHEN charge < 50 THEN '$40-50/hr'
        ELSE '$50+/hr'
    END
ORDER BY MIN(charge);

-- ============================================================================
-- PHASE 7: TEMPORAL PATTERNS
-- ============================================================================

-- 7.1: Cancellation rate by day of week

WITH shift_cancel_join AS (
    SELECT 
        s.shift_id,
        CASE DATEPART(WEEKDAY, s.start)
            WHEN 1 THEN 'Sunday'
            WHEN 2 THEN 'Monday'
            WHEN 3 THEN 'Tuesday'
            WHEN 4 THEN 'Wednesday'
            WHEN 5 THEN 'Thursday'
            WHEN 6 THEN 'Friday'
            WHEN 7 THEN 'Saturday'
        END as day_of_week,
        CASE WHEN c.shift_id IS NOT NULL THEN 1 ELSE 0 END as was_canceled
    FROM [Cleveland_shifts_logs] s
    LEFT JOIN [Cancel_logs v1] c ON s.shift_id = c.shift_id
    WHERE s.worker_id IS NOT NULL
)
SELECT 
    day_of_week,
    COUNT(*) as total_shifts,
    SUM(was_canceled) as cancellations,
    ROUND(SUM(was_canceled) * 100.0 / COUNT(*), 2) as cancel_rate
FROM shift_cancel_join
GROUP BY day_of_week
ORDER BY 
    CASE day_of_week
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END;

-- ============================================================================
-- PHASE 8: COMPREHENSIVE SUMMARY METRICS
-- ============================================================================

-- 8.1: Overall marketplace health metrics

SELECT 
    -- Shifts
    COUNT(DISTINCT s.shift_id) as total_shifts_posted,
    SUM(CASE WHEN s.worker_id IS NOT NULL THEN 1 ELSE 0 END) as shifts_assigned,
    SUM(CASE WHEN s.verified = 1 THEN 1 ELSE 0 END) as shifts_completed,
    
    -- Cancellations
    COUNT(DISTINCT c.shift_id) as shifts_canceled,
    SUM(CASE WHEN c.action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) as ncns_count,
    SUM(CASE WHEN c.lead_time < 24 THEN 1 ELSE 0 END) as late_cancels,
    
    -- Rates
    ROUND(COUNT(DISTINCT c.shift_id) * 100.0 / 
        NULLIF(SUM(CASE WHEN s.worker_id IS NOT NULL THEN 1 ELSE 0 END), 0), 2) as overall_cancel_rate,
    ROUND(SUM(CASE WHEN c.lead_time < 24 OR c.action = 'NO_CALL_NO_SHOW' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(CASE WHEN s.worker_id IS NOT NULL THEN 1 ELSE 0 END), 0), 2) as problematic_cancel_rate,
    
    -- Financial
    ROUND(SUM(s.charge * s.time), 2) as total_gsv,
    ROUND(SUM(CASE WHEN s.verified = 1 THEN s.charge * s.time ELSE 0 END), 2) as completed_gsv,
    ROUND(SUM(CASE WHEN c.shift_id IS NOT NULL THEN s.charge * s.time ELSE 0 END), 2) as canceled_gsv
FROM cleveland_shifts_logs s
LEFT JOIN [Cancel_logs v1] c ON s.shift_id = c.shift_id;