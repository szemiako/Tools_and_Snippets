USE PROD
GO

--Build temp table of "Most Recent Business Days".
DECLARE @offset INT

SET @offset = 2

DECLARE @last_business_dates TABLE (
	business_dates DATETIME
)

WHILE @offset > 0
	BEGIN
		INSERT INTO @last_business_dates
			SELECT
				CASE
					WHEN DATEPART(WEEKDAY, DATEADD(DAY, -@offset, DATEDIFF(DAY, 0, GETDATE()))  + @@DATEFIRST) % 7 NOT IN (0, 1)
					THEN DATEADD(DAY, -@offset, DATEDIFF(DAY, 0, GETDATE()))
				END [BusinessDate]
		SET @offset = @offset - 1
	END

;WITH broker_data (brokerage, customer, accountguid, pershing) AS (
	SELECT
		b.BrokerName,
		c.CompanyName,
		a.AccountGUID
	FROM Brokers b WITH (NOLOCK)
	JOIN Accounts a WITH (NOLOCK) ON b.PrimaryGUID = a.ForeignGUID
	JOIN Users u WITH (NOLOCK) ON a.ForeignGUID = u.PrimaryGUID
	JOIN Customers c WITH (NOLOCK) ON u.ForeignGUID = c.PrimaryGUID 
	WHERE (
		a.LastProcessed >= (SELECT TOP (1) business_dates FROM @last_business_dates WHERE business_dates IS NOT NULL ORDER BY business_dates)
),
--Build temp table of all permutations of active brokerages, customers, and last n business dates.
expected (brokerage, customer, business_dates) AS (
	SELECT
		d.brokerage [BrokerName],
		d.customer [CompanyName],
		lbd.[BusinessDates] [Business Dates]
	FROM broker_data d
	CROSS APPLY ( --Use Cross Apply to easily apply expected business dates for each brokerage.
		SELECT
			business_dates 
		FROM @last_business_dates
		WHERE business_dates IS NOT NULL
	) lbd
	GROUP BY
		d.brokerage,
		d.customer,
		lbd.[BusinessDates]
),
processed_accounts (brokerage, customer, dates) AS (
	SELECT
		e.brokerage [Broker Name],
		e.customer [Company Name],
		a.Date
	FROM expected e
	JOIN broker_data d ON (
		e.brokerage = d.brokerage
		AND e.customer = d.customer
	)
	JOIN [DailyProcess] dp WITH (NOLOCK) ON ( --Use the daily process table for those brokerages that provide daily files.
		d.accountguid = adp.AccountGUID
		AND e.business_dates = dp.DateOfData
	)
	GROUP BY
		e.brokerage,
		e.customer,
		adp.DateOfData
),
Unprocessed_Accounts (BrokerName, CompanyName, BusinessDate) AS (
	SELECT *
	FROM expected

	EXCEPT

	SELECT *
	FROM processed_accounts
)

SELECT
	@@SERVERNAME [Process Server],
	ua.BrokerName,
	ua.BusinessDate,
	ua.CompanyName
FROM Unprocessed_Accounts ua
ORDER BY
	ua.BusinessDate,
	ua.BrokerName	