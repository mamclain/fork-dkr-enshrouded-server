@echo off

@REM This script is used as a substitute for a Makefile for folks who are not familiar with Makefiles and/or dont
@REM have make installed.
@REM
@REM an attempt was made to mirror the original Makefile commands; however the assumption here is the user is
@REM working under windows via WLS2 or docker desktop and doesnt have Buildah/Podman installed.
@REM run functionality is currently limited (i might expand this later); however push functionality was added along with
@REM the ability to do a full rebuild of the container image via the "full" argument.
@REM
@REM to mirror .env support under linux a command was added to load a .env file into the current environment
@REM this is done via the :LoadEnvFile function, this is a bit of a hack but it works...
@REM
@REM currently you can set values in the env for REGISTRY, PROJECT, IMAGE, and TAG
@REM a env value of REGISTRY= will result in a docker hub image being built
@REM a env value of REGISTRY=registry.example.com will result in a private registry image being built
@REM if no values are found the defaults in this script will be used
@REM
@REM if a TAG env value is provided it will be used as the image tag
@REM if no TAG env value is provided the git commit hash will be used as the image tag and if git is not installed
@REM the image tag will be set to local

@REM use enabledelayedexpansion to allow for the use of ! in variables
setlocal enabledelayedexpansion

@REM check for docker (exit if not found)
call :CheckForDocker

@REM Load a .env file into the current environment
echo "Loading .env file..."
call :LoadEnvFile .env

@REM Check if the environmental variables exist, if not set them to the default values
echo "evaluating build env vars..."
call :CheckOrSetEnvVar REGISTRY "localhost"
call :CheckOrSetEnvVar PROJECT "sknnr"
call :CheckOrSetEnvVar IMAGE "enshrouded-server-testing"

echo "evaluating run env vars..."
@REM provide the user some configuration options for the container run
call :CheckOrSetEnvVar CONTAINER_NAME "enshrouded-test"
call :CheckOrSetEnvVar FILE_MOUNT "./temp:/home/steam/enshrouded/savegame"
call :CheckOrSetEnvVar SERVER_NAME "Enshrouded Containerized Server"
call :CheckOrSetEnvVar SERVER_SLOTS "16"
call :CheckOrSetEnvVar SERVER_PASSWORD "ChangeThisPlease"



@REM set the default run options...
set DEFAULT_RUN_OPTS=
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! --name '!CONTAINER_NAME!'
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! --rm
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! -it
@REM set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! -d
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! -v '!FILE_MOUNT!'
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! -p 15636:15636/udp
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! -p 15637:15637/udp
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! --env SERVER_NAME='!SERVER_NAME!'
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! --env SERVER_SLOTS=!SERVER_SLOTS!
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! --env SERVER_PASSWORD='!SERVER_PASSWORD!'
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! --env GAME_PORT=15636
set DEFAULT_RUN_OPTS=!DEFAULT_RUN_OPTS! --env QUERY_PORT=15637

@REM echo Default Run Options: !DEFAULT_RUN_OPTS!
@REM allow the user to override the default run options fully or partially
call :CheckOrSetEnvVar RUN_OPTS "!DEFAULT_RUN_OPTS!" replace

@REM echo Run Options: !RUN_OPTS!

@REM set the image tag based on the TAG environmental variable or the git commit hash otherwise
call :SetImageTag

@REM set the docker image path
call :SetImagePath

@REM check input args for action
if /i "%1%"=="full" (
    echo Building the project...
    docker build --progress=plain -f ./container/Containerfile --no-cache -t %IMAGE_REF%  ./container/
) else if /i "%1%"=="push" (
    echo Push the project...
    docker push %IMAGE_REF%
) else if /i "%1%"=="run" (
    echo Run the project...
    call :CheckForImage !IMAGE_REF!
    echo docker run !RUN_OPTS! !IMAGE_REF!
    docker run !RUN_OPTS! !IMAGE_REF!
) else (
    echo Building the project...
    docker build --progress=plain -f ./container/Containerfile -t %IMAGE_REF% ./container/
)
goto :eof



@REM set the docker image path
:SetImagePath
IF %REGISTRY%=="" (
    echo %PROJECT%/%IMAGE%:%TAG%
    @REM this is a docker hub image so drop the registry prefix
    set IMAGE_REF=%PROJECT%/%IMAGE%:%TAG%
    echo Docker Hub Image For IMAGE_REF: !IMAGE_REF!
) ELSE (
    @REM this is a private registry image so include the registry prefix
    set IMAGE_REF=%REGISTRY%/%PROJECT%/%IMAGE%:%TAG%
    echo Private Image for IMAGE_REF: !IMAGE_REF!
)
goto :eof

@REM Set the image tag based on the TAG environmental variable or the git commit hash otherwise
:SetImageTag
IF DEFINED TAG (
    set "HASH=%TAG%"
    echo TAG environmental variable found. Setting docker image tag to: %HASH%
) ELSE (
    where /q git
    IF ERRORLEVEL 1 (
        set TAG=local
        echo Git is not installed, setting docker image tag to: %TAG%
    ) ELSE (
        for /f "delims=" %%i in ('git rev-parse --short HEAD') do set "TAG=%%i"
        echo Git is installed, setting docker image tag to: %TAG%
    )
)
goto :eof

@REM Load a .env file into the current environment must use Var=Value format
:LoadEnvFile
IF EXIST %~1 (
    for /F "tokens=1* delims==" %%a in (%~1) do (
        echo %%a=%%b
        IF "%%b"=="" (
            set %%a=""
        ) ELSE (
            set %%a=%%b
        )
    )
) ELSE (
    echo "%~1 file does not exist."
)
goto :eof

@REM Check if the environmental variables exist, if not set them to the default values
:CheckOrSetEnvVar
echo Checking for environmental %~1
IF NOT DEFINED %~1 (
    echo Environmental %~1 does not exist, setting it as local now of: %~2
    set %~1=%~2
    IF "%~3"=="replace" (
        set "%~1=!%~1:'="!"
    )
) ELSE (
    echo Environmental %~1 exists with value: !%~1%!
)
goto :eof


:CheckForDocker
docker --version >nul 2>&1
if errorlevel 1 (
    echo Docker is not installed. Exiting.
    exit /b
) else (
    echo Docker is installed.
)
goto :eof

:CheckForImage
docker images %~1  | findstr /i "\!%~1!\>" >nul
if errorlevel 1 (
    echo Image does not exist. Exiting.
    exit /b
) else (
    echo Image exists.
)
goto :eof

endlocal