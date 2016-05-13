SET TEMPDIR="..\jekyll_output"

REM Build pages
rd /s/q %TEMPDIR%
call jekyll build -d %TEMPDIR%

REM Update site with built pages
git checkout master
robocopy %TEMPDIR% . /MIR /FFT /Z /XA:H /W:5 /xd ".git"
rd /s/q %TEMPDIR%

REM Commit updates
git add --all
git commit -m "Publish"

REM Return to original branch
git checkout site
