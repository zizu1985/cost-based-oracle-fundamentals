rem
rem	Script:		birth_month_01.sql
rem	Author:		Jonathan Lewis
rem	Dated:		Sept 2003
rem	Purpose:	Demonstration script for Cost Based Oracle'.
rem	Purpose:	Simple selectivity - month of birth.
rem
rem	Versions tested 
rem		10.1.0.4
rem		 9.2.0.6
rem		 8.1.7.4
rem     19.3.0.0
rem
rem	Notes:
rem	When hacking the stats with the 'set_column_stats' package,
rem	10g picks up the new statistics automatically, earlier 
rem	versions will only do so if the old statistics are flushed
rem	from the shared pool.
rem
rem	The following comments relate specifically to the query:
rem		where month_no = 12
rem	and Oracle 10g
rem
rem	If you run hack_stats.sql to modify the num_distinct and the
rem	density, you will find that the NUM_DISTINCT is used to estimate
rem	the CARD in the full tablescan if there is no histogram.
rem
rem	If you change the method_opt to 'for all columns size 6', you 
rem	will find that Oracle creates a height-balanced histogram, and 
rem	the DENSITY will be used to estimate the CARD in the full tablescan.
rem
rem	If you use more than 12 buckets (there are twelve distinct values)
rem	Oracle will build a frequency histogram, and report exactly the number
rem	of rows with the value 12, whatever you do in hack_stats.  This will
rem	also occur in Oracle 8i if you use exactly 12 buckets - the mechanism 
rem	for building a histogram changed from 8i to 9i, and the results are
rem	slightly different.
rem
rem	For 9i and 10g, the histogram with 12 buckets happens to produce
rem	a special case: the number of rows with the value 12 covers two 
rem	buckets, so Oracle reports the results as 'two buckets worth'
rem	whatever you do in hack_stats.
rem
rem	Oracle 8i and Oracle 9i behave a little differently from 10g
rem	in their choice of num_distinct and density.
rem
rem	Oracle 8i always uses the DENSITY to calculate the CARD.
rem
rem	Oracle 9i uses the same strategy (NUM_DISTINCT if there is no 
rem	histogram, DENSITY if there is) - but you have to flush the 
rem	shared pool after changing the statistics, or Oracle does not
rem	pick up the new values.
rem

/*
    Czy co sie zmienilo w 19c ?
    Tak. Przy braku histogramu nie bierze statystyki num_distinct, ale czesciej denisty.
    
    Jezeli density i num_distinct nie graja, to jest brane density:
    
     kkecdn: Single Table Predicate:"AUDIENCE"."MONTH_NO"=12
  Column (#1): MONTH_NO(NUMBER)
    AvgLen: 3 NDV: 20 Nulls: 0 Density: 200.000000 Min: 1.000000 Max: 12.000000
    Histogram: HtBal  #Bkts: 1200  UncompBkts: 1200  EndPtVals: 12  ActualVal: yes
  Using density: 200.000000 of col #1 as selectivity of pred having unreasonably low value
  Table: AUDIENCE  Alias: AUDIENCE
    Card: Original: 1200.000000  Rounded: 1181  Computed: 1181.000000  Non Adjusted: 1181.000000
    
    Wtedy cardinality = num_rows - num_distinct + 1
    
*/

start setenv

execute dbms_random.seed(0);
drop table audience;

begin
	begin		execute immediate 'purge recyclebin';
	exception	when others then null;
	end;

	begin		execute immediate 'begin dbms_stats.delete_system_stats; end;';
	exception 	when others then null;
	end;

	begin		execute immediate 'alter session set "_optimizer_cost_model"=io';
	exception	when others then null;
	end;
end;
/

create table audience as
select
	trunc(dbms_random.value(1,13))	month_no
from
	all_objects
where
	rownum <= 1200
;

-- Tabela bez histogramów 
-- TODO: Co daje null dla estimate percent ? Automatycznie określi ilość wierszy do wyliczania statystyk ?
begin
	dbms_stats.gather_table_stats(
		user,
		'audience',
		cascade => true,
		estimate_percent => null,
		method_opt => 'for all columns size 1'
	);
end;
/

rem
rem	A little function to make is possible to call
rem	the conversion routines in dbms_stats from an
rem	SQL statement
rem

-- Potrzebna, bo wartosci sa przechowywane w hexach 
create or replace function value_to_number(i_raw in raw)
return number deterministic as
	m_n		number(6);
begin
	dbms_stats.convert_raw_value(i_raw,m_n);
	return m_n;
end;
/
	
spool birth_month_01

select
	column_name,
	num_distinct,
	num_nulls,
	density,
	value_to_number(low_value)	low,
	value_to_number(high_value)	high
from
	user_tab_columns
where	table_name = 'AUDIENCE'
and	column_name = 'MONTH_NO'
;
/*
    column_name => 'MONTH_NO'
    num_distinct => 12
    num_nulls    => 0
    density      => 0.0833
    low          => 1
    high         => 12
*/
-- tutaj density = 1/num_distinct 

-- Sprawdzanie co sie zmieni jak zbierzemy histogram
-- Co bedzie jak zbierzemy z histogramem ?
select histogram from user_tab_columns where table_name='AUDIENCE';
-- NONE

begin
    dbms_stats.gather_table_stats(
		user,
		'audience',
		cascade => true,
		estimate_percent => null,
		method_opt => 'for all columns size auto'
	);
end;
/

select histogram from user_tab_columns where table_name='AUDIENCE';
-- Nie ma histogramu

begin
    dbms_stats.gather_table_stats(
		user,
		'audience',
		cascade => true,
		estimate_percent => null,
		method_opt => 'for all columns size 255'
	);
end;
/

select histogram from user_tab_columns where table_name='AUDIENCE';
-- Frequency

select
	column_name,
	num_distinct,
	num_nulls,
	density,
	value_to_number(low_value)	low,
	value_to_number(high_value)	high
from
	user_tab_columns
where	table_name = 'AUDIENCE'
and	column_name = 'MONTH_NO'
;
/*
    MONTH_NO	12	0	0,000416666666666667	1	12
*/

/*
    Wracamy do poprzedniej wersji statystyk
*/
begin
	dbms_stats.gather_table_stats(
		user,
		'audience',
		cascade => true,
		estimate_percent => null,
		method_opt => 'for all columns size 1'
	);
end;
/


select * from 
	user_tab_columns
where	table_name = 'AUDIENCE'
and	column_name = 'MONTH_NO'
;



select 
	column_name, endpoint_number, endpoint_value 
from 
	user_tab_histograms 
where 
	table_name = 'AUDIENCE'
order by
	column_name, endpoint_number
;
-- Jeden bucket 1-12 dla calego zakresu, czyli bez histogramow

set autotrace traceonly explain

-- Rows = 100 = cardinality = num_rows * density = 100
explain plan for
select count(*) 
from audience
where month_no = 12
;

select * from table(dbms_xplan.display);
/*
    Plan hash value: 3337892515
    
    -------------------------------------------------------------------------------
    | Id  | Operation          | Name     | Rows  | Bytes | Cost (%CPU)| Time     |
    -------------------------------------------------------------------------------
    |   0 | SELECT STATEMENT   |          |     1 |     3 |     3   (0)| 00:00:01 |
    |   1 |  SORT AGGREGATE    |          |     1 |     3 |            |          |
    |*  2 |   TABLE ACCESS FULL| AUDIENCE |   100 |   300 |     3   (0)| 00:00:01 |
    -------------------------------------------------------------------------------
    
    Predicate Information (identified by operation id):
    ---------------------------------------------------     
       2 - filter("MONTH_NO"=12)
*/

accept x prompt 'Now use hack_stats.sql to change distinct or density'
-- Changes: num_distinct for column month_no increased by 30
-- Num distinct: 10 -> 42

alter system flush shared_pool;

explain plan for
select count(*) 
from audience
where month_no = 12
;

select * from table(dbms_xplan.display);
/*

Plan hash value: 3337892515
 
-------------------------------------------------------------------------------
| Id  | Operation          | Name     | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |          |     1 |     3 |     3   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE    |          |     1 |     3 |            |          |
|*  2 |   TABLE ACCESS FULL| AUDIENCE |   100 |   300 |     3   (0)| 00:00:01 |
-------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - filter("MONTH_NO"=12)
   
*/

-- Cardinality sie nie zmienilo, czyli 19c wzielo gestosc a nie num_distinct

-- Zmiana gestosci: 
    -- 1200 * 100 = 120000
-- Zmiana NVD:
    -- 1200 / 42 = 28.58 
    
/*

Plan hash value: 3337892515
 
-------------------------------------------------------------------------------
| Id  | Operation          | Name     | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |          |     1 |     3 |     3   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE    |          |     1 |     3 |            |          |
|*  2 |   TABLE ACCESS FULL| AUDIENCE |  1159 |  3477 |     3   (0)| 00:00:01 |
-------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - filter("MONTH_NO"=12)
   
*/
    
set autotrace off

spool off

-- hidden 


set pagesize 35
set linesize 150
col NAME format a40
col VALUE format a20
col DESCRIPTION format a60

SELECT x.ksppinm NAME, y.ksppstvl VALUE, x.ksppdesc DESCRIPTION
FROM x$ksppi x, x$ksppcv y
WHERE x.inst_id = userenv('Instance')
AND y.inst_id = userenv('Instance')
AND x.indx = y.indx
AND SUBSTR(x.ksppinm,1,1) = '_'
and x.ksppinm like '%&str%'
ORDER BY 1;  

-- Nie znalazlem zadnego specjalnego parametru 
-- ktory, by sterowal algorytmem wyliczania cardinality i selectivity

alter system flush shared_pool;
alter session set tracefile_identifier='CARDINALITY_HACKED_STATS_5';
alter session set events '10053 trace name context forever, level 2';

select count(*) 
from audience
where month_no = 12
;