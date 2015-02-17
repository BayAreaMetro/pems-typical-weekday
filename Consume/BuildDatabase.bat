set path=c:\program files\R\R-3.1.2\bin\x64;%path%

:: Build annual databases
FOR %%A IN (2005 2006 2007 2008 2009 2010 2011 2012 2013 2014) DO Rscript Build_Annual_Database.R %%A

:: Combine into a single database
call Rscript Build_Database.R

