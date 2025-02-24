DROP FUNCTION IF EXISTS postgisftw.search_sources(TEXT);
CREATE OR REPLACE FUNCTION postgisftw.search_sources(_search_string TEXT DEFAULT NULL)
RETURNS TABLE
(
	f_provider			TEXT,
	f_resource 			TEXT, 
	f_description 		TEXT, 
	f_short_description TEXT,
	f_version			INTEGER,
	f_url				TEXT,
	f_use				BOOLEAN,
	f_meta_data_url		TEXT,
    f_web_source_url	TEXT,
	f_license			TEXT,
	f_query_resource	TEXT,
	f_years				JSONB,
	f_levels			JSONB
)
AS
$BODY$
DECLARE
	rec	RECORD;
	strQuery	TEXT;
BEGIN
	RETURN QUERY 
	EXECUTE FORMAT ($$SELECT
		provider,
		c.resource,
		descr,
		short_descr::TEXT,
		version,
		url,
		use,
		meta_data_url,
    	web_source_url,
		license,
		query_resource,
		(SELECT json_agg(year) FROM website.resource_years r WHERE r.resource = c.resource )::JSONB,
		(SELECT json_agg(level) FROM website.resource_nuts_levels r WHERE r.resource = c.resource )::JSONB
	FROM
		website.vw_data_tables c
	WHERE
		provider || c.resource || descr || short_descr ILIKE '%%%s%%'$$,_search_string) ;
END;
$BODY$
LANGUAGE PLPGSQL;

DROP FUNCTION IF EXISTS postgisftw.get_use_cases(INTEGER);
CREATE OR REPLACE FUNCTION postgisftw.get_use_cases(_use_case INTEGER DEFAULT NULL)
RETURNS TABLE
(
	f_use_case		INTEGER,
	f_short_descr	TEXT,
	f_long_descr	TEXT,
	f_parameters	JSONB
)
AS
$BODY$
BEGIN
	RETURN QUERY
	SELECT
		use_case,
		short_descr,
		long_descr,
		parameters
	FROM
		website.use_cases
	WHERE
		use_case = _use_case
		OR _use_case IS NULL
	ORDER BY
		use_case;
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_levels(INTEGER);
CREATE OR REPLACE FUNCTION postgisftw.get_levels(_use_case INTEGER DEFAULT NULL)
RETURNS TABLE
(
	f_level	TEXT
)
AS
$BODY$
DECLARE
	rec				RECORD;
	bCaseOptions	BOOLEAN		:= FALSE;
	arrLevels		INTEGER[] 	:= NULL;
BEGIN
	SELECT 
		case_options IS NOT NULL 
	INTO
		bCaseOptions
	FROM 
		website.use_cases 
	WHERE 
		use_case = _use_case;

	IF bCaseOptions   
	THEN
		FOR rec IN
			WITH cte AS
			(
				SELECT
					jsonb_array_elements(case_options) AS j
				FROM
					website.use_cases
				WHERE
					use_case = _use_case
			)
			SELECT 
				(jsonb_array_elements(j -> 'tableRegionLevels'))::INTEGER levels
			FROM 
				cte
			WHERE
				j ->> 'tableFunction' IN ('Predictor', '*')
				AND (j -> 'tableRegionLevels' @> ('"*"')) = FALSE
		LOOP
			arrLevels = ARRAY_APPEND(arrLevels, rec.levels);
		END LOOP;
		
		FOR rec IN
			WITH cte AS
			(
				SELECT
					jsonb_array_elements(case_options) AS j
				FROM
					website.use_cases
				WHERE
					use_case = _use_case
			),
			cte_2 AS
			(SELECT 
				j ->> 'tableName' optiontable
			FROM 
				cte
			WHERE
				j ->> 'tableFunction' IN ('Predictor', '*')
				AND (j -> 'tableRegionLevels' @> ('"*"')) = TRUE
			)
			SELECT DISTINCT
				r.level	AS levels
			FROM
				website.resource_year_nuts_levels AS r,
				cte_2
			WHERE
				resource = optiontable
		LOOP
			arrLevels = ARRAY_APPEND(arrLevels, rec.levels);
		END LOOP;
		
		RETURN QUERY SELECT DISTINCT UNNEST(arrLevels)::TEXT ORDER BY 1 DESC;
	ELSE
		RETURN QUERY 
		SELECT DISTINCT 
			r.level::TEXT 
		FROM 
			website.resource_year_nuts_levels r
		ORDER BY 
			level DESC;
	END IF;
		
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_tag(TEXT, INTEGER, TEXT);

CREATE OR REPLACE FUNCTION postgisftw.get_tag(_resource TEXT DEFAULT NULL, _use_case INTEGER DEFAULT NULL, _function TEXT DEFAULT NULL)
RETURNS TABLE
	(
		f_id			INTEGER,
		f_description	TEXT
	)
AS
$BODY$
DECLARE
	caseTables		TEXT[] 	:= NULL;
	bCaseOptions	BOOLEAN := FALSE;
BEGIN
	SELECT 
		case_options IS NOT NULL 
	INTO
		bCaseOptions
	FROM 
		website.use_cases 
	WHERE 
		use_case = _use_case;

	IF bCaseOptions THEN
		WITH cte AS
		(
			SELECT
				jsonb_array_elements(case_options) AS j
			FROM
				website.use_cases
			WHERE
				use_case = _use_case
		)
		SELECT 
			ARRAY_AGG(j ->> 'tableName')  
		INTO
			caseTables
		FROM 
			cte
		WHERE
			 (j ->> 'tableFunction' = _function OR _function IS NULL);
	END IF;	
	
	RETURN QUERY
	SELECT DISTINCT
		ct.id,
		ct.descr
	FROM
		website.catalogue_tag ct
		LEFT JOIN website.resource_tag rt
			ON ct.id = rt.tag_id
	WHERE
		(
			rt.resource = ANY(caseTables)
			OR (caseTables IS NULL AND(_use_case IS NULL OR NOT bCaseOptions))
		)
		AND
		(
			_resource IS NULL
			OR resource ILIKE _resource
		)
	ORDER BY
		ct.descr;
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_source_by_year(INTEGER, INTEGER, TEXT, TEXT);
CREATE OR REPLACE FUNCTION postgisftw.get_source_by_year(_year INTEGER, _use_case INTEGER DEFAULT NULL, _function TEXT DEFAULT NULL, _tag TEXT DEFAULT NULL)
RETURNS TABLE
(
	f_resource			TEXT,
	f_description		TEXT,
	f_short_description	TEXT
)
AS
$BODY$
DECLARE
	caseTables		TEXT[] 	:= NULL;
	tagTables		TEXT[]  := NULL;
	bCaseOptions	BOOLEAN := FALSE;
BEGIN
	IF _tag IS NOT NULL THEN
		SELECT * FROM website.get_resources_by_tag(_Tag) INTO tagTables;
	END IF;

	SELECT 
		case_options IS NOT NULL 
	INTO
		bCaseOptions
	FROM 
		website.use_cases 
	WHERE 
		use_case = _use_case;
	IF bCaseOptions THEN
		WITH cte AS
		(
			SELECT
				jsonb_array_elements(case_options) AS j
			FROM
				website.use_cases
			WHERE
				use_case = _use_case
		)
		SELECT 
			ARRAY_AGG(j ->> 'tableName')  
		INTO
			caseTables
		FROM 
			cte
		WHERE
			 (j ->> 'tableFunction' = _function OR _function IS NULL) AND
			(j -> 'tableYears' @>  _year::TEXT::JSONB  OR j -> 'tableYears' @> ('"*"'));
	END IF;	
	RETURN QUERY
	SELECT 
		r.resource,
		descr || ' (' || provider || ')',
		short_descr::TEXT
	FROM
		website.resource_years r
		INNER JOIN website.vw_data_tables v
			ON r.resource = v.resource
	WHERE
		year =_year::TEXT
		AND (
				r.resource = ANY(caseTables) 
				OR (caseTables IS NULL AND (_use_case IS NULL OR NOT bCaseOptions))
			)
		AND (
				r.resource = ANY(tagTables)
				OR _tag IS NULL
			)
	ORDER BY
		descr;
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_source_by_nuts_level(INTEGER, INTEGER, TEXT, TEXT);
CREATE OR REPLACE FUNCTION postgisftw.get_source_by_nuts_level(_level INTEGER, _use_case INTEGER DEFAULT NULL, _function TEXT DEFAULT NULL, _tag TEXT DEFAULT NULL)
RETURNS TABLE
(
	f_resource			TEXT,
	f_description		TEXT,
	f_short_description	TEXT
)
AS
$BODY$
DECLARE
	caseTables		TEXT[] 	:= NULL;
	tagTables		TEXT[]	:= NULL;
	bCaseOptions	BOOLEAN := FALSE;
BEGIN
	IF _tag IS NOT NULL THEN
		SELECT * FROM website.get_resources_by_tag(_Tag) INTO tagTables;
	END IF;
	
	SELECT 
		case_options IS NOT NULL 
	INTO
		bCaseOptions
	FROM 
		website.use_cases 
	WHERE 
		use_case = _use_case;

	IF bCaseOptions THEN
		WITH cte AS
		(
			SELECT
				jsonb_array_elements(case_options) AS j
			FROM
				website.use_cases
			WHERE
				use_case = _use_case
		)
		SELECT 
			ARRAY_AGG(j ->> 'tableName')   
		INTO
			caseTables
		FROM 
			cte
		WHERE
			(j ->> 'tableFunction' IN (_function, '*') OR _function IS NULL) AND
			(j -> 'tableRegionLevels' @> _level::TEXT::JSONB OR j -> 'tableRegionLevels' @> ('"*"'));
	END IF;
	RETURN QUERY
	SELECT 
		r.resource,
		(descr || ' (' || provider || ')')::TEXT,
		short_descr::TEXT
	FROM
		website.resource_nuts_levels r
		INNER JOIN website.vw_data_tables v
			ON r.resource = v.resource
	WHERE
		level = _level
		AND (
				r.resource = ANY(caseTables) 
				OR (caseTables IS NULL AND (_use_case IS NULL OR NOT bCaseOptions))
			)
		AND (
				r.resource = ANY(tagTables)
				OR _tag IS NULL
			)			
	ORDER BY 
		descr;
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_source_by_year_nuts_level(INTEGER, INTEGER, INTEGER, TEXT, TEXT);
CREATE OR REPLACE FUNCTION postgisftw.get_source_by_year_nuts_level(_level INTEGER, _year INTEGER, _use_case INTEGER DEFAULT NULL, _function TEXT DEFAULT NULL, _tag TEXT DEFAULT NULL)
RETURNS TABLE
(
	f_resource			TEXT,
	f_description		TEXT,
	f_short_description	TEXT
)
AS
$BODY$
DECLARE
	caseTables		TEXT[] 	:= NULL;
	tagTables		TEXT[]	:= NULL;
	bCaseOptions	BOOLEAN := FALSE;
BEGIN
	IF _tag IS NOT NULL THEN
		SELECT * FROM website.get_resources_by_tag(_Tag) INTO tagTables;
	END IF;
	
	SELECT 
		case_options IS NOT NULL 
	INTO
		bCaseOptions
	FROM 
		website.use_cases 
	WHERE 
		use_case = _use_case;

	IF bCaseOptions THEN
		WITH cte AS
		(
			SELECT
				jsonb_array_elements(case_options) AS j
			FROM
				website.use_cases
			WHERE
				use_case = _use_case
		)
		SELECT 
			ARRAY_AGG(j ->> 'tableName')  
		INTO
			caseTables
		FROM 
			cte
		WHERE
			(j ->> 'tableFunction'  IN (_function, '*') OR _function IS NULL) AND
			(j -> 'tableRegionLevels' @>  _level::TEXT::JSONB OR j -> 'tableRegionLevels' @> ('"*"'))  AND
			(j -> 'tableYears' @>  _year::TEXT::JSONB  OR j -> 'tableYears' @> ('"*"'));
	END IF;

	RETURN QUERY
	SELECT 
		r.resource,
		(descr || ' (' || provider || ')')::TEXT,
		short_descr::TEXT
	FROM
		website.resource_year_nuts_levels r
		INNER JOIN website.vw_data_tables v
			ON r.resource = v.resource
	WHERE
		level =_level 
		AND year = _year::TEXT
		AND (
				r.resource = ANY(caseTables) 
				OR (caseTables IS NULL AND (_use_case IS NULL OR NOT bCaseOptions))
			)	
		AND (
				r.resource = ANY(tagTables)
				OR _tag IS NULL
			)				
	ORDER BY 
		descr;
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_year_nuts_level_from_source(TEXT, INTEGER, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION postgisftw.get_year_nuts_level_from_source(_resource TEXT, _year INTEGER DEFAULT NULL, _level INTEGER DEFAULT NULL, _use_case INTEGER DEFAULT NULL)
RETURNS TABLE
(
	f_level			TEXT,
	f_year			TEXT
)
AS
$BODY$
DECLARE
	caseYears	TEXT[] := NULL;
	caseLevels	TEXT[] := NULL;
	rec			RECORD;
BEGIN
	IF _use_case IS NOT NULL THEN
		WITH cte AS
		(
			SELECT
				jsonb_array_elements(case_options) AS j
			FROM
				website.use_cases
			WHERE
				use_case = _use_case
		)
		SELECT 
			ARRAY(SELECT jsonb_array_elements(j -> 'tableRegionLevels')) 	AS arrLevels,
			ARRAY(SELECT jsonb_array_elements(j -> 'tableYears'))			AS arrYears
		INTO
			caseLevels,
			caseYears
		FROM 
			cte
		 WHERE
			j ->> 'tableName' = _resource;
	END IF;

	IF caseYears::TEXT LIKE '%*%' THEN
		caseYears := NULL;
	END IF;

	IF caseLevels::TEXT LIKE '%*%' THEN
		caseLevels := NULL;
	END IF;

	RETURN QUERY
	SELECT DISTINCT
		t.level::TEXT,
		t.year::TEXT
	FROM
		website.resource_year_nuts_levels as t
	WHERE
		t.resource =_resource
		AND  (t.level::TEXT = ANY(caseLevels) OR _use_case IS NULL OR caseLevels IS NULL) AND (t.level = _level OR  _level IS NULL)
		AND  (t.year::TEXT = ANY(caseYears) OR _use_case IS NULL OR caseYears IS NULL) AND (t.year = _year::TEXT OR  _year IS NULL  )
	ORDER BY 
		t.level::TEXT,
		t.year::TEXT;
	
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_all_sources(INTEGER, TEXT, TEXT);
CREATE OR REPLACE FUNCTION postgisftw.get_all_sources(_use_case INTEGER DEFAULT NULL, _function TEXT DEFAULT NULL, _tag TEXT DEFAULT NULL)
RETURNS TABLE
(
	f_resource			TEXT,
	f_description		TEXT,
	f_short_description	TEXT
)
AS
$BODY$
DECLARE
	caseTables		TEXT[] := NULL;
	tagTables		TEXT[]	:= NULL;
	bCaseOptions	BOOLEAN := FALSE;
BEGIN
	IF _tag IS NOT NULL THEN
		SELECT * FROM website.get_resources_by_tag(_tag) INTO tagTables;
	END IF;
	SELECT 
		case_options IS NOT NULL 
	INTO
		bCaseOptions
	FROM 
		website.use_cases 
	WHERE 
		use_case = _use_case;

	IF bCaseOptions THEN
		WITH cte AS
		(
			SELECT
				jsonb_array_elements(case_options) AS j
			FROM
				website.use_cases
			WHERE
				use_case = _use_case
		)
		SELECT 
			ARRAY_AGG(j ->> 'tableName')  
		INTO
			caseTables
		FROM 
			cte
		WHERE
			(j ->> 'tableFunction' = _function OR _function IS NULL);
	END IF;

	RETURN QUERY
	SELECT
		resource,
		descr || ' (' || provider || ')',
		short_descr::TEXT
	FROM
		website.vw_data_tables e
	WHERE
		(
			resource = ANY(caseTables) 
			OR (caseTables IS NULL AND (_use_case IS NULL OR NOT bCaseOptions))
		)
		AND (
				resource = ANY(tagTables)
				OR _tag IS NULL
			)	
	
	ORDER BY
		descr;
END;
$BODY$
LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS postgisftw.get_column_values_source_json(TEXT,  JSONB, INTEGER  );
CREATE OR REPLACE FUNCTION postgisftw.get_column_values_source_json(_resource TEXT, source_selections JSONB DEFAULT NULL::JSONB, _use_case INTEGER DEFAULT NULL)
RETURNS TABLE
(
	field			TEXT,
	field_label		TEXT, 
	field_values	JSONB
)
AS
$BODY$
DECLARE 
	strQueryResource	TEXT;
	strProvider			TEXT;
	recCaseOptions		RECORD;
	recOverlap			RECORD;
	recSelected			RECORD;	
	recField			RECORD;
	recValue			RECORD;
	strWhere			TEXT := '';
	arrWhere			TEXT[];
	strQuery			TEXT;
	active_loop			TEXT;
	bValueOptions		BOOLEAN;
	LOOP_QUERY		CONSTANT TEXT := $$	SELECT
											table_name,
											column_name::TEXT,
											label::TEXT
										FROM
											information_schema.columns c
											INNER JOIN website.catalogue_field_description d
												ON column_name = d.field
										WHERE
											provider = %L
											AND table_name = %L 
											AND (resource = %L or resource IS NULL) $$;

	VALUES_QUERY	CONSTANT TEXT:= $$
					WITH cte AS
						(SELECT DISTINCT 
							%I as field_value
						FROM
							%I  
						%s 
						ORDER BY
							field_value
						),
						cte_ordered AS
						(SELECT
							value,
							CASE WHEN label = '' THEN value ELSE COALESCE(label, value) END as label
						FROM
							cte
							INNER JOIN website.catalogue_field_value_description d
								ON field_value::TEXT = d.value
						WHERE
							provider = %L
							AND (resource = %L OR resource IS NULL)
							AND field = %L
						ORDER BY 
							website.catalogue_field_value_order(provider,resource,field,value))
						SELECT
							jsonb_agg(JSONB_BUILD_OBJECT('value',value,'label', CASE WHEN label = '' THEN value ELSE COALESCE(label, value) END)) AS field_values
						FROM 
							cte_ordered	$$;		
	WHEREPART		CONSTANT TEXT := ' %I = %L ';

	VALUES_OPTIONS	CONSTANT TEXT := $$
						SELECT
							j->>'tableColumnValueOtions' != '*'
						FROM
							website.use_cases,
							jsonb_array_elements(case_options) AS j
						WHERE
							use_case = %s
							AND j ->> 'tableName' = %L $$;

	OPTIONS_QUERY	CONSTANT TEXT := $$
									SELECT
										key 					AS column_name,
										ARRAY_AGG(column_value) AS column_values
									FROM
										website.use_cases,
										jsonb_array_elements(case_options) AS j,
										jsonb_each_text(j->'tableColumnValueOtions') AS key_value,
										jsonb_array_elements_text(key_value.value::jsonb) AS column_value
									WHERE
										use_case = %s AND
										j ->> 'tableName' = %L AND
										key = %L
									GROUP BY column_name$$;
	OPTIONS_EXTRA	CONSTANT TEXT := $$ AND field_value::TEXT = ANY(%L) $$;
	
BEGIN
	
	SELECT
		query_resource,
		provider
	INTO
		strQueryResource,
		strProvider
	FROM
		website.vw_data_tables
	WHERE
		resource = _resource;


	IF source_selections ->> 'year' IS NOT NULL THEN 
		arrWhere = ARRAY_APPEND(arrWhere,FORMAT(WHEREPART,'obsTime', source_selections ->> 'year'));
	END IF;
	
	FOR recSelected IN
	SELECT
		j ->> 'field'  as field,
		j ->> 'value' as value
	FROM
		jsonb_array_elements(source_selections -> 'selected') AS j		
	LOOP
		arrWhere = array_append(arrWhere, FORMAT(WHEREPART,recSelected.field, recSelected.value));
	END LOOP;

	IF COALESCE(array_length(arrWhere,1),0) > 0 THEN
		strWhere = ' WHERE '  || ARRAY_TO_STRING(arrWhere, ' AND ');
	END IF;

	IF _use_case IS NOT NULL THEN
		EXECUTE FORMAT(VALUES_OPTIONS, _use_case, _resource) INTO bValueOptions;
		RAISE INFO '%', bValueOptions;
	END IF;
	
	FOR recField IN EXECUTE FORMAT(LOOP_QUERY,strProvider, strQueryResource, _resource)
	LOOP
		strQuery := FORMAT(VALUES_QUERY,recField.column_name, strQueryResource, strWhere, strProvider, _resource,  recField.column_name);
		
		IF _use_case IS NOT NULL AND bValueOptions THEN
			EXECUTE FORMAT(OPTIONS_QUERY, _use_case, _resource, recField.column_name) INTO recCaseOptions;
			IF recCaseOptions.column_values != '{*}' THEN
				strQuery := strQuery || FORMAT(OPTIONS_EXTRA,recCaseOptions.column_values );
			END IF;	
		END IF;
		RAISE INFO '%', strQuery;
		EXECUTE strQuery INTO recValue;
		field			= recField.column_name::TEXT;
		field_label		= recField.label::TEXT;
		field_values	= recValue.field_values::JSONB;
		
		RETURN NEXT;
	END LOOP;
	
END;
$BODY$
LANGUAGE PLPGSQL;

--old version, will be removed after frontend adjustments to support different years for predictor and outcome
DROP FUNCTION IF EXISTS postgisftw.get_xy_data(INT, INT, JSONB, JSONB);
CREATE OR REPLACE FUNCTION postgisftw.get_xy_data(_level INTEGER, _year INTEGER, X_JSON JSONB, Y_JSON JSONB)
RETURNS TABLE
(
	geo				TEXT,
	geo_name		TEXT,	
	geo_year		TEXT,
	geo_source		TEXT,
	predictor_year	TEXT,
	outcome_year	TEXT,
	x				DOUBLE PRECISION,
	y				DOUBLE PRECISION
)
AS
$BODY$
DECLARE 
	best_year	INTEGER;
BEGIN
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpSource_x AS 
	SELECT * FROM website.get_data_source_level_year (_year, X_JSON) WITH NO DATA;
	TRUNCATE TABLE tmpSource_x;
	INSERT INTO tmpSource_x SELECT * FROM website.get_data_source_level_year (_year, X_JSON);
	CALL areas.get_nuts_codes(X_JSON ->> 'source', _level,'tmpSource_x' );

	CREATE TEMPORARY TABLE IF NOT EXISTS tmpSource_y AS 
	SELECT * FROM website.get_data_source_level_year (_year, Y_JSON) WITH NO DATA;
	TRUNCATE TABLE tmpSource_y;
	INSERT INTO tmpSource_y SELECT * FROM website.get_data_source_level_year (_year, Y_JSON);
	CALL areas.get_nuts_codes(Y_JSON ->> 'source', _level,'tmpSource_y' );
	SELECT * FROM areas.get_xy_data_map_year(_level, _year, X_JSON, Y_JSON ) INTO best_year;
	RETURN QUERY
	SELECT 
		f_nuts_id,
		nuts_name,
		best_year::TEXT			AS geo_year,
		'NUTS'::TEXT 			AS geo_source,
		_year::TEXT				AS predictor_year,
		_year::TEXT				AS outcome_year,
		x.f_value::DOUBLE PRECISION,
		y.f_value::DOUBLE PRECISION
	FROM 
		areas.get_nuts_areas(best_year,_level)
		LEFT JOIN  tmpSource_x  AS x
			ON f_nuts_id = x.f_geo
		LEFT JOIN  tmpSource_y  AS y
			ON f_nuts_id = y.f_geo;
END;
$BODY$
LANGUAGE PLPGSQL;

--New version with seperate years for predictor and outcome
DROP FUNCTION IF EXISTS postgisftw.get_xy_data(INT, INT, INT, JSONB, JSONB);
CREATE OR REPLACE FUNCTION postgisftw.get_xy_data(_level INTEGER, _predictor_year INTEGER, _outcome_year INTEGER, X_JSON JSONB, Y_JSON JSONB)
RETURNS TABLE
(
	geo				TEXT,
	geo_name		TEXT,	
	geo_year		TEXT,
	geo_source		TEXT,
	predictor_year	TEXT,
	outcome_year	TEXT,
	x				DOUBLE PRECISION,
	y				DOUBLE PRECISION
)
AS
$BODY$
DECLARE 
	best_year	INTEGER;
BEGIN
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpSource_x AS 
	SELECT * FROM website.get_data_source_level_year (_predictor_year, X_JSON) WITH NO DATA;
	TRUNCATE TABLE tmpSource_x;
	INSERT INTO tmpSource_x SELECT * FROM website.get_data_source_level_year (_predictor_year, X_JSON);
	CALL areas.get_nuts_codes(X_JSON ->> 'source', _level,'tmpSource_x' );

	CREATE TEMPORARY TABLE IF NOT EXISTS tmpSource_y AS 
	SELECT * FROM website.get_data_source_level_year (_outcome_year, Y_JSON) WITH NO DATA;
	TRUNCATE TABLE tmpSource_y;
	INSERT INTO tmpSource_y SELECT * FROM website.get_data_source_level_year (_outcome_year, Y_JSON);
	CALL areas.get_nuts_codes(Y_JSON ->> 'source', _level,'tmpSource_y' );
	SELECT * FROM areas.get_xy_data_map_year(_level, _predictor_year, X_JSON, Y_JSON ) INTO best_year;
	RETURN QUERY
	SELECT 
		f_nuts_id,
		nuts_name,
		best_year::TEXT					AS geo_year,
		'NUTS'::TEXT 					AS geo_source,
		_predictor_year::TEXT			AS predictor_year,
		_outcome_year::TEXT				AS outcome_year,
		x.f_value::DOUBLE PRECISION,
		y.f_value::DOUBLE PRECISION
	FROM 
		areas.get_nuts_areas(best_year,_level)
		LEFT JOIN  tmpSource_x  AS x
			ON f_nuts_id = x.f_geo
		LEFT JOIN  tmpSource_y  AS y
			ON f_nuts_id = y.f_geo;
END;
$BODY$
LANGUAGE PLPGSQL;

DROP FUNCTION IF EXISTS postgisftw.get_x_data(INT, INT, JSONB);
CREATE OR REPLACE FUNCTION postgisftw.get_x_data(_level INTEGER, _year INTEGER, X_JSON JSONB)
RETURNS TABLE
(
	geo				TEXT,
	geo_name		TEXT,	
	geo_year		TEXT,
	geo_source		TEXT,
	predictor_year	TEXT,
	outcome_year	TEXT,
	x				DOUBLE PRECISION
)
AS
$BODY$
DECLARE 
	best_year	INTEGER;
BEGIN
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpSource_x AS 
	SELECT * FROM website.get_data_source_level_year (_year, X_JSON) WITH NO DATA;
	TRUNCATE TABLE tmpSource_x;
	INSERT INTO tmpSource_x SELECT * FROM website.get_data_source_level_year (_year, X_JSON);
	CALL areas.get_nuts_codes(X_JSON ->> 'source', _level,'tmpSource_x' );

	SELECT * FROM areas.get_x_data_map_year(_level, _year, X_JSON ) INTO best_year;
	
	RETURN QUERY
	SELECT 
		f_nuts_id,
		nuts_name,
		best_year::TEXT AS geo_year,
		'NUTS'::TEXT 	AS geo_source,
		_year::TEXT		AS predictor_year,
		_year::TEXT		AS outcome_year,
		x.f_value::DOUBLE PRECISION
	FROM 
		areas.get_nuts_areas(best_year,_level)
		LEFT JOIN  tmpSource_x  AS x
			ON f_nuts_id = x.f_geo;
END;
$BODY$
LANGUAGE PLPGSQL;



