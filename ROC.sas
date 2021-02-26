%macro roc (dt=, 
	    var = , 
	    y=, 
	    cov=, 
	    event='1', 
	    format=, 
	    output_roc=a, 
	    output_auc=auc, 
	    result=result, 
	    plot=1, 
	    outfile=);
%let n=%sysfunc(countw(&var));
data &output_auc;
	stop;
run;
data cc;
	stop;
run;

%do i=1 %to &n;
	%let val = %scan(&var,&i);
/*	Fit Logistic regression models*/
	proc logistic data=&dt plots=roc;
		model &y (event= &event)=&val &cov/outroc=&val;
		roc;
		roccontrast;
		ODS OUTPUT ROCASSOCIATION = &val._AUC ParameterEstimates=est ROCContrastTest=pval;
	run;

	proc print data=&val._AUC;run;

	data &val;
	length _SOURCE_ $50;
	set &val;
	if _SOURCE_ = 'Model' then _SOURCE_="&val";
	run;


	/*DATASET FOR AUC RESULTS*/
	data &val._AUC;
	set &val._AUC;
	group="&val";
	var=group;
	format group &format;
	run;
	data &output_auc;
	set &output_auc &val._AUC;
	run;
	/*DATASET FOR ROC*/
	data &val;
	length _SOURCE_ $50;
	set &val;
	group="&val";
	var=group;
	format group &format;
	run;

	/*DATASET FOR RESULT */
	data test;
		length group $50;
		set &val;
		spec=1-_1MSPEC_;
		criteria_1=spec +_SENSIT_;
		criteria_2=spec + 1.5 * _SENSIT_;
	run;

	proc transpose data=est out=est_t;
	run;

	proc sql;
	create table c1 as
	select  group, _SENSIT_ as sen_c1, spec as spe_c1, _prob_ as prob1
	from test  
	where _source_="&val" 
	having criteria_1=max(criteria_1);

	create table betas1 as
	select  col1 as b0_1, col2 as b1_1, %tslit(&val) as group 
	from est_t 
	where _name_="Estimate";

	create table c2 as
	select  group, _SENSIT_ as sen_c2, spec as spe_c2, _prob_ as prob2
	from test  
	where _source_="&val" 
	having criteria_2=max(criteria_2);

	create table betas2 as
	select  col1 as b0_2, col2 as b1_2, %tslit(&val) as group 
	from est_t 
	where _name_="Estimate";
	quit;
	
	data aucsub;
	set &val._AUC;
	keep group Area LowerArea UpperArea ;
	where rocmodel="Model";
	group=%tslit(&val);
	run;

	data par1; merge aucsub c1 betas1; by group;run;
	data par2; merge  c2 betas2; by group;run;

	proc sql;
	create table c as 
	select * from par1 as x
	join par2 as y on x.group=y.group;
	quit;

	/*	Add pvalue*/
	data p;
	set pval;
	group=%tslit(&val);
	keep group ProbChiSq;
	run;

	data c;
	merge c p;
	by group;
	run;

	data cc;
	set cc c;
%end;


/*Generate ROC output with all variables (for R)*/
data &output_roc; 
	set &var;
run;

proc print data=a;
run;

/*Generate a Result table*/

%if %length(&cov) ne 0 %then 
	%do;
		proc sql;
		create table &result as
		select group, 
		cat(round(area,.001),' (', round(lowerarea,.01),', ' ,round(upperarea,.01), ')') as auc, 
		round(ProbChiSq,.001) as P,
		round(prob1,.01) as oc1,sen_c1, spe_c1, 
		round(prob2,.01) as oc2,sen_c2, spe_c2 from cc;
		quit;
	%end;
%else
	%do;
		proc sql;
		create table &result as
		select group,
		cat(round(area,.001),' (', round(lowerarea,.01),', ' ,round(upperarea,.01), ')') as auc, 
		round(ProbChiSq,.001) as P,
		(log(prob1/(1-prob1))-b0_1)/b1_1 as oc1,sen_c1, spe_c1, 
		(log(prob2/(1-prob2))-b0_2)/b1_2 as oc2,sen_c2, spe_c2 from cc;
		quit;
	%end;

proc sql;
create table verre as
select group, auc, p, oc1, sen_c1, spe_c1,"1" as criteria
from &result 
UNION ALL
select group, auc, p, oc2 as oc1, sen_c2 as sen_c1, spe_c2 as spe_c1, "2" as criteria
from &result ;
quit;

data verre;
set verre;
sen_c1=round(sen_c1,.01);
spe_c1=round(spe_c1,.01);
run;

/*%if %length(&cov) ne 0 %then %do;*/
/*	data verre;*/
/*	set verre;*/
/*	group="Model";*/
/*	run;*/
/*%end;*/

proc contents data= verre;run;
proc print data=verre;run;

*ods escapechar = '~';
ods rtf file=&outfile bodytitle;
proc report data=verre nowd headline headskip
	style(report) = {cellpadding = 1.25pt
				cellspacing = 0pt
 				frame = hsides
 				rules = groups}
 	style(header) = {font = ("times new roman",11pt) background = white just = center };
	title1 "ROC Results";
	column group auc p criteria oc1 sen_c1 spe_c1  ;
	define criteria /display 'Criteria'
 			style(column) = {cellwidth = 0.75in just = center}; 
	define group/group 'Variable'
 			style(column) = {cellwidth = 1.25in}; 
	define auc /group 'AUC (95% CI)'
 			style(column) = {cellwidth = 1.25in just = center}; 
    define p /display group 'P'
 			style(column) = {cellwidth = 0.75in j5ust = center};
	define OC1 /display 'OC'
 			style(column) = {cellwidth = 0.75in just = center}; 
	define sen_c1 /display 'Sen'
 			style(column) = {cellwidth = 0.75in just = center}; 
	define spe_c1 /display 'Spe'
 			style(column) = {cellwidth = 0.75in just = center}; 

	compute before group;
		line ' ';
	endcomp; 
	compute after _page_ / style={just=left bordertopcolor=black bordertopwidth=2};
		line 'AUC = Area Under Curve. OC=Optimum Cutoff. Sen = sensitivity. Spe = specificity. Cutoff values are shown that maximize the sum of sensitivity and specificity (Criterion 1), and a weighted sum of sensitivity and specificity that weighted sensitivity 50% more heavily (Criterion 2).'
;
 endcomp; 
run;
%if &plot=1 %then 
	%do;
		proc sgplot data=&output_roc aspect=1;
			where _SOURCE_ ne "ROC1" ;
			format group &format;
			title " ";
			xaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
			yaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
			series x=_1mspec_ y=_sensit_ /group=group;
			keylegend / location=outside position=right title="";
			lineparm x=0 y=0 slope=1/transparancy=.7;
		run;
		ods rtf close;
	%end;
%else
	%do;
		ods rtf close;
	%end;
%mend;
