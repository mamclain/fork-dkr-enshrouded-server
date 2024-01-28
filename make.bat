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


@REM Load a .env file into the current environment
call :LoadEnvFile .env

@REM Check if the environmental variables exist, if not set them to the default values
call :CheckOrSetEnvVar REGISTRY "localhost"
call :CheckOrSetEnvVar PROJECT "sknnr"
call :CheckOrSetEnvVar IMAGE "enshrouded-server-testing"

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
) else (
    echo Building the project...
    docker build --progress=plain -f ./container/Containerfile -t %IMAGE_REF% ./container/
)
goto :eof



@REM set the docker image path
:SetImagePath
IF "%REGISTRY%"=="" (
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
        set %%a=%%b
    )
) ELSE (
    echo "%~1 file does not exist."
)
goto :eof

@REM Check if the environmental variables exist, if not set them to the default values
:CheckOrSetEnvVar
IF "!%~1!"=="" (
    echo Environmental %~1 exists with value: !%~1%!
) ELSE IF NOT DEFINED %~1 (
    echo Environmental %~1 does not exist, setting it as local now of: %~2
    set %~1=%~2
) ELSE (
    echo Environmental %~1 exists with value: !%~1%!
)
goto :eof

endlocal