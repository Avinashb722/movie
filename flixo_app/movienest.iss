[Setup]
AppName=MovieNest
AppVersion=1.1.0
DefaultDirName={localappdata}\MovieNest
DefaultGroupName=MovieNest
UninstallDisplayIcon={app}\movienest.exe
Compression=lzma2
SolidCompression=yes
OutputDir=web\downloads
OutputBaseFilename=movienest-setup
SetupIconFile=web\favicon.ico
DisableProgramGroupPage=yes
DisableDirPage=yes
CloseApplications=no

[Files]
Source: "build\windows\x64\runner\movienest-windows\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{userdesktop}\MovieNest"; Filename: "{app}\movienest.exe"; WorkingDir: "{app}"
Name: "{group}\MovieNest"; Filename: "{app}\movienest.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\movienest.exe"; Description: "Launch MovieNest"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Silently terminate movienest.exe if it is currently running in the background
  Exec('taskkill', '/f /im movienest.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;


