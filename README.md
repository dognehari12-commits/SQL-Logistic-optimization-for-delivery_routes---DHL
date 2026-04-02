# 🚚 DHL Logistics Optimization & Delivery Performance Analysis

## 📌 Project Overview
This project focuses on analyzing logistics delivery data to identify delay patterns and optimize operations.  
The goal is to improve delivery performance by analyzing routes, warehouses, and delivery agents using SQL.

---

## ❗ Business Problem
- Frequent delivery delays and SLA breaches
- High operational costs due to inefficiencies
- Lack of visibility into route, warehouse, and agent performance

👉 Key Question:  
How can data be used to identify delay drivers and optimize logistics operations?

---

## 🎯 Project Objectives
- Identify high-delay routes
- Analyze warehouse performance
- Evaluate delivery agent efficiency
- Detect shipment bottlenecks
- Provide data-driven recommendations

---

## 🗂 Dataset Description
The project uses multiple relational tables:

- **Orders**: Order_ID, Order_Date, Delivery_Type, etc.
- **Shipments**: Shipment_ID, Pickup_Date, Delivery_Date, Delay_Hours
- **Routes**: Distance, Transit Time
- **Warehouses**: Capacity, Location
- **Delivery Agents**: Experience, Ratings

---

## 🧹 Data Cleaning & Preparation

### 🔹 Key Steps:
- Removed duplicate records
- Handled missing values using route-level averages
- Standardized date formats
- Validated delivery date consistency
- Ensured referential integrity across tables

### 🧾 Sample SQL Query:
```sql
SELECT Order_ID, COUNT(*)
FROM dhl_orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;
📊 Exploratory Data Analysis (EDA)
🔹 1. Top Delayed Routes

📌 Insight: Identified routes with highest average delay

👉 📸 Add Screenshot Below:


🧾 SQL Query:
SELECT Route_ID, ROUND(AVG(Delay_Hours),2) AS Avg_Delay
FROM dhl_shipments
GROUP BY Route_ID
ORDER BY Avg_Delay DESC
LIMIT 10;
🔹 2. Delivery Type Comparison

📌 Insight: Standard deliveries show higher delays than Express

👉 📸 Add Screenshot Below:


🧾 SQL Query:
SELECT o.Delivery_Type, ROUND(AVG(s.Delay_Hours),2)
FROM dhl_shipments s
JOIN dhl_orders o ON s.Order_ID = o.Order_ID
GROUP BY o.Delivery_Type;
🔹 3. Warehouse Performance

📌 Insight: Some warehouses are overloaded causing delays

👉 📸 Add Screenshot Below:


🧾 SQL Query:
SELECT Warehouse_ID, COUNT(*) AS Total_Shipments,
SUM(CASE WHEN Delay_Hours > 0 THEN 1 ELSE 0 END) AS Delayed
FROM dhl_shipments
GROUP BY Warehouse_ID;
🔹 4. Delivery Agent Performance

📌 Insight: Identified agents with <85% on-time delivery

👉 📸 Add Screenshot Below:


🧾 SQL Query:
SELECT Agent_ID,
ROUND(SUM(CASE WHEN Delay_Hours=0 THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS On_Time_Percentage
FROM dhl_shipments
GROUP BY Agent_ID;
🔹 5. Delay Distribution

📌 Insight: Most delays fall under minor and moderate categories

👉 📸 Add Screenshot Below:
📈 Key Insights
Standard deliveries have higher delays than Express
Few routes contribute to majority of delays
Overloaded warehouses increase delivery time
Low-performing agents impact SLA

🚀 Business Recommendations
Implement dynamic route optimization
Balance load across warehouses
Train low-performing delivery agents
Use real-time monitoring dashboards

📽 Project Resources
📄 PPT Presentation: (Add your link here)
🎥 Video Explanation: (Add your link here)

👨‍💻 Author

Harivansh Dogne
Data Analyst | SQL | Power BI
