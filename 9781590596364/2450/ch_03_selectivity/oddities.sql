rem
rem	Script:		oddities.sql
rem	Author:		Jonathan Lewis
rem	Dated:		Sept 2003
rem	Purpose:	Demonstration script for Cost Based Oracle'.
rem	Purpose:	A few random funnies with selectivity.
rem
rem	Versions tested 
rem		10.1.0.4
rem		10.1.0.2
rem		 9.2.0.4
rem		 8.1.7.4
rem     19.3.0.0
rem
rem	Notes:
rem	This suddenly behaves differently in 10.1.0.4, where
rem	queries outside the low/high range scale back some of
rem	their answers compared to 10.1.0.2
rem

/*
        where month_no = 25 (spoza zakresu ze zmniejszajaca sie linia, minimalna wartosc 1) 
            10.2 -> 100
            19c -> 1
        where month_no in (4, 4)
            10.2 -> 100
            19c -> 100


*/

start setenv
set timing off

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

create or replace function value_to_number(i_raw in raw)
return number deterministic as
	m_n		number(6);
begin
	dbms_stats.convert_raw_value(i_raw,m_n);
	return m_n;
end;
/

variable b1 number;
variable b2 number;
variable b3 number;

set autotrace traceonly explain

spool oddities

explain plan for
select count(*) from audience
where month_no = 25
;

select * from table(dbms_xplan.display);
/*

Plan hash value: 3337892515
 
-------------------------------------------------------------------------------
| Id  | Operation          | Name     | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |          |     1 |     3 |     3   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE    |          |     1 |     3 |            |          |
|*  2 |   TABLE ACCESS FULL| AUDIENCE |     1 |     3 |     3   (0)| 00:00:01 |
-------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - filter("MONTH_NO"=25)
   
*/

explain plan for
select count(*) from audience
where month_no in (4, 4)
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
       2 - filter("MONTH_NO"=4)
*/


select count(*) from audience
where month_no in (3, 25) 
;

select count(*) from audience
where month_no in (3, 25, 26)
;

select count(*) from audience
where month_no in (3, 25, 25, 26)
;

select count(*) from audience
where month_no in (3, 25, null)
;

select count(*) from audience
where month_no in (:b1, :b2, :b3)
;

set autotrace off

spool off
