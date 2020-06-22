*###############################################;
*#### STEP 1: Descriptive summary statistics ###;
*###############################################;
* Printing the data;
proc print data=predmod.housing_price (obs=100);
run;

* Checking summary statistics;
proc means data=predmod.housing_price;
run;

* Finding correlation between data;
proc corr data=predmod.housing_price nomiss rank;
run;

* Scatterplot and histograms of imp features;
proc sgscatter data=predmod.housing_price backcolor=antiquewhite 
		datacolors=(LILAC);
	title "Scatter matrix of housing data";
	plot median_house_value * (median_income total_rooms);
run;
title;

proc sgplot data=predmod.housing_price;
	histogram median_house_value;
run;

proc freq data=work.housing_price_sorted nlevels;
	table ocean_proximity;
run;


*######################################################;
*#### STEP 2: Data cleaning and feature engineering ###;
*######################################################;
* To sort the data and remove capped data from the table;
proc sort data=predmod.housing_price noduprecs out=housing_price_sorted;
	where median_house_value <=500000 and median_income<=15;
	by descending _all_;
run;

* Check which of the columns have missing values;
proc means data=work.temp nmiss;
run;    * Result: So now we know that total_bedrooms has missing values;

* Cleaning the data of missing and capped values;
data temp;
	set work.housing_price_sorted;
	bedrooms_per_house=total_bedrooms/ households;
	house_per_person=households/ population;
	rooms_per_house=total_rooms/ households;
	format bedrooms_per_house house_per_person rooms_per_house 5.3;

	if ocean_proximity="<1H OCEAN" then
		ocean_prox=1;
	else
		ocean_prox=0;
	drop ocean_proximity;

	if total_bedrooms=. then
		total_bedrooms=0;

	if bedrooms_per_house=. then
		bedrooms_per_house=0;
run;

proc contents data=work.temp;
run;


*################################;
*#### STEP 3: Feature Scaling ###;
*################################;
* Building macros for min-max scaling;
%macro MinMax(table, colname, mini, maxi);
	%global &mini &maxi;

	proc sql;
		select MIN(&colname) into: &mini from &table;
		select MAX(&colname) into: &maxi from &table;
	quit;

%mend;

proc sql;
	create table work.scaled(temp num);
quit;	

%macro Scaler(table,column, maxu, minu);
	data temp2;
		set &table(keep = &column);
		&column = (&column - &minu) / (&maxu - &minu);
		keep &column;
	run; 
/*	proc sql;
		create table work.temp3 as
			select &column from work.temp2 outer union 
			select * from work.scaled;
	quit; */
	data work.scaled;
		merge work.scaled temp2;
	run;
%mend;

* Calling all the macros;
%MinMax(work.temp, bedrooms_per_house, val, val2) ;
options spool;
%Scaler(work.temp, bedrooms_per_house, &val2, &val);

%MinMax(work.temp, house_per_person, val, val2);
%Scaler(work.temp, house_per_person, &val2, &val);
 
%MinMax(work.temp, households, val, val2);
%Scaler(work.temp, households, &val2, &val);
 
%MinMax(work.temp, housing_median_age, val, val2);
%Scaler(work.temp, housing_median_age, &val2, &val);
 
%MinMax(work.temp, latitude, val, val2);
%Scaler(work.temp, latitude, &val2, &val);
 
%MinMax(work.temp, longitude, val, val2);
%Scaler(work.temp, longitude, &val2, &val);
 
%MinMax(work.temp, median_income, val, val2);
%Scaler(work.temp, median_income, &val2, &val);
 
%MinMax(work.temp, population, val, val2);
%Scaler(work.temp, population, &val2, &val);
 
%MinMax(work.temp, rooms_per_house, val, val2);
%Scaler(work.temp, rooms_per_house, &val2, &val);
 
%MinMax(work.temp, total_bedrooms, val, val2);
%Scaler(work.temp, total_bedrooms, &val2, &val);
 
%MinMax(work.temp, total_rooms, val, val2);
%Scaler(work.temp, total_rooms, &val2, &val);


*#########################################;
*#### STEP 4: Creating feature dataset ###;
*#########################################;
data predmod.scaled;
	set work.scaled;
	drop temp;
	keep  households housing_median_age  latitude longitude median_income population 
	rooms_per_house total_bedrooms total_rooms  bedrooms_per_house house_per_person;
run;

data temp2 ;
	set temp;
	keep ocean_prox median_house_value;
run;

data predmod.features;
	merge predmod.scaled work.temp2;
run;
	



