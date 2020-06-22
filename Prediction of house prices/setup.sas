*#####Creating the library########;
libname predmod "/home/u38961934/PredictiveModelling";

*#####Creating SAS data table ####;
proc import datafile="/home/u38961934/PredictiveModelling/housing.csv" dbms=csv 
		out=predmod.housing_price replace;
	guessingrows = max;
run;

proc contents data= predmod.housing_price;

libname predmod clear;