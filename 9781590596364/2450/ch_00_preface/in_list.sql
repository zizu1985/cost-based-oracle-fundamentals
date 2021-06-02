rem
rem	Script:		in_list.sql
rem	Author:		Jonathan Lewis
rem	Dated:		Sept 2003
rem	Purpose:	Demonstration script for Cost Based Oracle'.
rem
rem	Versions tested 
rem     19.3.0.0.0
rem		10.1.0.4
rem		 9.2.0.6
rem		 8.1.7.4
rem
rem	Notes:
rem	The "dire warning".  
rem	An upgrade from 8 to 9 changes the in-list cardinality
rem
rem	We have a table where every value for column N1 returns
rem	100 rows. Under 9i and 10g, a list of two values produces
rem	a cardinality of 200 rows. Under 8i, the eswtimated cardinality
rem	is only 190 rows. This is an error in the optimizer code.
rem	
rem	The in-list is converted to an 'OR' list
rem		n1 = 1 OR n1 = 2
rem
rem	Unfortunately, 8i then treats the two predicates as independent,
rem	so the calculated cardinality is
rem		estimate of rows where n1 = 1	(one in 10 = 100) plus
rem		estimate of rows where n1 = 2	(one in 10 = 100) minus
rem		estimate of rows where 'n1 = 1 and n1 = 2' ... one in 100 = 10.
rem
rem	See the Chapter 3 "Basic Selectivity" for more details
rem

/*
    P(A u B) = P(A) + P(B) - P(A) * P(B)
    1/10 * 1000 + 1/10 * 1000 - (1/10 * 1/10 * 1000) = 100 + 100 - 10 = 190
    
    W 19.3.0.0.0 estymacja liczebności wierszy zachowuje się poprawnie. Jest 200 wierszy do pobrania.
    

*/

start setenv

drop table hr.t1;

begin
	begin		
        execute immediate 'purge recyclebin';
	exception	
        when others then null;
	end;

	begin		
        execute immediate 'begin dbms_stats.delete_system_stats; end;';
	exception 	
        when others then null;
	end;

	begin
        execute immediate 'alter session set "_optimizer_cost_model"=io';
	exception
        when others then null;
	end;

end;
/


create table hr.t1
as
select
	trunc((rownum-1)/100)	n1,
	rpad('x',100)		padding
from
	all_objects
where
	rownum <= 1000
;

-- bez histogramow
-- estimate_percent = default
begin
	dbms_stats.gather_table_stats(
		'hr',
		't1',
		cascade => true,
		estimate_percent => null,
		method_opt => 'for all columns size 1'
	);
end;
/
///
set autotrace traceonly explain


spool in_list

explain plan for
select 
	* 
from	t1
where
	n1 in (1,2)
;

select * from table(dbms_xplan.display);

/*

Plan hash value: 3617692013
 
--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |   200 | 20800 |     6   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| T1   |   200 | 20800 |     6   (0)| 00:00:01 |
--------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   1 - filter("N1"=1 OR "N1"=2)
   
Note
-----
   - cpu costing is off (consider enabling it) 
   
*/

spool off


set doc off
doc

Under 8i, the cardinality of an in-list is too low.

Execution Plan (8.1.7.4 autotrace)
----------------------------------------------------------
   0      SELECT STATEMENT Optimizer=ALL_ROWS (Cost=3 Card=190 Bytes=19570)
   1    0   TABLE ACCESS (FULL) OF 'T1' (Cost=3 Card=190 Bytes=19570)


Execution Plan (9.2.0.6 autotrace)
----------------------------------------------------------
   0      SELECT STATEMENT Optimizer=ALL_ROWS (Cost=4 Card=200 Bytes=20600)
   1    0   TABLE ACCESS (FULL) OF 'T1' (Cost=4 Card=200 Bytes=20600)


Execution Plan (10.1.0.4 autotrace)
----------------------------------------------------------
   0      SELECT STATEMENT Optimizer=ALL_ROWS (Cost=4 Card=200 Bytes=20600)
   1    0   TABLE ACCESS (FULL) OF 'T1' (TABLE) (Cost=4 Card=200 Bytes=20600)


#

-- Sprawdzenie co sie stanie jezeli wprowadzimy do listy wartosci spoza zakresu
explain plan for
select 
	* 
from	hr.t1
where
	n1 in (11,12)
;
-- 144 wiersze. 
-- 1 wiersz dla 101 i 1

select * from table(dbms_xplan.display);
/*

Plan hash value: 3617692013
 
----------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost  |
----------------------------------------------------------
|   0 | SELECT STATEMENT  |      |    72 |  7488 |     4 |
|*  1 |  TABLE ACCESS FULL| T1   |    72 |  7488 |     4 |
----------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   1 - filter("N1"=11 OR "N1"=12)
 
Note
-----
   - cpu costing is off (consider enabling it)
   
*/

/*
Plan hash value: 3617692013
 
----------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost  |
----------------------------------------------------------
|   0 | SELECT STATEMENT  |      |     1 |   104 |     4 |
|*  1 |  TABLE ACCESS FULL| T1   |     1 |   104 |     4 |
----------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   1 - filter("N1"=101 OR "N1"=102)
 
Note
-----
   - cpu costing is off (consider enabling it)
*/

-- Czasami po prostu nie generuje trace, a flush pomaga
alter system flush shared_pool;
alter session set TRACEFILE_IDENTIFIER='_in_list_11_12';
ALTER SESSION SET EVENTS='10053 trace name context forever, level 1';
select 
	* 
from	hr.t1
where
	n1 in (11,12)
;
ALTER SESSION SET EVENTS '10053 trace name context off';

/*

***************************************
BASE STATISTICAL INFORMATION
***********************
Table Stats::
  Table: T1  Alias: T1
  #Rows: 1000  SSZ: 0  LGR: 0  #Blks:  20  AvgRowLen:  104.00  NEB: 0  ChainCnt:  0.00  ScanRate:  0.00  SPC: 0  RFL: 0  RNF: 0  CBK: 0  CHR: 0  KQDFLG: 129
  #IMCUs: 0  IMCRowCnt: 0  IMCJournalRowCnt: 0  #IMCBlocks: 0  IMCQuotient: 0.000000
  Column (#1): N1(NUMBER)
    AvgLen: 3 NDV: 10 Nulls: 0 Density: 0.100000 Min: 0.000000 Max: 9.000000
try to generate single-table filter predicates from ORs for query block SEL$1 (#0)
finally: "T1"."N1"=11 OR "T1"."N1"=12

SINGLE TABLE ACCESS PATH
  Single Table Cardinality Estimation for T1[T1]
  SPD: Return code in qosdDSDirSetup: NOCTX, estType = TABLE

 kkecdn: Single Table Predicate:"T1"."N1"=11 OR "T1"."N1"=12
  Using prorated density: 0.077778 of col #1 as selectivity of out-of-range/non-existent value pred
  Using prorated density: 0.077778 of col #1 as selectivity of out-of-range/non-existent value pred
  Using prorated density: 0.066667 of col #1 as selectivity of out-of-range/non-existent value pred
  Using prorated density: 0.066667 of col #1 as selectivity of out-of-range/non-existent value pred
  Table: T1  Alias: T1
    Card: Original: 1000.000000  Rounded: 144  Computed: 144.444444  Non Adjusted: 144.444444
  Scan IO  Cost (Disk) =   7.000000
  Scan CPU Cost (Disk) =   295308.800000
  Cost of predicates:
    io = 0.000000, cpu = 96.111111, sel = 0.144444 flag = 2048  (Inlist)
      io = NOCOST, cpu = 50.000000, sel = 0.077778 flag = 2048  ("T1"."N1"=11)
      io = NOCOST, cpu = 50.000000, sel = 0.066667 flag = 2048  ("T1"."N1"=12)
  Total Scan IO  Cost  =   7.000000 (scan (Disk))
                         + 0.000000 (io filter eval) (= 0.000000 (per row) * 1000.000000 (#rows))
                       =   7.000000
  Total Scan CPU  Cost =   295308.800000 (scan (Disk))
                         + 96111.111111 (cpu filter eval) (= 96.111111 (per row) * 1000.000000 (#rows))
                       =   391419.911111
  Access Path: TableScan
    Cost:  7.028488  Resp: 7.028488  Degree: 0
      Cost_io: 7.000000  Cost_cpu: 391420
      Resp_io: 7.000000  Resp_cpu: 391420
  Best:: AccessPath: TableScan
         Cost: 7.028488  Degree: 1  Resp: 7.028488  Card: 144.444444  Bytes: 0.000000
  
 Proporcjonalna gęstość ?
 Skad wzielo sie 0.1 ? Denisty = 1 / NVD = 1 / 10 = 0.1 
 # Density: 0.100000
 
 Using prorated density: 0.077778 of col #1 as selectivity of out-of-range/non-existent value pred
 Using prorated density: 0.077778 of col #1 as selectivity of out-of-range/non-existent value pred
 Using prorated density: 0.066667 of col #1 as selectivity of out-of-range/non-existent value pred
 Using prorated density: 0.066667 of col #1 as selectivity of out-of-range/non-existent value pred
 
   Cost of predicates:
    io = 0.000000, cpu = 96.111111, sel = 0.144444 flag = 2048  (Inlist)
      io = NOCOST, cpu = 50.000000, sel = 0.077778 flag = 2048  ("T1"."N1"=11)
      io = NOCOST, cpu = 50.000000, sel = 0.066667 flag = 2048  ("T1"."N1"=12)
 
 Dlaczego spadla z 0.1 do 0.07 ?
    1 / 10 = 0.1
    1 / 13 = 0.077 = 0.8 * 0.1 = 0.08
    1 / 15 = 0.066 = 0.7 * 0.1 = 0.07
    
    0.15 * 1000 = 150 wierszy
    
    Spadajaca linia (regresja liniowa).
        Initiali 0.1 dla 0.9, Przedial rowny 10, czyli wartosci 10 dostanie 90% z 0.1, Wartosc 11 dostanie 80% z 0.1 
  
*/

-- Czyli jezeli zrobie to samo dla 22 i 23 to powinno byc 0?
-- Jest 1, bo selectivity wyszlo 0.001 czyli 0.001 x 1000 = 1
alter system flush shared_pool;
alter session set TRACEFILE_IDENTIFIER='_in_list_22_23';
ALTER SESSION SET EVENTS='10053 trace name context forever, level 1';
select 
	* 
from	hr.t1
where
	n1 in (22,23)
;
ALTER SESSION SET EVENTS '10053 trace name context off';

/*

SINGLE TABLE ACCESS PATH
  Single Table Cardinality Estimation for T1[T1]
  SPD: Return code in qosdDSDirSetup: NOCTX, estType = TABLE

 kkecdn: Single Table Predicate:"T1"."N1"=22 OR "T1"."N1"=23
  Using prorated density: 5.0000e-04 of col #1 as selectivity of out-of-range/non-existent value pred
  Using prorated density: 5.0000e-04 of col #1 as selectivity of out-of-range/non-existent value pred
  Using prorated density: 5.0000e-04 of col #1 as selectivity of out-of-range/non-existent value pred
  Using prorated density: 5.0000e-04 of col #1 as selectivity of out-of-range/non-existent value pred
  Table: T1  Alias: T1
    Card: Original: 1000.000000  Rounded: 1  Computed: 1.000000  Non Adjusted: 1.000000
  Scan IO  Cost (Disk) =   5.000000
  Scan CPU Cost (Disk) =   0.000000
  Cost of predicates:
    io = NOCOST, cpu = NOCOST, sel = 0.001000 flag = 0  (Inlist)
      io = NOCOST, cpu = NOCOST, sel = 0.000500 flag = 0  ("T1"."N1"=22)
      io = NOCOST, cpu = NOCOST, sel = 0.000500 flag = 0  ("T1"."N1"=23)
    
*/

