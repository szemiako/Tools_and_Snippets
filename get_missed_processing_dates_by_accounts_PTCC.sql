USE PTCC
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

--For Pershing brokers specifically, determine date of most recently passed Friday.

DECLARE @last_friday DATETIME

SET @last_friday = (
	SELECT
		DATEADD(
			DAY,
			-((DATEPART(WEEKDAY, GETDATE()) + @@DATEFIRST) % 7 + 1), --Returns "Absolute Day of Week" irrespective of DateFirst setting, then increments it by 1 to always calculated days needed for most recently passed Friday.
			DATEDIFF(DAY, 0, GETDATE()) --Converts this into DateTime but at midnight.
		)
)

;WITH broker_data (brokerage, customer, accountguid, pershing) AS (
	SELECT
		b.BrokerName,
		c.CompanyName,
		a.AccountGUID,
		CASE
			WHEN b.PershingServer LIKE 'sftp.sfg.%' THEN 1
			ELSE 0
		END [isPershing]
	FROM Brokers b WITH (NOLOCK)
	JOIN Accounts a WITH (NOLOCK) ON b.BrokerGUID = a.BrokerGUID
	JOIN Users u WITH (NOLOCK) ON a.UserGUID = u.UserGUID
	JOIN Customers c WITH (NOLOCK) ON u.CustomerGUID = c.CustomerGUID
	WHERE (
		a.LastBrokerReport >= CASE
			WHEN b.PershingServer LIKE 'sftp.sfg.%' THEN @last_friday --If isPershing: Get all accounts with LastBrokerReport greater than or equal to last Friday (last Pershing delta file).
			ELSE (SELECT TOP (1) business_dates FROM @last_business_dates WHERE business_dates IS NOT NULL ORDER BY business_dates) --If not isPershing: Get all accounts with LastBrokerReport gerater than or equal to the earlier bound of the last two completed business days.
		END
		AND c.CustomerEnabled = 1
		AND c.CompanyName NOT LIKE '-DEMO-%'
		AND c.CompanyName NOT LIKE 'COMPLYSCI-%'
	)
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
			CASE d.pershing
				WHEN 1 THEN @last_friday --To Account for Pershing. Expected to return one (1) row for Pershing brokers.
				ELSE business_dates --Expected to return n rows for all other brokers.
			END [BusinessDates]
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
		adp.DateOfData
	FROM expected e
	JOIN broker_data d ON (
		e.brokerage = d.brokerage
		AND e.customer = d.customer
	)
	JOIN [Accounts-DailyProcess] adp WITH (NOLOCK) ON ( --Use the daily process table for those brokerages that provide accounts files.
		d.accountguid = adp.AccountGUID
		AND e.business_dates = adp.DateOfData
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

--SELECT
--	@@SERVERNAME [Process Server],
--	ua.BrokerName,
--	ua.BusinessDate,
--	COUNT(ua.CompanyName) [Number of Impacted PTCC Customers]
--FROM Unprocessed_Accounts ua
--GROUP BY
--	ua.BrokerName,
--	ua.BusinessDate
--ORDER BY
--	ua.BusinessDate,
--	ua.BrokerName	

SELECT
	@@SERVERNAME [Process Server],
	ua.BrokerName,
	ua.BusinessDate,
	ua.CompanyName
FROM Unprocessed_Accounts ua
ORDER BY
	ua.BusinessDate,
	ua.BrokerName	