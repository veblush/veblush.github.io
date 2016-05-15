@Echo off

SET SRCDIR=".\veblush.github.io"
SET TEMPDIR="..\veblush.github.io_output"

Echo Go into srcdir
pushd %~dp0
CD %SRCDIR%

Echo Build pages
rd /s/q %TEMPDIR%
call jekyll build -d %TEMPDIR%
IF ERRORLEVEL 1 GOTO ERR 

Echo Update site with built pages
git checkout master
IF ERRORLEVEL 1 GOTO ERR 
robocopy %TEMPDIR% . /MIR /FFT /Z /XA:H /W:5 /xd ".git"
IF ERRORLEVEL 8 GOTO ERR 
rd /s/q %TEMPDIR%

Echo Commit updates
git add --all
git commit -m "Publish"

Echo Return to original branch
git checkout site
IF ERRORLEVEL 1 GOTO ERR

popd

echo done
GOTO END

:ERR

echo !ERROR!

:END
