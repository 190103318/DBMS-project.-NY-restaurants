CREATE OR REPLACE FUNCTION extract_number(in_number VARCHAR2) 
RETURN NUMBER IS
BEGIN
RETURN regexp_replace(in_number, '[^[:digit:]]', '');
END;
-------------------------------------------------------------------------
SELECT *
FROM   (
    SELECT *
    FROM   
        (SELECT *
        FROM restaurants
        WHERE review_count IS NOT NULL AND extract_number(review_count) IS NOT NULL
        ORDER BY extract_number(review_count) DESC
        )
    WHERE ROWNUM <= 9
    ORDER BY DBMS_RANDOM.RANDOM )
WHERE  rownum < 2;

--------------------------------------------------------------------------

SELECT * FROM (
    SELECT *
    FROM restaurants
    WHERE review_count IS NOT NULL AND extract_number(review_count) IS NOT NULL
    ORDER BY extract_number(review_count) DESC
    )
WHERE ROWNUM <= 12;

---------------------------------------------------------------------------

SELECT * FROM (
    SELECT *
    FROM restaurants
    WHERE STAR_5 IS NOT NULL 
    ORDER BY STAR_5 DESC
    )
WHERE ROWNUM <= 12;

select * from restaurants;
---------------------------------------------------------------------------
alter table restaurants
add image blob;

DECLARE
src_lob BFILE := BFILENAME('IMAGES', 'resto6.jpg');
dest_lob BLOB;
BEGIN
UPDATE restaurants SET image = EMPTY_BLOB() WHERE name = 'Danji'
RETURNING image INTO dest_lob;
DBMS_LOB.OPEN(src_lob, DBMS_LOB.LOB_READONLY);
DBMS_LOB.LoadFromFile( DEST_LOB =>dest_lob,
SRC_LOB =>src_lob,
AMOUNT =>DBMS_LOB.GETLENGTH(src_lob) );
DBMS_LOB.CLOSE(src_lob);
COMMIT;
END;
/
-------------------------------------------------------------------------
alter table restaurants
add price VARCHAR(50);


CREATE OR REPLACE PROCEDURE fill_price_col AS
CURSOR price_range_curs IS 
SELECT id, price_range FROM restaurants;
curs restaurants%ROWTYPE;
BEGIN
FOR curs IN price_range_curs
LOOP
CASE curs.price_range
    WHEN '$31 to $50' THEN 
    UPDATE restaurants 
    set price = 'Medium'
    where id = curs.id;
    WHEN '$30 and under' THEN 
    UPDATE restaurants 
    set price = 'Low'
    where id = curs.id;
    WHEN '$50 and over' THEN 
    UPDATE restaurants 
    set price = 'High'
    where id = curs.id;
    ELSE 
    UPDATE restaurants 
    set price = 'Medium'
    where id = curs.id;
END CASE;
END LOOP;
END fill_price_col;

BEGIN
fill_price_col;
END;
-----------------------------------------------------------------------------------------------
--'High,star_5,Italian'
create or replace PROCEDURE filter_data(p_input IN VARCHAR, res OUT VARCHAR)
IS
TYPE FILTER_TAB IS TABLE OF VARCHAR2(100) INDEX BY PLS_INTEGER;
v_filter FILTER_TAB;
TYPE RESTO_TAB IS TABLE OF restaurants%ROWTYPE INDEX BY PLS_INTEGER;
v_resto RESTO_TAB;
v_query VARCHAR(8000);
V_condition VARCHAR(4000);
v_next VARCHAR(50);
counter NUMBER := 0;
BEGIN
SELECT regexp_substr(p_input,'[^,]+', 1, level) BULK COLLECT INTO v_filter
FROM dual
CONNECT BY regexp_substr(p_input, '[^,]+', 1, level) IS NOT NULL;
v_query := 'SELECT * FROM RESTAURANTS ';
v_condition  := NULL;
FOR i IN 1 .. v_filter.COUNT
LOOP
v_next := v_filter(i);      
        IF UPPER(v_next) = UPPER('low') OR UPPER(v_next) = UPPER('medium') OR UPPER(v_next) = UPPER('high') AND v_next IS NOT NULL
        THEN
            v_condition  := v_condition || 'AND price = '||''''|| v_next || '''' || ' '; 
        ELSIF UPPER(v_next) LIKE UPPER('%star%') AND v_next != 'star_' AND v_next IS NOT NULL
        THEN
            v_condition  := v_condition || 'AND '|| v_next || '>10 ';
        ELSE 
            IF(counter = 0 AND v_next IS NOT NULL) THEN
                v_condition := v_condition || 'AND restaurant_main_type = '||''''||v_next ||''''|| ' ';
                counter:=counter + 1;
            ELSIF(v_next IS NULL) THEN
                v_condition := v_condition;
            ELSE
                IF(v_next IS NOT NULL) THEN
                v_condition := v_condition || 'OR restaurant_main_type = '||''''||v_next ||''''|| ' ';
                counter:=counter + 1;
                END IF;
            END IF;
        END IF;
END LOOP;
IF (v_condition IS NULL) THEN
    v_query := v_query || v_condition;
ELSE
    v_condition := SUBSTR(v_condition, 4);
    v_query := v_query || ' WHERE ' ||  v_condition;
END IF;
EXECUTE IMMEDIATE v_query  BULK COLLECT INTO v_resto;
FOR i IN 1 .. v_resto.COUNT
LOOP
res := res||v_resto(i).id||'::'||v_resto(i).name||'::'||v_resto(i).street_address||'::'||v_resto(i).average_review||'::'||v_resto(i).restaurant_main_type||'::'||v_resto(i).price||'::'||v_resto(i).imagee||':::';
DBMS_OUTPUT.PUT_LINE(v_resto(i).id || ' :: '|| v_resto(i).name || ' :: '|| v_resto(i).street_address || ' :: '|| v_resto(i).average_review || ' :: '|| v_resto(i).restaurant_main_type || ' :: '|| v_resto(i).price);
END LOOP;
--DBMS_OUTPUT.PUT_LINE(v_query);
END filter_data;
-----------------------------------------------------------------------------------------------
create or replace PROCEDURE recommend_data(p_input IN VARCHAR, res OUT VARCHAR)
IS
TYPE RESTO_TAB IS TABLE OF restaurants%ROWTYPE INDEX BY PLS_INTEGER;
v_resto RESTO_TAB;
v_query VARCHAR(8000);
V_condition VARCHAR(4000);
BEGIN
v_query := 'SELECT * FROM 
(SELECT * FROM restaurants
WHERE restaurant_main_type = '||''''||p_input||''''||' and average_review > '||''''||'5'||''''||' or average_review > '||''''||'4'||''''||' ORDER BY DBMS_RANDOM.RANDOM)
WHERE ROWNUM <= 4 AND restaurant_main_type = '||''''||p_input||'''';
EXECUTE IMMEDIATE v_query  BULK COLLECT INTO v_resto;
FOR i IN 1 .. v_resto.COUNT
LOOP
res := res||v_resto(i).id||'::'||v_resto(i).name||'::'||v_resto(i).street_address||'::'||v_resto(i).average_review||'::'||v_resto(i).restaurant_main_type||'::'||v_resto(i).price||'::'||v_resto(i).imagee||':::';
DBMS_OUTPUT.PUT_LINE(v_resto(i).id || ' :: '|| v_resto(i).name || ' :: '|| v_resto(i).street_address || ' :: '|| v_resto(i).average_review || ' :: '|| v_resto(i).restaurant_main_type || ' :: '|| v_resto(i).price);
END LOOP;
--DBMS_OUTPUT.PUT_LINE(v_query);
END recommend_data;
------------------------------------------------------------------------------------
create or replace PROCEDURE search_data (p_input IN VARCHAR, res OUT VARCHAR)
IS
TYPE RESTO_TAB IS TABLE OF restaurants%ROWTYPE INDEX BY PLS_INTEGER;
v_resto RESTO_TAB;
v_query VARCHAR(8000);
V_condition VARCHAR(4000);
BEGIN
v_query := 'SELECT * FROM RESTAURANTS ';
v_condition  := 'name LIKE '||''''||'%'||p_input||'%'||''''||' OR street_address LIKE '||''''||'%'||p_input||'%'||'''';
IF (p_input = ' ') THEN
    v_query := v_query || v_condition;
ELSE
    v_query := v_query || ' WHERE ' ||  v_condition;
END IF;
EXECUTE IMMEDIATE v_query  BULK COLLECT INTO v_resto;
FOR i IN 1 .. v_resto.COUNT
LOOP
res := res||v_resto(i).id||'::'||v_resto(i).name||'::'||v_resto(i).street_address||'::'||v_resto(i).average_review||'::'||v_resto(i).restaurant_main_type||'::'||v_resto(i).price||'::'||v_resto(i).imagee||':::';
DBMS_OUTPUT.PUT_LINE(v_resto(i).id || ' :: '|| v_resto(i).name || ' :: '|| v_resto(i).street_address || ' :: '|| v_resto(i).average_review || ' :: '|| v_resto(i).restaurant_main_type || ' :: '|| v_resto(i).price);
END LOOP;
--DBMS_OUTPUT.PUT_LINE(v_query);
END search_data;





