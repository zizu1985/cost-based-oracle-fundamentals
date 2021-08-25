rem
rem	Script:		in_list.sql
rem	Author:		Jonathan Lewis
rem	Dated:		Sept 2003
rem	Purpose:	Demonstration script for Cost Based Oracle'.
rem	Purpose:	Simple selectivity - month of birth.
rem
rem	Versions tested 
rem		10.1.0.2
rem		 9.2.0.6
rem		 8.1.7.4
rem     19.3.0.0
rem
rem	Notes:
rem

/* 19c - wnioski

    1. Poprawnie wylicza cardinality dla wartosci z listy


*/

start setenv

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
		cascade=>true,
		estimate_percent => null,
		method_opt =>'for all columns size 1'
	);
end;
/

set autotrace traceonly explain

spool in_list

explain plan for
select count(*) from audience where month_no in (1,2,3);

select * from table(dbms_xplan.display);
/*
    Plan hash value: 3337892515     
    ---------------------------------------------------------------
    | Id  | Operation          | Name     | Rows  | Bytes | Cost  |
    ---------------------------------------------------------------
    |   0 | SELECT STATEMENT   |          |     1 |     3 |     2 |
    |   1 |  SORT AGGREGATE    |          |     1 |     3 |       |
    |*  2 |   TABLE ACCESS FULL| AUDIENCE |   300 |   900 |     2 |
    ---------------------------------------------------------------
     
    Predicate Information (identified by operation id):
    ---------------------------------------------------
     
       2 - filter("MONTH_NO"=1 OR "MONTH_NO"=2 OR "MONTH_NO"=3)
     
    Note
    -----
       - cpu costing is off (consider enabling it)
*/

explain plan for
select /*+ USE_CONCAT */ count(*) from audience where month_no in (1,2,3);

select * from table(dbms_xplan.display);
/*
Plan hash value: 3337892515
 
-------------------------------------------------------------------------------
| Id  | Operation          | Name     | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |          |     1 |     3 |     3   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE    |          |     1 |     3 |            |          |
|*  2 |   TABLE ACCESS FULL| AUDIENCE |   300 |   900 |     3   (0)| 00:00:01 |
-------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - filter("MONTH_NO"=1 OR "MONTH_NO"=2 OR "MONTH_NO"=3)
 
Hint Report (identified by operation id / Query Block Name / Object Alias):
Total hints for statement: 1 (U - Unused (1))
---------------------------------------------------------------------------
 
   1 -  SEL$1
         U -  USE_CONCAT
*/


select count(*) from audience where month_no in (1,2);
select count(*) from audience where month_no in (1,2,3);
select count(*) from audience where month_no in (1,2,3,4);
select count(*) from audience where month_no in (1,2,3,4,5);
select count(*) from audience where month_no in (1,2,3,4,5,6);
select count(*) from audience where month_no in (1,2,3,4,5,6,7);
select count(*) from audience where month_no in (1,2,3,4,5,6,7,8);
select count(*) from audience where month_no in (1,2,3,4,5,6,7,8,9);
select count(*) from audience where month_no in (1,2,3,4,5,6,7,8,9,10);
select count(*) from audience where month_no in (1,2,3,4,5,6,7,8,9,10,11);
select count(*) from audience where month_no in (1,2,3,4,5,6,7,8,9,10,11,12);
select count(*) from audience where month_no in (1,2,3,4,5,6,7,8,9,10,11,12,13);
select count(*) from audience where month_no in (1,2,3,4,5,6,7,8,9,10,11,12,13,14);


select count(*) from audience where month_no in (
	 1, 2, 3, 4, 5, 6, 7, 8, 9,10,
	11,12,13,14,15,16,17,18,19,20,
	21,22,23,24,25,26,27,28,29,30
);

set autotrace off

spool off

