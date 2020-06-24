*#####################################;
*#### STEP 1: Analysis of variance ###;
*#####################################;

proc glm data=predmod.housing_price PLOTS(MAXPOINTS=210000)=diagnostics;
	class ocean_proximity;
	model median_house_value=ocean_proximity;
	means ocean_proximity / hovtest=levene;
	format ocean_proximity $ocean_proximity.;
	title "ANOVA test with ocean_proximity as predictor";
	run;
	title;
quit;

proc sgplot data = predmod.housing_price;
	vline ocean_proximity / stat= mean
							response= median_house_value
							markers;
	format ocean_proximity $ocean_proximity.;


*#####################################;
*#### STEP 2: Correlation analysis ###;
*#####################################;
ods graphics / reset=all imagemap;
%let variables =  bedrooms_per_house house_per_person households housing_median_age latitude longitude 
median_house_value median_income population ocean_prox rooms_per_house total_bedrooms total_rooms;

proc corr data=predmod.features rank plots(maxpoints = 22000)=scatter(nvar=all ellipse=none);
	var &variables;
	with median_house_value;
	title "Correlation matrix and scatter-plots";
run;
title;

* Result: Based on the results, we will only keep the variables with strong correlation(i.e 0.1) in desc order;
%let impvar = median_income ocean_prox house_per_person latitude total_rooms rooms_per_house;


*################################;
*#### STEP 3: Model building ####;
*################################;
* Testing a simple linear regression model with the strongest predictor variable;
proc reg data = predmod.features ;
	model median_house_value = median_income;
	title "Simple linear regression";
run;	
quit;
title;

/* proc glm data = predmod.features
		plots(only) = (countourfit);
	model median_house_value = &impvar;
	store out = mul;
	title "Regression modelling";
run;
quit;
title;
*/


*################################;
*#### STEP 4: Model selection ###;
*################################;
proc glmselect data=predmod.features plots = all;
	STEPWISE: model median_house_value = &impvar / selection= stepwise details=steps
													select = SL slstay = 0.05 slentry = 0.05;
	title "Stepwise model selection";
run;
title;
quit;

* Let's create a macro which does the same;
%macro ModelSelection(dataset , sel);
	proc glmselect data = &dataset plots = all;
		model median_house_value = &impvar / selection= stepwise details= steps select = &sel;
	run;
%mend;

%ModelSelection(predmod.features , AIC);
%ModelSelection(predmod.features , AICC);
%ModelSelection(predmod.features , BIC);
%ModelSelection(predmod.features , SBC);


*####################################################;
*#### STEP 5: Outlier & influential obs detection ###;
*####################################################;
ods graphics on;
ods output RSTUDENTBYPREDICTED = RStud
			COOKSDPLOT = Cook
			DFFITSPLOT = Dffits
			DFBETASPANEL = Dfbs;

proc reg data = predmod.features 
			plots(MAXPOINTS = 22000 only label) = (RSTUDENTBYPREDICTED
			COOKSD
			DFFITS
			DFBETAS);
	Siglimit: model median_house_value = &_GLSIND;
run;
quit;

data dfbs01;
	set Dfbs(obs = 19672);
run;

data dfbs02;
	set Dfbs(firstobs  = 19673);
run;

data Dfbs2;
	update dfbs01 dfbs02;
	by Observation;
run;

data influential;
	merge Rstud
		Cook
		Dffits
		Dfbs2;
	by observation;
	
	if(ABS(RStudent)>3) or (Cooksdlabel ne ' ') or Dffitsout then flag = 1;
	array dfbetas{*} _dfbetasout: ;
	do i=2 to dim(dfbetas);
		if dfbetas{i} then flag =1;
	end;
	
	if(ABS(RStudent) < 3) then RStudent = .;
	if Cooksdlabel eq ' ' then CooksD = . ;
	
	if flag =1;
	drop i flag;
run;

proc print data = influential ;
	id Observation;
	var RStudent CooksD Dffitsout _dfbetasout:;
run;
	
* The number of outliers and influential observation is quite large(>20000*5%);
* Now that we know that the data was correctly collected, we will have to use a different model to fit it;


*##############################################;
*#### STEP 6: Train-test split###;
*##############################################;
proc surveyselect data = predmod.features out = train_test_split method=srs samprate = 0.8
		outall seed = 42 noprint;
	samplingunit median_house_value;
run;

data train_set;
	set work.train_test_split ;
	where Selected = 1;
run;

data test_set;
	set work.train_test_split ; 
	where Selected = 0;
run;


*###############################################;
*#### STEP 7: Predictive analytics in action ###;
*###############################################;
* Multiple linear regression;
%let interval = median_income house_per_person latitude total_rooms rooms_per_house;
%let cat = ocean_prox ;
proc glmselect data = train_set plots = all;
	effect poly = polynomial(&interval/ degree=3);
	class &cat / param=glm ref=first;
	partition fraction(validate = 0.04);
	model median_house_value = poly &cat / 
									selection = stepwise details = steps select = SBC slstay = 0.05 slentry = 0.05;
	store out = predmod.housestore;
	title "Select the best model";
run;
quit;

proc plm restore= predmod.housestore;
	score data = test_set out = scored;
run;

* Random forest regressor;
proc hpforest data = train_set;
	target median_house_value / level=interval;
	input bedrooms_per_house house_per_person households housing_median_age latitude longitude 
	median_income population rooms_per_house total_bedrooms total_rooms / level=interval;
	input ocean_prox / level= nominal;
	ods output fitstatistics = fitstats;
	save file = "\home\u38961934\PredictiveModelling\rf_fit.bin";
run;

proc hp4score data = work.test_set;
	id median_house_value;
	score file = "\home\u38961934\PredictiveModelling\rf_fit.bin"
	out = rf_scored;
run;

* So, random forest and glm have been proved to be performing really bad with this dataset;
* We shall need to tune the hyperparameters and do One-hot encoding;