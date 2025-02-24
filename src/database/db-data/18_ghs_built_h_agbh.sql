--First create table,the order of the columns and their types should be the same as in the csv file. The names can differ. Make sure the year is in a column name "obsTime", the values are in the column "obsValue" and the area code is in geo. 
--For obsTime and obsValue the capitals are important.
DROP TABLE IF EXISTS ghs_built_h_agbh CASCADE;
CREATE TABLE IF NOT EXISTS ghs_built_h_agbh
(
    geo 		TEXT,
    "obsValue" 	NUMERIC,
    indicator 	TEXT,
    freq 		TEXT,
    "obsTime" 	INTEGER,
    unit 		TEXT,
    geo_source 	TEXT
)

--Load with  PSQL
--This part you should run with psql. Only in psql you can use local files for copy with the command \copy. The normal copy command uses only files which are on the database server.
--And of course adjust the path to the file.
\copy ghs_built_h_agbh FROM 'c:\projects\mapineq\db_geodienst\data\ghs_built_h_agbh.csv' HEADER DELIMITER ',' CSV

--Add an entry to the catalogue table.
--Check upfromt if the entry is not already there.
DELETE FROM catalogue WHERE resource = 'ghs_built_h_agbh';
INSERT INTO public.catalogue(
	provider, resource, descr,   use, short_descr, query_resource)
	VALUES ('Global Human Settlement Layer', 'ghs_built_h_agbh', 'Average of the Gross Building Height', TRUE, 'ghs_built_h_agbh','vw_ghs_built_h_agbh');

--Create a view with the name vw_tablename. Leave columns out which should not be used. A view is needed.
DROP VIEW IF EXISTS vw_ghs_built_h_agbh;
CREATE OR REPLACE VIEW vw_ghs_built_h_agbh AS
SELECT
    geo,
    "obsValue",
    indicator,
    "obsTime",
    unit
FROM
	ghs_built_h_agbh;

--Fill some tables with information. Just run these procedures. The procedure first removes the records for the table and then add new records, so it can be run again if needed.
CALL website.fill_resource_years('ghs_built_h_agbh');
CALL website.fill_resource_nuts_levels('ghs_built_h_agbh');
CALL website.fill_resource_year_nuts_levels('ghs_built_h_agbh');

CALL website.fill_catalogue_field_description( 'ghs_built_h_agbh');
CALL website.fill_catalogue_field_value_description( 'ghs_built_h_agbh');

--Check if everythin if working with these control queries
SELECT * FROM website.vw_data_tables WHERE resource = 'ghs_built_h_agbh';

SELECT * FROM website.resource_years WHERE resource = 'ghs_built_h_agbh' order by year;
SELECT * FROM website.resource_nuts_levels WHERE resource = 'ghs_built_h_agbh' order by level;
SELECT * FROM website.resource_year_nuts_levels WHERE resource = 'ghs_built_h_agbh' order by 3,2;

SELECT * FROM website.catalogue_field_description WHERE resource = 'ghs_built_h_agbh';
SELECT * FROM website.catalogue_field_value_description WHERE resource = 'ghs_built_h_agbh';


