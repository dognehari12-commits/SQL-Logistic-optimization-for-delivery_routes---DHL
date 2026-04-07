CREATE DATABASE DHL_DB;


USE DHL_DB;

ALTER TABLE dhl_orders
RENAME COLUMN `ï»¿Order_ID` TO `Order_ID`;

-- Check duplicate Order_ID
SELECT Order_ID, COUNT(*) AS cnt
FROM dhl_orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

ALTER TABLE dhl_shipments
RENAME COLUMN `ï»¿Shipment_ID` TO `Shipment_ID`;

-- Check duplicate Shipment_ID
SELECT Shipment_ID, COUNT(*) AS cnt
FROM dhl_shipments
GROUP BY Shipment_ID
HAVING COUNT(*) > 1;

-- Replace NULL Delay_Hours with Route Average
SELECT *
FROM dhl_shipments
WHERE Delay_Hours IS NULL;

-- Ensure Delivery_Date is NOT before Pickup_Date
SELECT *
FROM dhl_shipments
WHERE Delivery_Date < Pickup_Date;

-- Order_ID in Shipments exists in Orders
SELECT s.*
FROM dhl_shipments s
LEFT JOIN dhl_orders o
ON s.Order_ID = o.Order_ID
WHERE o.Order_ID IS NULL;

ALTER TABLE dhl_routes
RENAME COLUMN `ï»¿Route_ID` TO `Route_ID`;

-- Route_ID in Shipments exists in Routes
SELECT s.*
FROM dhl_shipments s
LEFT JOIN dhl_routes r
ON s.Route_ID = r.Route_ID
WHERE r.Route_ID IS NULL;

ALTER TABLE dhl_warehouses
RENAME COLUMN `ï»¿Warehouse_ID` TO `Warehouse_ID`;

-- Warehouse_ID in Shipments exists in Warehouses
SELECT s.*
FROM dhl_shipments s
LEFT JOIN dhl_warehouses w
ON s.Warehouse_ID = w.Warehouse_ID
WHERE w.Warehouse_ID IS NULL;

-- Calculate Delivery Delay (in hours) for each Shipment
SELECT 
    Shipment_ID,
    Order_ID,
    Route_ID,
    Warehouse_ID,
    Pickup_Date,
    Delivery_Date,
    TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date) AS Calculated_Delay_Hours
FROM dhl_shipments;

-- Top 10 Delayed Routes (Based on Average Delay)
SELECT 
    Route_ID,
    ROUND(AVG(Delay_Hours), 2) AS Avg_Delay_Hours
FROM dhl_shipments
GROUP BY Route_ID
ORDER BY Avg_Delay_Hours DESC
LIMIT 10;
 
-- Rank Shipments by Delay within Each Warehouse
SELECT
    Shipment_ID,
    Warehouse_ID,
    Delay_Hours,
    RANK() OVER (
        PARTITION BY Warehouse_ID
        ORDER BY Delay_Hours DESC
    ) AS Delay_Rank_In_Warehouse
FROM dhl_shipments;

-- Average Delay per Delivery_Type
SELECT
    o.Delivery_Type,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM dhl_shipments s
JOIN dhl_orders o
ON s.Order_ID = o.Order_ID
GROUP BY o.Delivery_Type;

-- Average Transit Time (Hours) per Route
SELECT
    Route_ID,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date)), 2) 
        AS Avg_Transit_Time_Hours
FROM dhl_shipments
GROUP BY Route_ID;

-- Average Delay (Hours) per Route
SELECT
    Route_ID,
    ROUND(AVG(Delay_Hours), 2) AS Avg_Delay_Hours
FROM dhl_shipments
GROUP BY Route_ID;

-- Distance-to-Time Efficiency Ratio
WITH route_transit AS (
    SELECT
        Route_ID,
        AVG(TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date)) 
            AS Avg_Transit_Time_Hours
    FROM dhl_shipments
    GROUP BY Route_ID
)
SELECT
    r.Route_ID,
    r.Distance_KM,
    ROUND(rt.Avg_Transit_Time_Hours, 2) AS Avg_Transit_Time_Hours,
    ROUND(r.Distance_KM / rt.Avg_Transit_Time_Hours, 2) 
        AS Distance_Time_Efficiency
FROM dhl_routes r
JOIN route_transit rt
ON r.Route_ID = rt.Route_ID;

-- Identify 3 Routes with Worst Efficiency
SELECT
    r.Route_ID,
    ROUND(r.Distance_KM / rt.Avg_Transit_Time_Hours, 2) 
        AS Distance_Time_Efficiency
FROM dhl_routes r
JOIN (
    SELECT
        Route_ID,
        AVG(TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date)) 
            AS Avg_Transit_Time_Hours
    FROM dhl_shipments
    GROUP BY Route_ID
) rt
ON r.Route_ID = rt.Route_ID
ORDER BY Distance_Time_Efficiency ASC
LIMIT 3;

-- Routes with >20% Shipments Delayed Beyond Expected Transit Time
SELECT
    s.Route_ID,
    COUNT(*) AS Total_Shipments,
    SUM(
        CASE 
            WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) 
                 > r.Avg_Transit_Time_Hours
            THEN 1 ELSE 0 
        END
    ) AS Delayed_Shipments,
    ROUND(
        SUM(
            CASE 
                WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) 
                     > r.Avg_Transit_Time_Hours
                THEN 1 ELSE 0 
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS Delay_Percentage
FROM dhl_shipments s
JOIN dhl_routes r
ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID
HAVING Delay_Percentage > 20;

-- Top 3 Warehouses with Highest Average Delay
SELECT
    Warehouse_ID,
    ROUND(AVG(Delay_Hours), 2) AS Avg_Delay_Hours
FROM dhl_shipments
GROUP BY Warehouse_ID
ORDER BY Avg_Delay_Hours DESC
LIMIT 3;

-- Total Shipments vs Delayed Shipments (Per Warehouse)
SELECT
    Warehouse_ID,
    COUNT(*) AS Total_Shipments,
    SUM(
        CASE 
            WHEN Delay_Hours > 0 THEN 1 
            ELSE 0 
        END
    ) AS Delayed_Shipments
FROM dhl_shipments
GROUP BY Warehouse_ID;

-- Warehouses Where Avg Delay > Global Avg Delay
WITH global_avg AS (
    SELECT AVG(Delay_Hours) AS Global_Avg_Delay
    FROM dhl_shipments
),
warehouse_avg AS (
    SELECT
        Warehouse_ID,
        AVG(Delay_Hours) AS Warehouse_Avg_Delay
    FROM dhl_shipments
    GROUP BY Warehouse_ID
)
SELECT
    w.Warehouse_ID,
    ROUND(w.Warehouse_Avg_Delay, 2) AS Warehouse_Avg_Delay,
    ROUND(g.Global_Avg_Delay, 2) AS Global_Avg_Delay
FROM warehouse_avg w
JOIN global_avg g
ON w.Warehouse_Avg_Delay > g.Global_Avg_Delay;

-- Rank Warehouses by On-Time Delivery Percentage
SELECT
    Warehouse_ID,
    COUNT(*) AS Total_Shipments,
    SUM(
        CASE 
            WHEN Delay_Hours = 0 THEN 1 
            ELSE 0 
        END
    ) AS On_Time_Shipments,
    ROUND(
        SUM(
            CASE 
                WHEN Delay_Hours = 0 THEN 1 
                ELSE 0 
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Percentage,
    RANK() OVER (
        ORDER BY 
        SUM(
            CASE 
                WHEN Delay_Hours = 0 THEN 1 
                ELSE 0 
            END
        ) * 1.0 / COUNT(*) DESC
    ) AS Warehouse_Rank
FROM dhl_shipments
GROUP BY Warehouse_ID;

-- Rank Delivery Agents (Per Route) by On-Time Delivery Percentage
SELECT
    s.Route_ID,
    s.Agent_ID,
    COUNT(*) AS Total_Shipments,
    SUM(
        CASE 
            WHEN s.Delay_Hours = 0 THEN 1 
            ELSE 0 
        END
    ) AS On_Time_Shipments,
    ROUND(
        SUM(
            CASE 
                WHEN s.Delay_Hours = 0 THEN 1 
                ELSE 0 
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Percentage,
    RANK() OVER (
        PARTITION BY s.Route_ID
        ORDER BY 
        SUM(
            CASE 
                WHEN s.Delay_Hours = 0 THEN 1 
                ELSE 0 
            END
        ) * 1.0 / COUNT(*) DESC
    ) AS Agent_Rank_Per_Route
FROM dhl_shipments s
GROUP BY s.Route_ID, s.Agent_ID;

-- Agents Whose On-Time Percentage is Below 85%
SELECT
    Agent_ID,
    COUNT(*) AS Total_Shipments,
    ROUND(
        SUM(
            CASE 
                WHEN Delay_Hours = 0 THEN 1 
                ELSE 0 
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Percentage
FROM dhl_shipments
GROUP BY Agent_ID
HAVING On_Time_Percentage < 85;

-- Compare Avg Rating & Experience
-- Step 1: Calculate On-Time % Per Agent
WITH agent_performance AS (
    SELECT
        Agent_ID,
        ROUND(
            SUM(
                CASE 
                    WHEN Delay_Hours = 0 THEN 1 
                    ELSE 0 
                END
            ) * 100.0 / COUNT(*),
            2
        ) AS On_Time_Percentage
    FROM dhl_shipments
    GROUP BY Agent_ID
)
SELECT *
FROM agent_performance
WHERE On_Time_Percentage < 85;

-- Step 2: Top 5 Agents

CREATE TABLE agent_performance AS
SELECT
Agent_ID,
ROUND(
SUM(CASE WHEN Delivery_Status = 'On
Time' THEN 1 ELSE 0 END)
/COUNT(*) * 100, 2
) AS On_Time_Percentage
FROM dhl_shipments
GROUP BY Agent_ID;

ALTER TABLE dhl_delivery_agents
RENAME COLUMN `ï»¿Agent_ID` TO `Agent_ID`;

SELECT
    'Top 5 Agents' AS Agent_Group,
    ROUND(AVG(a.Avg_Rating), 2) AS Avg_Rating,
    ROUND(AVG(a.Experience_Years), 2) AS Avg_Experience
FROM dhl_delivery_agents a
JOIN (
    SELECT Agent_ID
    FROM agent_performance
    ORDER BY On_Time_Percentage DESC
    LIMIT 5
)t
ON a.Agent_ID = t.Agent_ID;

-- Bottom 5 Agents
SELECT
    'Bottom 5 Agents' AS Agent_Group,
    ROUND(AVG(a.Avg_Rating), 2) AS Avg_Rating,
    ROUND(AVG(a.Experience_Years), 2) AS Avg_Experience
FROM dhl_delivery_agents a
JOIN(
    SELECT Agent_ID
    FROM agent_performance
    ORDER BY On_Time_Percentage ASC
    LIMIT 5
)t
ON a.Agent_ID = t.Agent_ID;

-- Latest Status & Latest Delivery_Date for Each Shipment
SELECT
    Shipment_ID,
    Delivery_Status,
    Delivery_Date
FROM (
    SELECT
        Shipment_ID,
        Delivery_Status,
        Delivery_Date,
        ROW_NUMBER() OVER (
            PARTITION BY Shipment_ID
            ORDER BY Delivery_Date DESC
        ) AS rn
    FROM dhl_shipments
) t
WHERE rn = 1;

-- Routes Where Majority Shipments Are “In Transit” or “Returned”
SELECT
    Route_ID,
    COUNT(*) AS Total_Shipments,
    SUM(
        CASE 
            WHEN Delivery_Status IN ('In Transit', 'Returned')
            THEN 1 ELSE 0
        END
    ) AS Pending_Shipments,
    ROUND(
        SUM(
            CASE 
                WHEN Delivery_Status IN ('In Transit', 'Returned')
                THEN 1 ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS Pending_Percentage
FROM dhl_shipments
GROUP BY Route_ID
HAVING Pending_Percentage > 50;

-- Most Frequent Delay Reasons
SELECT
    CASE
        WHEN Delay_Hours = 0 THEN 'No Delay'
        WHEN Delay_Hours BETWEEN 1 AND 24 THEN 'Minor Delay'
        WHEN Delay_Hours BETWEEN 25 AND 72 THEN 'Moderate Delay'
        ELSE 'Severe Delay'
    END AS Delay_Category,
    COUNT(*) AS Shipment_Count
FROM dhl_shipments
GROUP BY Delay_Category
ORDER BY Shipment_Count DESC;

-- Orders with Exceptionally High Delay (>120 Hours)
SELECT
    s.Shipment_ID,
    s.Order_ID,
    s.Route_ID,
    s.Warehouse_ID,
    s.Delay_Hours,
    s.Delivery_Status
FROM dhl_shipments s
WHERE s.Delay_Hours > 120
ORDER BY s.Delay_Hours DESC;

-- Average Delivery Delay per Source_Country
SELECT
    r.Source_Country,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delivery_Delay_Hours
FROM dhl_shipments s
JOIN dhl_routes r
ON s.Route_ID = r.Route_ID
GROUP BY r.Source_Country
ORDER BY Avg_Delivery_Delay_Hours DESC;

-- On-Time Delivery Percentage (Overall)
SELECT
    COUNT(*) AS Total_Deliveries,
    SUM(
        CASE 
            WHEN Delay_Hours = 0 THEN 1 
            ELSE 0 
        END
    ) AS On_Time_Deliveries,
    ROUND(
        SUM(
            CASE 
                WHEN Delay_Hours = 0 THEN 1 
                ELSE 0 
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Delivery_Percentage
FROM dhl_shipments;

-- Average Delay (Hours) per Route_ID
SELECT
    Route_ID,
    ROUND(AVG(Delay_Hours), 2) AS Avg_Delay_Hours
FROM dhl_shipments
GROUP BY Route_ID
ORDER BY Avg_Delay_Hours DESC;

-- Warehouse Utilization Percentage
SELECT
    w.Warehouse_ID,
    w.City,
    w.Country,
    w.Capacity_per_day,
    COUNT(s.Shipment_ID) AS Shipments_Handled,
    ROUND(
        COUNT(s.Shipment_ID) * 100.0 / w.Capacity_per_day,
        2
    ) AS Warehouse_Utilization_Percentage
FROM dhl_warehouses w
LEFT JOIN dhl_shipments s
ON w.Warehouse_ID = s.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.City,
    w.Country,
    w.Capacity_per_day
ORDER BY Warehouse_Utilization_Percentage DESC;

-- KPI Summary Table (Optional but High-Scoring)
SELECT
    ROUND(AVG(Delay_Hours), 2) AS Overall_Avg_Delay,
    ROUND(
        SUM(
            CASE 
                WHEN Delay_Hours = 0 THEN 1 
                ELSE 0 
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS Overall_On_Time_Percentage
FROM dhl_shipments;



