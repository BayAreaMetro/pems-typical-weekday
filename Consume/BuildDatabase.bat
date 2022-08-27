set path=C:\Program Files\R\R-3.5.1\bin\x64;%path%

:: Build annual databases
FOR %%A IN (2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022) DO Rscript Build_Annual_Database.R %%A

:: Combine into a single database
call Rscript Build_Database.R

