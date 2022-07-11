--Exploring the table
SELECT * FROM [dbo].[sales_data_sample]


--Checking unique values of categorical variable
SELECT DISTINCT [status] FROM sales_data_sample 
/*
Resolved
On Hold
Cancelled
Shipped
Disputed
In Process
*/
SELECT DISTINCT [PRODUCTLINE] FROM sales_data_sample 
/*Motorcycles
Ships
Trucks and Buses
Vintage Cars
Classic Cars
Planes*/
SELECT DISTINCT [MSRP] FROM sales_data_sample -- 80 unique values
SELECT DISTINCT [CITY] FROM sales_data_sample -- 73 states
SELECT DISTINCT [STATE] FROM sales_data_sample --17 states + NULL
SELECT DISTINCT [COUNTRY] FROM sales_data_sample -- 17 countries
SELECT DISTINCT [TERRITORY] FROM sales_data_sample
/*
EMEA
APAC
Japan
NA
*/
SELECT DISTINCT [CONTACTFIRSTNAME] FROM sales_data_sample --72 firstname
SELECT DISTINCT [CONTACTLASTNAME] FROM sales_data_sample --77 lastname
SELECT DISTINCT [DEALSIZE] FROM sales_data_sample
/*
Large
Medium
Small
*/
SELECT DISTINCT [YEAR_ID] FROM sales_data_sample
/*
2004
2005
2003
*/



--EDA
--grouping [sales] by [productline]
SELECT [PRODUCTLINE], SUM([SALES]) AS REVENUE 
FROM [dbo].[sales_data_sample]
GROUP BY [PRODUCTLINE]
ORDER BY REVENUE DESC --Classic cars has the highest revenue

-- grouping [sales] by [year_id]
SELECT [YEAR_ID], SUM([SALES]) AS REVENUE 
FROM [dbo].[sales_data_sample]
GROUP BY [YEAR_ID]
ORDER BY REVENUE DESC --year 2004 had the highest revenue 
--why is 2005 revenue so low?
SELECT DISTINCT [MONTH_ID] 
FROM sales_data_sample
WHERE [YEAR_ID] = 2005 --OOh, They only operated for 5 months

-- grouping [sales] by [DEALSIZE]
SELECT [DEALSIZE], SUM([SALES]) AS REVENUE 
FROM [dbo].[sales_data_sample]
GROUP BY [DEALSIZE]
ORDER BY REVENUE DESC --Medium had the highest revenue


--Q1 what were best months for sales per year, and how much?
SELECT [MONTH_ID],SUM([SALES]) AS REVENUE, COUNT([ORDERNUMBER]) AS FREQUENCY
FROM sales_data_sample
WHERE [YEAR_ID] = 2003
GROUP BY [MONTH_ID]
ORDER BY REVENUE DESC --NOVEMBER
--------
SELECT [MONTH_ID],SUM([SALES]) AS REVENUE, COUNT([ORDERNUMBER]) AS FREQUENCY
FROM sales_data_sample
WHERE [YEAR_ID] = 2004
GROUP BY [MONTH_ID]
ORDER BY REVENUE DESC --NOVEMBER
--------
SELECT [MONTH_ID],SUM([SALES]) AS REVENUE, COUNT([ORDERNUMBER]) AS FREQUENCY
FROM sales_data_sample
WHERE [YEAR_ID] = 2005
GROUP BY [MONTH_ID]
ORDER BY REVENUE DESC --MAY

-- What product was selling in November?
SELECT [MONTH_ID], [PRODUCTLINE] AS PRODUCT,SUM([SALES]) AS REVENUE, COUNT([ORDERNUMBER]) AS FREQUENCY
FROM sales_data_sample
WHERE [YEAR_ID] = 2003 AND [MONTH_ID] = 11
GROUP BY [MONTH_ID], [PRODUCTLINE]
ORDER BY REVENUE DESC --Classic cars
------------
SELECT [MONTH_ID], [PRODUCTLINE] AS PRODUCT,SUM([SALES]) AS REVENUE, COUNT([ORDERNUMBER]) AS FREQUENCY
FROM sales_data_sample
WHERE [YEAR_ID] = 2004 AND [MONTH_ID] = 11
GROUP BY [MONTH_ID], [PRODUCTLINE]
ORDER BY REVENUE DESC --Classic cars

--Who was our best customer?
DROP TABLE IF EXISTS #rfm;

WITH rfm AS
(
	SELECT 
			[CUSTOMERNAME],
			SUM([SALES]) AS MonetaryValue,
			AVG([SALES]) AS AvgMonetaryValue,
			COUNT(ORDERNUMBER) FREQUENCY,
			MAX([ORDERDATE]) Last_order_date,
			(SELECT MAX([ORDERDATE]) FROM [dbo].[sales_data_sample]) AS max_order_date,
			DATEDIFF(DD, MAX([ORDERDATE]),  (SELECT MAX([ORDERDATE]) FROM [dbo].[sales_data_sample])) AS RECENCY
	FROM [dbo].[sales_data_sample]
	GROUP BY [CUSTOMERNAME]
),
rfm_calculated AS 
(
	SELECT r.*,
		   NTILE(4) OVER (ORDER BY RECENCY) AS ref_RECENCY,
		   NTILE(4) OVER (ORDER BY FREQUENCY) AS ref_FREQUENCY,
		   NTILE(4) OVER (ORDER BY MonetaryValue) AS ref_MonetaryValue
	FROM rfm AS r
)

SELECT 
	rc.*,
	(ref_RECENCY + ref_FREQUENCY + ref_MonetaryValue) AS rfm_sum,
	cast(ref_RECENCY AS nvarchar) + cast(ref_FREQUENCY AS nvarchar) + cast(ref_MonetaryValue AS nvarchar) AS rfm_sum_string
INTO #RFM
FROM rfm_calculated AS rc

SELECT [CUSTOMERNAME],[ref_RECENCY], [ref_FREQUENCY], [ref_MonetaryValue],
	   CASE
			WHEN rfm_sum_string in (111, 112, 121, 122, 123, 132, 211, 212, 114, 141) THEN 'lost customer' --lost customers
			WHEN rfm_sum_string IN (133,134,143,244, 334, 343, 344, 144) THEN  'Slipping away, can not lose' --big customers but havent purchased lately
			WHEN rfm_sum_string IN (311, 411, 331) THEN 'new_customer'
			WHEN rfm_sum_string IN (222, 223, 233, 322) THEN 'potential customer'
			WHEN rfm_sum_string IN (323, 333, 321, 422, 332, 432) THEN 'active' --buys recently and often, but at low price
			WHEN rfm_sum_string IN (433, 434, 443, 444) THEN 'loyal'

	   END ref_segment
FROM #RFM



--which products are most often sold together?
SELECT DISTINCT [ORDERNUMBER], STUFF  (
(
	SELECT ',' + [PRODUCTCODE]
	FROM [dbo].[sales_data_sample] AS TR
	WHERE ORDERNUMBER IN
	(
		SELECT [ORDERNUMBER]
		FROM (
				SELECT [ORDERNUMBER], COUNT(*) AS rn 
				FROM [dbo].[sales_data_sample]
				WHERE [STATUS] = 'Shipped'
				GROUP BY [ORDERNUMBER]
			  ) AS mn
		WHERE rn = 3
	) AND TR.[ORDERNUMBER] = S.[ORDERNUMBER]
	FOR XML PATH ('')
)
,1,1,''          ) AS PRO_CODES
FROM [dbo].[sales_data_sample] AS S
ORDER BY 2 DESC
