@echo off
cd /d "%~dp0"

set GODOT_EXE=C:\Users\gabri\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT_EXE%" (
  echo Godot nao encontrado em:
  echo   %GODOT_EXE%
  echo Se voce moveu o Godot de lugar, edite o caminho no topo deste arquivo
  echo ^(gorot_executavel.bat^, clique direito -^> Editar^).
  pause
  exit /b 1
)

"%GODOT_EXE%" --path "%~dp0."
