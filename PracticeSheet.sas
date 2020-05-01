/* The below code chunk is to understand the working of certain procs */
libname pg1 "/home/u38961934/EPG194/data";

/* Using the different Proc functions */
*Limiting the observations to 10;

proc print data=pg1.storm_summary (obs=10);
	var StartDate MinPressure Name Season MaxWindMPH EndDate;
run;

proc means data=pg1.storm_summary;
	var MinPressure MaxWindMPH;
run;

proc univariate data=pg1.storm_summary;
	var MinPressure MaxWindMPH;
run;

proc freq data=pg1.storm_summary;
	table Season;
run;

/* Write the proc freq step to analyze rows with where clause and macros */
%let ParkCode = ZION;
%let SpeciesCat = Bird;

proc freq data=pg1.np_species;
	tables Abundance Conservation_Status;
	WHERE Species_ID like "&ParkCode%" and Category="&SpeciesCat";
run;

proc print data=pg1.np_species;
	var Species_ID Category Scientific_Name Common_Names;
	WHERE Species_ID like "&ParkCode%" and Category="&SpeciesCat";
run;

/* Code to format the date  */
proc print data=pg1.storm_summary(obs=20);
	format Lat Lon 4. StartDate EndDate date11.;
run;

proc freq data=pg1.storm_summary order=freq;
	tables StartDate;
	FORMAT StartDate MONNAME.;
	*Add a FORMAT statement;
run;

/* Code to sort the data and remove the duplicates */
proc sort data=pg1.np_largeparks out=park_clean noduprecs dupout=park_dups;
	by _all_;
run;

/* Code to create a table using data */
data Storm_cat5;
	set pg1.storm_summary;
	Where MaxWindMPH >=156 and StartDate >='01Jan2000'd;
	keep Season Basin Name Type MaxWindMPH;
run;

/* Code to create table and assign format to it */
data eu_occ2016;
	set pg1.eu_occ;
	WHERE YearMon like '2016%';
	format Hotel Shortstay Camp COMMA17.;
	drop geo;
run;

/* Create a permanent table in the output folder and sort */
data pg1.fox;
	set pg1.np_species;
	where category="Mammal" and Common_Names like '%Fox%';
	where also Common_Names not like '%Squirrel%';
	drop Category Record_Status Occurence Nativeness;
run;

proc sort data=pg1.fox;
	by Common_Names;
run;

/* Code to create new columns using numeric summary functions */
data storm_wingavg;
	set pg1.storm_range;
	*Add assignment statements;
	WindAvg=MEAN(wind1, wind2, wind3, wind4);
	WindRange=RANGE(wind1, wind2, wind3, wind4);
run;

/* Code to create new columns using string summary functions */
data np_summary_update;
	set pg1.np_summary;
	SqMiles=Acres * 0.0015625;
	Camping=SUM(OtherCamping, TentCampers, RVCampers, BackcountryCampers);
	FORMAT SqMiles Comma6. Camping 6.1;
	keep SqMiles Camping;
run;

/* More Code to create new columns using string summary functions */
data eu_occ_total;
	set pg1.eu_occ;
	Year=SUBSTR(YearMon, 1, 4);
	Month=SUBSTR(YearMon, 6, 2);
	ReportDate=MDY(Month, 1, Year);
	Total=SUM(Hotel, ShortStay, Camp);
	FORMAT Hotel ShortStay Camp Total COMMA10. ReportDate monyy7.;
	Keep Country Hotel ShortStay Camp ReportDate Total;
run;

/* Using If then else statements */
data park_type;
	set pg1.np_summary;
	*Add IF-THEN-ELSE statements;
	LENGTH Parktype $ 10;

	if Type="NM" then
		ParkType="Monument";
	else if Type="NP" then
		ParkType="Park";
	else if Type in("NPRE", "PRE", "PRESERVE") then
		ParkType="Preserve";
	else if Type="NS" then
		ParkType="Seashore";
	else if Type in("RVR", "RIVERWAYS") then
		ParkType="River";
run;

proc freq data=park_type;
	tables ParkType;
run;

/* Using if then do else statements for multiple tables */
data parks monuments;
	set pg1.np_summary;
	WHERE Type="NP" or Type="NM";
	Campers=SUM(OtherCamping, BackcountryCampers, RVCampers, TentCampers);
	FORMAT Campers COMMA10.;
	LENGTH ParkType $ 10;

	if Type="NP" then
		do;
			ParkType="Park";
			output parks;
		end;
	else if Type="NM" then
		do;
			ParkType="Monument";
			output monuments;
		end;
	Keep Reg ParkName DayVisits OtherLodging Campers ParkType;
run;

/* Code to use labels & titles */
data cars_update;
	set sashelp.cars;
	keep Make Model MSRP Invoice AvgMPG;
	AvgMPG=mean(MPG_Highway, MPG_City);
	by Make;
	label MSRP="Manufacturer Suggested Retail Price" 
		AvgMPG="Average Miles per Gallon" Invoice="Invoice Price";
run;

proc means data=cars_update min mean max;
	var MSRP Invoice;
run;

proc print data=cars_update label noobs;
	var Make Model MSRP Invoice AvgMPG;
run;

/* Create custom frequency tables using freq proc */
ods graphics on;
ods noproctitle;
title "Frequency tables for Basin and Month";

proc freq data=pg1.storm_final order=freq nlevels;
	tables Basin StartDate / nocum plots=freqplot(orient=horizontal scale=percent);
	label Basin="Basin Name" StartDate="Month";
	format StartDate monname3.;
run;

/* Create one way frequency reports */
ods graphics on;
ods noproctitle;
title "Categories of reported species";
title2 "in the Everglades";

proc freq data=pg1.np_species order=freq;
	tables Category / nocum plots=freqplot(orient=horizontal);
	WHERE Species_ID like 'EVER%' and Category ne 'Vascular Plant';
run;

/* Create two way frequency reports */
ods noproctitle;
title "Selected Park Types by Region";

proc freq data=pg1.np_codelookup order=freq;
	tables Type*Region / nopercent crosslist plots=freqplot(groupby=row 
		scale=grouppercent orient=horizontal);
	WHERE Type not like '%Other%' and Type in('National Park', 
		'National Monument', 'National Historic Site');
run;

title;

/* Producing a descriptive statistics report */
title "Weather Statistics by Year and Park";

proc means data=pg1.np_westweather mean min max maxdec=2;
	var PRECIP SNOW TEMPMIN TEMPMAX;
	Class Year Name;
run;

title;

/* Creating an output table with custom columns */
proc means data=pg1.np_westweather;
	where Precip ^= 0;
	var Precip;
	class Name Year;
	ways 2;
	output out=rainstats N=RainDays sum=TotalRain;
run;

title "Rain Statistics by Year and Park";

proc print data=work.rainstats noobs label;
	var Name Year RainDays TotalRain;
	label Name="Park name" RainDays="Number of Days Raining" 
		TotalRain="Total Rain Amount(inches)";
run;

title;


/* Code to generate the output in an excel report using ODS */
ods excel file="&outpath/StormStats.xlsx" style=snow 
	options(sheet_name='South Pacific Summary');
ods noproctitle;
title;

proc means data=pg1.storm_detail maxdec=0 median max;
	class Season;
	var Wind;
	where Basin='SP' and Season in (2014, 2015, 2016);
run;

ods excel options(sheet_name='Detail');

proc print data=pg1.storm_detail noobs;
	where Basin='SP' and Season in (2014, 2015, 2016);
	by Season;
run;
ods proctitle;
ods excel close;


/* Code to generate the output in an RTF file using ODS */
ods rtf file="&outpath/ParkReport.rtf" style=journal startpage=NO;
title "US National Park Regional Usage Summary";
ods noproctitle;

options nodate;

proc freq data=pg1.np_final;
	tables Region /nocum;
run;

proc means data=pg1.np_final mean median max nonobs maxdec=0;
	class Region;
	var DayVisits Campers;
run;

title2 'Day Visits vs. Camping';
ods rtf style=SASDOCPRINTER;

proc sgplot data=pg1.np_final;
	vbar Region / response=DayVisits;
	vline Region / response=Campers;
run;

options date;
title;
ods proctitle;
ods rtf close;


/* Code to use SQL in SAS with some date formating*/
option obs = 10;
proc sql;
	select Name, MaxWindMPH, MinPressure, StormType, StartDate format = mmddyy10.
	from pg1.storm_final
	where MaxWindMPH > 156 and StormType is not NULL and StartDate > mdy(10,27,2015)
	order by MaxWindMPH desc;
quit;


/* Code to create a table in SAS using SQL query */
proc sql;
	*Modify the query to create a table;
	create table pg1.top_damage as 
		select Event, Date format=monyy7., Cost 
		format=dollar16.
    from pg1.storm_damage order by Cost desc;
	*Add a title and query to create a top 10 report;
	title "Top 10 Storms by Damage Cost";
	options obs=10;
	select * from pg1.top_damage;
quit;


/* Code to join two tables in SQL using SAS */
proc sql;
select Season, Name, s.Basin, BasinName, MaxWindMPH 
    from pg1.storm_summary as s inner join pg1.storm_basincodes as b
    on s.Basin = b.Basin
    order by Season desc, Name;
quit;

