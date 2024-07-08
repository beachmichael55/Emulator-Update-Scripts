@echo off
setlocal EnableDelayedExpansion

:SetVariables
::Sets the original directory to a variable to use later
set "OriginalDir=%~dp0"
::Sets the name of what the script is for
set "ScriptName=Vita3K"
:: Tests write permissions for script directory
echo Success.> "%OriginalDir%%ScriptName%_Permissions_Test.txt"
	if exist "%OriginalDir%%ScriptName%_Permissions_Test.txt" (
		del /f /q "%OriginalDir%%ScriptName%_Permissions_Test.txt" >nul 2>&1
	) else (
	echo Error. Does not have Write Permissions to script folder.
		echo Please fix folder permissions before next run.
		echo Will now exit script.
		pause
		goto :EXIT
)
::Sets the current time variable in Julian Day of Year format [1-365]. The variable name is JDN.
for /F "tokens=2-4 delims=/ " %%a in ("%date%") do (
	  set /A "MM=1%%a-100, DD=1%%b-100, Y=%%c, Ymod4=%%c%%4, Ymod100=%%c%%100, Ymod400=%%c%%400"
)
for /F "tokens=%MM%" %%m in ("0 31 59 90 120 151 181 212 243 273 304 334") do set /A JDN=DD+%%m
if %Ymod4% equ 0 (
	if %Ymod100% neq 0 (
		set /A Day+=1
	) else (
		if %Ymod400% equ 0 set /A Day+=1
	)
)
::Sets future Julian time variables
set /a "one_weeks=JDN + 7"
set /a "two_weeks=JDN + 14"
set /a "one_month=JDN + 30"
set /a "three_months=JDN + 90"
set /a "never_check=JDN + 1000"
::Sets time check file variables
set "TimeDir=%OriginalDir%DelayTime"
set "WeekCheckFile=%TimeDir%\%ScriptName%_Time_Week_Check.txt"
set "TwoWeekCheckFile=%TimeDir%\%ScriptName%_Time_Week2_Check.txt"
set "MonthCheckFile=%TimeDir%\%ScriptName%_Time_Month_Check.txt"
set "ThreeMonthCheckFile=%TimeDir%\%ScriptName%_Time_Month3_Check.txt"
set "NeverCheckFile=%TimeDir%\%ScriptName%_Time_Never_Check.txt"
::Makes the time check files if they don't exist.
if not exist "%TimeDir%" (
	mkdir "DelayTime" > nul 2>&1
	)
if not exist "%WeekCheckFile%" (
    echo 0 > "%WeekCheckFile%"
)
if not exist "%TwoWeekCheckFile%" (
    echo 0 > "%TwoWeekCheckFile%"
)
if not exist "%MonthCheckFile%" (
    echo 0 > "%MonthCheckFile%"
)
if not exist "%ThreeMonthCheckFile%" (
    echo 0 > "%ThreeMonthCheckFile%"
)
if not exist "%NeverCheckFile%" (
    echo 0 > "%NeverCheckFile%"
)
::Reads from time check files and sets the variables.
set /p WeekCheck=<"%WeekCheckFile%"
set /p TwoWeekCheck=<"%TwoWeekCheckFile%"
set /p MonthCheck=<"%MonthCheckFile%"
set /p ThreeMonthCheck=<"%ThreeMonthCheckFile%"
set /p NeverCheck=<"%NeverCheckFile%"
::: Set path variables
set "WorkingTxtDir=%OriginalDir%WorkingDirectories"
set "WorkingTxt=%WorkingTxtDir%\%ScriptName%_working_directory.txt"
::Sets default install variable
set "WorkDir="
:: Set download path variables, repository URL, etc
set dlfile=%temp%\%ScriptName%.zip
set "lastverpath=%OriginalDir%Versions\%ScriptName%_VERSION.txt"
set repo=Vita3K/Vita3K
set link=https://api.github.com/repos/%repo%/releases/latest
set DownloadErrorFile=%temp%\%ScriptName%_download_log.txt
:: If first install (or no VERSION file) set current version to null
set oldver=""
if exist %lastverpath% (set /p oldver=<%lastverpath%)
::Sets default 7zip variable state
set Seven_Zip=
set WinRar=

:MakeFolders
::Makes the directories if needed
if not exist "%WorkingTxtDir%" (
	mkdir "WorkingDirectories" > nul 2>&1
	)
if not exist "%OriginalDir%Versions" (
	mkdir "Versions" > nul 2>&1
	)

:CheckWorkDir
:: Check if the working directory file exists.
if exist "%WorkingTxt%" (
    :: Read the working directory from the file.
    set /P "WorkDir="<"%WorkingTxt%"
	:: Sets the working directory permission test file variable.
	set "WorkingDirTestFile=!WorkDir!\Permissions_Test.txt"
	:: Tests if write permissions for working directory are valid.
	echo Success.> "!WorkingDirTestFile!"
	if exist "!WorkingDirTestFile!" (
		:: Change the working directory.
		cd /D "!WorkDir!"
		:: Deletes write permission test file.
		del /f /q !WorkingDirTestFile! >nul 2>&1
		goto :ArchiveTest
	) else (
		echo Error. Does not have Write Permissions to install folder.
		echo Please fix folder permissions before next run.
		echo Will now exit script.
		pause
		goto :EXIT
	)
    
) else (
    :: If the file doesn't exist, prompt the user to set the working directory.
    goto :SetWorkDir
)

:SetWorkDir
:: Request input from the user to change working directory.
cls
echo.
echo When entering the Install/Extract location, you can Copy/Paste the path
echo from File Explorer. Whichever is easier to get the Full path.
echo.
choice /C YN /N /M "Do you want or need to change were it will Install/Extract? [Y/N]: "
if errorlevel 2 goto :TestWorkDir
set /P "WorkDir=Please enter were you want to Install/Extract to, and then press ENTER: "
:: Add quotes around the input path to handle spaces.
set "WorkDir=%WorkDir:"=%"
:: Check if the input is a valid directory.
if not exist "%WorkDir%" (
    echo Invalid directory.
    pause
    goto :SetWorkDir
)
:: Save the working directory to a text file.
echo %WorkDir%> "%WorkingTxt%"
:: Change the working directory immediately after saving it to the file.
cd /D "%WorkDir%"

:TestWorkDir
::Checks if the "working directory" was set
if not defined WorkDir (
	echo ######################################################################################
    echo ##### Error, No Working Directory Set. Set a "Working Directory/Install" Location! ###
	echo ######################################################################################
    pause
    goto :SetWorkDir
	)

:ArchiveTest
where 7z > nul 2>&1
if %errorlevel% equ 1 (
	::If not found in Environment Variables, tries to find the 7z.exe location and if found, sets Seven_Zip variable.
	::For 32-bit version check
    if exist "%ProgramFiles(x86)%\7-zip\7z.exe" (
        set Seven_Zip="%ProgramFiles(x86)%\7-zip\7z.exe"
	)
	::For 64-bit version check
	if exist "%ProgramFiles%\7-zip\7z.exe" (
        set Seven_Zip="%ProgramFiles%\7-zip\7z.exe"
	) else (
	:: If 7z is not found in the default locations, will ask for it. Then run check for location EXE, then set it's location.
		set /p SevenZipDir="Enter path to 7zip (e.g., C:\Program Files\7-zip\): "
		if exist "!SevenZipDir!\7z.exe" (
			set Seven_Zip="!SevenZipDir!\7z.exe"
		)
    )
	
)
where 7z > nul 2>&1
if %errorlevel% equ 1 (
	if defined Seven_Zip (
		goto :PythonTest
	) else (
	:: Check for WinRar
	::For 32-bit version check
	if exist "%ProgramFiles(x86)%\WinRAR\WinRAR.exe" (
		set WinRAR="%ProgramFiles(x86)%\WinRAR\WinRAR.exe"
	)
	::For 64-bit version check
	if exist "%ProgramFiles%\WinRAR\WinRAR.exe" (
		set WinRAR="%ProgramFiles%\WinRAR\WinRAR.exe"
	) else (
	:: If WinRar is not found in the default locations, will ask for it. Then run check for location EXE, then set it's location.
		set /p WinRARDir="Enter path to WinRAR (e.g., C:\Program Files\WinRAR\): "
		if exist "!WinRARDir!\WinRAR.exe" (
			set WinRAR="!WinRARDir!\WinRAR.exe"
			)
		)
	)
)

:PythonTest
::Only needed if want controller support
::Tries to find Python in Environment Variables. If not found, sets python no found variable.
where python > nul 2>&1
if %errorlevel% equ 1 (
	set NOPythonFile=
)

:CheckIfDelay
::checks if from time check variables if they are toggled on=1, or off=0. Then checks if it has been how long that time.
::For if it has been 1 week
if %WeekCheck% equ 1 (
		if %one_weeks% gtr %JDN% (
			rem It has not been one week yet.
			goto :EXIT
		) else (
			echo 0 > "%WeekCheckFile%"
			goto :InternetTest
		)
)
::For if it has been 2 week
if %TwoWeekCheck% equ 1 (
		if %two_weeks% gtr %JDN% (
			rem It has not been two weeks yet.
			goto :EXIT
		) else (
			echo 0 > "%TwoWeekCheckFile%"
			goto :InternetTest
		)
)
::For if it has been 1 month
if %MonthCheck% equ 1 (
		if %one_month% gtr %JDN% (
			rem It has not been one month yet.
			goto :EXIT
		) else (
			echo 0 > "%MonthCheckFile%"
			goto :InternetTest
		)
)
::For if it has been 3 month
if %ThreeMonthCheck% equ 1 (
		if %three_months% gtr %JDN% (
			rem It has not been three month yet.
			goto :EXIT
		) else (
			echo 0 > "%ThreeMonthCheckFile%"
			goto :InternetTest
		)
)
::For if it is set to never
if %NeverCheck% equ 1 (
		if %never_check% gtr %JDN% (
			rem It has not been never yet.
			goto :EXIT
		) else (
			echo 0 > "%NeverCheckFile%"
			goto :InternetTest
		)
)

:InternetTest
::Checks for an internet connection
set "ping_result="
ping -n 2 google.com >nul 2>nul && set "ping_result=success"
if defined ping_result (
    goto :CheckNewVersion
) else (
    goto :EXIT
)

:CheckNewVersion	
:: Get latest version
:: for /f "tokens=2 delims=, " %%a in ('curl -s %link% ^| findstr /l "created_at"') do (set ver=%%a)
for /f "delims=" %%g in ('powershell "((Invoke-RestMethod %link% -timeout 2).body.Split("\"`n"\") | Select-String -Pattern 'Vita3K Build:') -replace  'Vita3K Build: '"') do @set ver=%%g

:: Simple check for API access
:: Will trigger if API rate limit exceeded or if user has no internet connection
if not defined ver (
    echo Error getting GitHub API
    timeout /t 2 >nul 2>&1
    goto :EXIT
)

:CheckIfNew
rem Checks if new one is available
if %ver% GTR %oldver% (
	GOTO MENU
	)
echo No New Version found.
timeout /t 1 >nul 2>&1
goto :EXIT

:MENU
:: Checks if Python is installed
cls
echo.
echo Install Folder:"%WorkDir%"
echo.
if defined NOPythonFile (
    echo Python is not installed. Only for controller support.
) else (
	echo Python installed. Controller supported.
	:: Starts a python script that enables controller input support for Menu.
	start /min python "%OriginalDir%zController_Input.py" >nul 2>&1
)
timeout /t 1 >nul 2>&1
echo.
echo New Version Found
if not %oldver% == "" (
echo Current version: %oldver%
)
echo Latest version:  %ver%
echo.
echo 1 or A     - Download
echo 2 or B     - Remaind Me in a Week 
echo 3 or Y     - Remaind Me in 2 Weeks
echo 4 or X     - Remaind Me in 1 Month
echo 5 or D-P U - Remaind Me in 3 months
echo 6 or D-P R - Remaind Me in 1 year
echo 7 or D-P D - exit
choice /C 1234567 /N /M "Do you want to update?: "
set "M=%ERRORLEVEL%"
	IF %M%==1 goto :DOWNLOAD
	IF %M%==2 goto :SetWeek
	IF %M%==3 goto :SetTwoWeek
	IF %M%==4 goto :SetMonth
	IF %M%==5 goto :SetThreeMonth
	IF %M%==6 goto :SetNerver
	IF %M%==7 goto :EXIT

:DOWNLOAD
cls
:: Kills Python proccess from controller script
if not defined NOPythonFile (
	taskkill /F /IM python.exe >nul 2>&1
)
echo Downloading...
:: Download release
for /f "tokens=2 delims= " %%a in ('curl -s %link% ^| findstr /l "browser_download_url" ^| findstr /v /r "pdbs|uibase|src" ^| findstr /l "windows-latest.zip"') do (set dl=%%a)
if not exist %dlfile% (powershell -command "& {Invoke-WebRequest -Uri %dl% -OutFile %dlfile%}") >> %DownloadErrorFile% 2>&1
:: Runs a check if the download was successfull or not.
for %%F in ("%DownloadErrorFile%") do (
	:: If the DownloadErrorFile is greater then 0, then there was an error.
	if %%~zF GTR 0 (
		echo Download failed!
        echo Check URL, check if the file exists on the website.
		echo Will now exit script.
		:: Delete temporary files
		del /f /q %dlfile% >nul 2>&1
		del /f /q %DownloadErrorFile% >nul 2>&1
		pause
		goto :EXIT
    )
)
:: Extract downloaded .zip file to current folder using local archive installations.
where 7z > nul 2>&1
if %errorlevel% equ 0 (
	7z x %dlfile% -aoa -o%temparchive% >nul 2>&1
) else (
	if defined Seven_Zip (
		%Seven_Zip% x %dlfile% -aoa -o%temparchive% >nul 2>&1
	) if defined WinRAR (
		%WinRAR% x -y -o+ %dlfile% %temparchive% >nul 2>&1
	)
)
:: Delete temporary files
del /f /q %dlfile% >nul 2>&1
del /f /q %DownloadErrorFile% >nul 2>&1
:: Update VERSION file
echo %ver% > %lastverpath%
goto :EXIT

:SetWeek
echo 1 > "%WeekCheckFile%"
for %%i in (%TwoWeekCheckFile% %MonthCheckFile% %ThreeMonthCheckFile% %NeverCheckFile%) do (
	echo 0 > "%%i"
)
goto :EXIT
:SetTwoWeek
echo 1 > "%TwoWeekCheckFile%"
for %%i in (%WeekCheckFile% %MonthCheckFile% %ThreeMonthCheckFile% %NeverCheckFile%) do (
	echo 0 > "%%i"
)
goto :EXIT
:SetMonth
echo 1 > "%MonthCheckFile%"
for %%i in (%WeekCheckFile% %TwoWeekCheckFile% %ThreeMonthCheckFile% %NeverCheckFile%) do (
	echo 0 > "%%i"
)
goto :EXIT
:SetThreeMonth
echo 1 > "%ThreeMonthCheckFile%"
for %%i in (%WeekCheckFile% %TwoWeekCheckFile% %MonthCheckFile% %NeverCheckFile%) do (
	echo 0 > "%%i"
)
goto :EXIT
:SetNerver
echo 1 > "%NeverCheckFile%"
for %%i in (%WeekCheckFile% %TwoWeekCheckFile% %MonthCheckFile% %ThreeMonthCheckFile%) do (
	echo 0 > "%%i"
)
goto :EXIT

:EXIT
if not defined NOPythonFile (
	taskkill /F /IM python.exe >nul 2>&1
)
endlocal
exit
exit