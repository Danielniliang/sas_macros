/*Create a macro to change the datatype of multiple varaibles from character to numeric in the same tim */
%macro char_to_num (dt=, vars=);
	%let n=%sysfunc(countw(&vars));
	%do i=1 %to &n;
		%let var = %scan(&vars,&i);
		data &dt;
		set &dt;
		var=input(&var, 8.);
		drop &var;
		rename var=&var;
		run;
	%end;
%mend;