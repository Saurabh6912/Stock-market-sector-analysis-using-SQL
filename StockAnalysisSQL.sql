-- SELECT * FROM bank_dataset
-- SELECT * FROM fmcg_dataset
-- SELECT * FROM it_dataset



ALTER TABLE bank_dataset
ADD COLUMN sector VARCHAR(50);

ALTER TABLE fmcg_dataset
ADD COLUMN sector VARCHAR(50);

ALTER TABLE it_dataset
ADD COLUMN sector VARCHAR(50);

UPDATE bank_dataset SET sector = 'BANK';
UPDATE fmcg_dataset SET sector = 'FMCG';
UPDATE it_dataset SET sector = 'IT';

CREATE VIEW A1 as (
SELECT sector,high,low FROM bank_dataset b
UNION
SELECT sector,high,low FROM fmcg_dataset	f	
UNION
SELECT sector,high,low FROM it_dataset i);

SELECT sector,AVG(High - Low) as avg_volatility, 
	   dense_rank() OVER(ORDER BY avg(high - low) asc) AS ranking
FROM A1
GROUP BY sector;

SET @pre_covid_price_it = (SELECT close FROM it_dataset WHERE DATE = '2020-02-20');
SET @post_covid_price_it = (SELECT close FROM it_dataset WHERE DATE = '2020-03-23');

SET @pre_covid_price_fmcg = (SELECT close FROM fmcg_dataset WHERE DATE = '2020-02-20');
SET @post_covid_price_fmcg = (SELECT close FROM fmcg_dataset WHERE DATE = '2020-03-23');

SET @pre_covid_price_bank = (SELECT close FROM bank_dataset WHERE DATE = '2020-02-20');
SET @post_covid_price_bank = (SELECT close FROM bank_dataset WHERE DATE = '2020-03-23');

SELECT ROUND(100.0*(@post_covid_price_it - @pre_covid_price_it)/@pre_covid_price_it,4) AS it_DrawDown;

SELECT ROUND(100.0*(@post_covid_price_fmcg - @pre_covid_price_fmcg)/@pre_covid_price_fmcg,4) AS fmcg_DrawDown;

SELECT ROUND(100.0*(@post_covid_price_bank - @pre_covid_price_bank)/@pre_covid_price_bank,4) AS bank_DrawDown;

SET @recovery_date_it = (SELECT date FROM it_dataset WHERE close > @pre_covid_price_it AND date > '2020-02-20' 
						 ORDER BY date LIMIT 1);
SELECT DATEDIFF(@recovery_date_it,'2020-02-20') AS recovery_date_it;

SET @recovery_date_fmcg = (SELECT date FROM fmcg_dataset WHERE close > @pre_covid_price_fmcg AND date > '2020-02-20' 
						   ORDER BY date LIMIT 1);
SELECT DATEDIFF(@recovery_date_fmcg,'2020-02-20') AS recovery_date_fmcg;

SET @recovery_date_bank = (SELECT date FROM bank_dataset WHERE close > @pre_covid_price_bank AND date > '2020-02-20' 
						 ORDER BY date LIMIT 1);
SELECT DATEDIFF(@recovery_date_bank,'2020-02-20') AS recovery_date_bank;

WITH CTE AS(
	SELECT sector,SUM(IF((close>prvs_close),1,0)) AS higher_closed_price_days
	FROM (SELECT sector,date,close,(LAG(close) OVER(ORDER BY date)) AS prvs_close FROM it_dataset) a
	GROUP BY sector
    UNION
    SELECT sector,SUM(IF((close>prvs_close),1,0)) AS higher_closed_price_days
	FROM (SELECT sector,date,close,(LAG(close) OVER(ORDER BY date)) AS prvs_close FROM fmcg_dataset) a
	GROUP BY sector
    UNION
    SELECT sector,SUM(IF((close>prvs_close),1,0)) AS higher_closed_price_days
	FROM (SELECT sector,date,close,(LAG(close) OVER(ORDER BY date)) AS prvs_close FROM bank_dataset) a
	GROUP BY sector)
	SELECT * FROM CTE ORDER BY higher_closed_price_days;
    
SET @number_of_years = (SELECT (MAX(year) - MIN(year)) 
						FROM (SELECT YEAR(date) as year FROM it_dataset GROUP BY YEAR(date)) a);
SELECT @number_of_years;

SET @begin_price_it = (SELECT close FROM it_dataset WHERE date = '2011-02-01');
SET @end_price_it = (SELECT close FROM it_dataset WHERE date = '2022-08-01');

SET @begin_price_fmcg = (SELECT close FROM fmcg_dataset WHERE date = '2011-02-01');
SET @end_price_fmcg = (SELECT close FROM fmcg_dataset WHERE date = '2022-08-01');

SET @begin_price_bank = (SELECT close FROM bank_dataset WHERE date = '2011-02-01');
SET @end_price_bank = (SELECT close FROM bank_dataset WHERE date = '2022-08-01');

WITH CTE1  AS(
SELECT 'it_CAGR' AS Category,ROUND((POWER((@end_price_it/@begin_price_it),(1/@number_of_years)) - 1)*100,4) AS CAGR
UNION
SELECT 'fmcg_CAGR' AS Category,ROUND((POWER((@end_price_fmcg/@begin_price_fmcg),(1/@number_of_years)) - 1)*100,4) AS CAGR
UNION
SELECT 'bank_CAGR' AS Category,ROUND((POWER((@end_price_bank/@begin_price_bank),(1/@number_of_years)) - 1)*100,4) AS CAGR)
SELECT * FROM CTE1 ORDER BY CAGR;

CREATE TABLE Score_Table (Sector varchar(50), `Description` VARCHAR(100), Score INT);

INSERT INTO Score_Table (Sector, `Description`, Score)
VALUES 
("IT","Volatility",3),("FMCG","Volatility",2),("BANK","Volatility",1),
("IT","Drawdown",2),("FMCG","Drawdown",3),("BANK","Drawdown",1),
("IT","Recovery",2),("FMCG","Recovery",3),("BANK","Recovery",1),
("IT","Higher_close_above",1),("FMCG","Higher_close_above",3),("BANK","Higher_close_above",2),
("IT","CAGR",2),("FMCG","CAGR",3),("BANK","CAGR",1);


CREATE TABLE weightage_table(`Description` VARCHAR(100), Weightage decimal(2,2));

INSERT INTO weightage_table (`Description`,Weightage)
VALUES
("Volatility",0.1),
("Drawdown",0.2),
("Recovery",0.2),
("Higher_close_above",0.3),
("CAGR",0.2);

SELECT * FROM Score_Table;
SELECT * FROM weightage_table;

SELECT Sector, SUM(ROUND((Score*Weightage),10)) AS final_score FROM Score_Table st INNER JOIN weightage_table wt
ON st.`Description` = wt.`Description`
GROUP BY Sector
ORDER BY final_score DESC;