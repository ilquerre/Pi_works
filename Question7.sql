--Median function was taken from https://wiki.postgresql.org/wiki/Aggregate_Median
CREATE FUNCTION _final_median(anyarray) RETURNS float8 AS $$ 
  WITH q AS
  (
     SELECT val
     FROM unnest($1) val
     WHERE VAL IS NOT NULL
     ORDER BY 1
  ),
  cnt AS
  (
    SELECT COUNT(*) as c FROM q
  )
  SELECT AVG(val)::float8
  FROM 
  (
    SELECT val FROM q
    LIMIT  2 - MOD((SELECT c FROM cnt), 2)
    OFFSET GREATEST(CEIL((SELECT c FROM cnt) / 2.0) - 1,0)  
  ) q2;
$$ LANGUAGE sql IMMUTABLE;

CREATE AGGREGATE median(anyelement) (
  SFUNC=array_append,
  STYPE=anyarray,
  FINALFUNC=_final_median,
  INITCOND='{}'
);
--Calculating medians of countries and inserting them to new table
SELECT median(vaccines.daily_vaccinations), vaccines.country 
INTO grouped
FROM vaccines 
GROUP BY vaccines.country
--Joining grouped table to vaccines table
SELECT vaccines.*,grouped.median
INTO joined
FROM grouped
LEFT JOIN vaccines
ON grouped.country=vaccines.country
--Fill Null values with COALESCE function
--First fill
UPDATE joined SET daily_vaccinations = COALESCE(daily_vaccinations, median);
--Second fill if there are still null values like Kuwait
UPDATE joined SET daily_vaccinations = COALESCE(daily_vaccinations, 0);
