; This file produces an installer for the Windows Service in the service/
; directory in this repository. Importantly, the installer contains the logic
; for updating the Service gracefully by first stopping the old version.
; The installer also supports silent installation via the `/S` flag, which is
; important for compatibility with Google Omaha.

; This file was developed with NSIS 3.06.1. It requires the NSIS Simple Service
; plugin from https://nsis.sourceforge.io/NSIS_Simple_Service_Plugin. This
; plugin does not yet offer a Unicode version (and likely never will). For this
; reason, you need to copy its SimpleSC.dll file into NSIS\Plugins\x86-ansi.

; You can use this file to create an Omaha-compatible installer for your own
; Windows Service. In the simplest case, it will be enough to change the
; constants below. If installing / updating / uninstalling your Service needs
; more complex logic than the bare minimum and extracting some files, you will
; need to extend the code below. Fortunately, NSIS makes most common tasks easy.

; As you can see in .onInit below, the installer first checks in the registry
; whether a previous version is already installed. If yes, it prompts the user
; whether they want to override the existing version. In silent mode
; (command-line flag /S), this consent is always assumed. Then, the installer
; either performs a clean install (function PerformInitialInstall) or an update
; (function UpdateExistingInstallation).

; All steps of the installer are carefully designed to be resilient to failures.
; As you can see in the functions that were just mentioned, each step comes with
; a "rollback" function that cleans up the system in case of an error. For
; example, if the installer fails to create the uninstaller, then it cleans it
; up in function RollbackUninstaller.

!define SERVICE_NAME "OmahaDemoService"
!define SERVICE_VERSION "0.0.0.2"
!define SERVICE_DISPLAY_NAME "Omaha Demo Service"
!define SERVICE_EXECUTABLE "OmahaDemoService.exe"
; Note: This constant can end in \* to include all files in a directory.
!define SERVICE_FILES "..\service\bin\Release\OmahaDemoService.exe"
!define SERVICE_START_TIMEOUT 30
!define SERVICE_STOP_TIMEOUT 30

!define OMAHA_REG_KEY "Software\OmahaTutorial\Update"
!define OMAHA_APP_ID "{C48667BA-C57A-4DFE-B219-6DB6C466E2CA}"
!define UNINSTALL_REG_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${SERVICE_DISPLAY_NAME}"

!include LogicLib.nsh
!include "MUI.nsh"
!include Try.nsh

OutFile "install-${SERVICE_VERSION}.exe"
InstallDir "$PROGRAMFILES\${SERVICE_DISPLAY_NAME}"
InstallDirRegKey HKLM "${UNINSTALL_REG_KEY}" InstallLocation
Name "${SERVICE_DISPLAY_NAME}"
RequestExecutionLevel admin

Var PrevVersion
Var PrevVersionUninstallCmdLine
Var ThisVersionUninstallCmdLine

!define MUI_WELCOMEPAGE_TITLE "Welcome!"
!define MUI_WELCOMEPAGE_TEXT "This wizard installs ${SERVICE_DISPLAY_NAME} ${SERVICE_VERSION}.\r\n\r\nThe Service will appear in:\r\n\r\n1) Its log file C:\OmahaDemoService.log,\r\n2) Services.msc,\r\n3) Add/Remove Programs.\r\n\r\nClick Install to get started."
!insertmacro MUI_PAGE_WELCOME

!define MUI_FINISHPAGE_NOAUTOCLOSE
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN "notepad.exe"
!define MUI_FINISHPAGE_RUN_PARAMETERS "C:\OmahaDemoService.log"
!define MUI_FINISHPAGE_RUN_TEXT "Show the Service's log file"
!insertmacro MUI_PAGE_FINISH

!define MUI_WELCOMEPAGE_TITLE "Uninstall ${SERVICE_DISPLAY_NAME}"
!define MUI_WELCOMEPAGE_TEXT "This will remove all remnants of ${SERVICE_DISPLAY_NAME} from your system.\r\n\r\nClick Uninstall to start the uninstallation."
!insertmacro MUI_UNPAGE_WELCOME

!define MUI_UNFINISHPAGE_NOAUTOCLOSE
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Function .onInit
    ReadRegStr $PrevVersion HKLM "${UNINSTALL_REG_KEY}" "DisplayVersion"
    ReadRegStr $PrevVersionUninstallCmdLine HKLM "${UNINSTALL_REG_KEY}" "QuietUninstallString"
    ${IfNot} ${Errors}
        ${If} $PrevVersion == ""
            StrCpy $0 "It seems ${SERVICE_DISPLAY_NAME} is already installed. Do you want to re-install version ${SERVICE_VERSION}?"
        ${ElseIf} $PrevVersion == ${SERVICE_VERSION}
            StrCpy $0 "It seems ${SERVICE_DISPLAY_NAME} $PrevVersion is already installed. Do you want to re-install it?"
        ${Else}
            StrCpy $0 "It seems ${SERVICE_DISPLAY_NAME} is already installed at version $PrevVersion. Do you want to update to ${SERVICE_VERSION}?"
        ${EndIf}
        ${If} ${Cmd} `MessageBox MB_YESNO|MB_ICONQUESTION "$0" /SD IDYES IDNO`
            Abort
        ${EndIf}
    ${EndIf}
    SetOutPath "$INSTDIR\${SERVICE_VERSION}"
FunctionEnd

Section
    ${If} $PrevVersion == ""
        DetailPrint "Performing a fresh installation."
        Call PerformInitialInstall
    ${ElseIf} $PrevVersion == ${SERVICE_VERSION}
        DetailPrint "Reinstalling version ${SERVICE_VERSION}."
        Call UninstallOldVersion
        Call PerformInitialInstall
    ${Else}
        DetailPrint "Updating from version $PrevVersion to ${SERVICE_VERSION}."
        Call UpdateExistingInstallation
    ${EndIf}
SectionEnd

Function PerformInitialInstall
    ${Try} CreateUninstaller
      ${Try} SetUninstallRegistryKeys
        ${Try} ExtractFiles
          ${Try} InstallService
            ${Try} StartService
              ${Try} SetOmahaRegistryKeys
              ${OnError} DeleteOmahaRegistryKeys
            ${OnError} StopService
          ${OnError} RemoveService
        ${OnError} DeleteExtractedFiles
      ${OnError} DeleteUninstallRegistryKeys
    ${OnError} RollbackUninstaller
    ${AbortIfErrors}
FunctionEnd

Function UpdateExistingInstallation
    ${Try} CreateUninstaller
      ${Try} ExtractFiles
        ${Try} StopService
          ${Try} UpdateServicePath
            ${Try} StartService
              ${Try} SetUninstallRegistryKeys
                ${Try} SetOmahaRegistryKeys
                  Call DeleteOldVersion
                ${OnError} RevertOmahaRegistryKeys
              ${OnError} RevertUninstallRegistryKeys
            ${OnError} StopService
          ${OnError} RestoreServicePath
        ${OnError} StartService
      ${OnError} DeleteExtractedFiles
    ${OnError} RollbackUninstaller
    ${AbortIfErrors}
FunctionEnd

Function CreateUninstaller
    WriteUninstaller "$OUTDIR\uninstall.exe"
    StrCpy $ThisVersionUninstallCmdLine '"$OUTDIR\uninstall.exe" /S _?=$INSTDIR'
    ${If} ${Errors}
        Push "Could not create uninstaller."
        SetErrors
    ${EndIf}
FunctionEnd

Function RollbackUninstaller
    Delete "$OUTDIR\uninstall.exe"
    RMDir "$OUTDIR"
FunctionEnd

Function SetUninstallRegistryKeys
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "DisplayName" "${SERVICE_DISPLAY_NAME}"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "DisplayVersion" "${SERVICE_VERSION}"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "UninstallString" "$INSTDIR\${SERVICE_VERSION}\uninstall.exe"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "QuietUninstallString" $ThisVersionUninstallCmdLine
    ${If} ${Errors}
        Push "Could not set registry keys."
        SetErrors
    ${EndIf}
FunctionEnd

Function RevertUninstallRegistryKeys
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "DisplayVersion" "$PrevVersion"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "UninstallString" "$INSTDIR\$PrevVersion\uninstall.exe"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "QuietUninstallString" $PrevVersionUninstallCmdLine
    ${If} ${Errors}
        Push "Could not set registry keys."
        SetErrors
    ${EndIf}
FunctionEnd

Function DeleteUninstallRegistryKeys
    DeleteRegKey HKLM "${UNINSTALL_REG_KEY}"
FunctionEnd

Function SetOmahaRegistryKeys
    WriteRegStr HKLM "${OMAHA_REG_KEY}\Clients\${OMAHA_APP_ID}" "name" "${SERVICE_DISPLAY_NAME}"
    WriteRegStr HKLM "${OMAHA_REG_KEY}\Clients\${OMAHA_APP_ID}" "pv" "${SERVICE_VERSION}"
    ${If} ${Errors}
        Push "Could not set registry keys."
        SetErrors
    ${EndIf}
FunctionEnd

Function RevertOmahaRegistryKeys
    WriteRegStr HKLM "${OMAHA_REG_KEY}\Clients\${OMAHA_APP_ID}" "pv" "$PrevVersion"
    ${If} ${Errors}
        Push "Could not set registry keys."
        SetErrors
    ${EndIf}
FunctionEnd

Function DeleteOmahaRegistryKeys
    DeleteRegKey HKLM "${OMAHA_REG_KEY}\Clients\${OMAHA_APP_ID}"
    DeleteRegKey /ifempty HKLM "${OMAHA_REG_KEY}\Clients"
    DeleteRegKey /ifempty HKLM "${OMAHA_REG_KEY}"
FunctionEnd

Function ExtractFiles
    File /r "${SERVICE_FILES}"
    ${If} ${Errors}
        Push "Could not extract files."
        SetErrors
    ${EndIf}
FunctionEnd

Function DeleteExtractedFiles
    Delete "$OUTDIR\*"
FunctionEnd

!macro CheckSCError Message
    Pop $0
    ${If} $0 <> 0
        Push $0
        SimpleSC::GetErrorMessage
        Pop $0
        Push "${Message}: $0"
        SetErrors
    ${EndIf}
!macroend

Function InstallService
    DetailPrint "Installing ${SERVICE_DISPLAY_NAME} ${SERVICE_VERSION}."
    SimpleSC::InstallService "${SERVICE_NAME}" "${SERVICE_DISPLAY_NAME}" "16" "2" "$INSTDIR\${SERVICE_VERSION}\${SERVICE_EXECUTABLE}" "" "" ""
    !insertmacro CheckSCError "Could not install ${SERVICE_DISPLAY_NAME}"
FunctionEnd

Function RemoveService
    SimpleSC::RemoveService "${SERVICE_NAME}"
    Pop $0
FunctionEnd

Function StartService
    DetailPrint "Starting ${SERVICE_DISPLAY_NAME}."
    SimpleSC::StartService "${SERVICE_NAME}" "" ${SERVICE_START_TIMEOUT}
    !insertmacro CheckSCError "Could not start ${SERVICE_DISPLAY_NAME}"
FunctionEnd

Function AbortInstallation
    Pop $0
    MessageBox MB_OK|MB_ICONSTOP "$0"
    ExecWait $ThisVersionUninstallCmdLine
    Delete "$INSTDIR\${SERVICE_VERSION}\uninstall.exe"
    DetailPrint "$0."
    Abort "Installation failed."
FunctionEnd

Function StopService
    DetailPrint "Stopping ${SERVICE_DISPLAY_NAME}."
    SimpleSC::StopService "${SERVICE_NAME}" 1 ${SERVICE_STOP_TIMEOUT}
    Pop $0
    ${If} 0 <> 1062 ; Service was not running
        Push $0
        !insertmacro CheckSCError "Could not stop ${SERVICE_DISPLAY_NAME}"
    ${EndIf}
FunctionEnd

Function UpdateServicePath
    Push "${SERVICE_VERSION}"
    Call SetServicePath
FunctionEnd

Function RestoreServicePath
    Push "$PrevVersion"
    Call SetServicePath
FunctionEnd

Function SetServicePath
    Pop $0
    DetailPrint "Updating binary path of ${SERVICE_DISPLAY_NAME}."
    SimpleSC::SetServiceBinaryPath "${SERVICE_NAME}" "$INSTDIR\$0\${SERVICE_EXECUTABLE}"
    !insertmacro CheckSCError "Could not update path of ${SERVICE_DISPLAY_NAME}"
FunctionEnd

Function UninstallOldVersion
    ExecWait $PrevVersionUninstallCmdLine
    ${If} ${Errors}
        Push "Could not remove ${SERVICE_DISPLAY_NAME} $PrevVersion."
        Call AbortInstallation
    ${EndIf}
FunctionEnd

Function DeleteOldVersion
    RMDIR /r "$INSTDIR\$PrevVersion"
FunctionEnd

Section "uninstall"
    DetailPrint "Stopping ${SERVICE_DISPLAY_NAME}."
    Call un.StopService
    Pop $0
    DetailPrint "Removing ${SERVICE_DISPLAY_NAME}."
    Call un.RemoveService
    Pop $0
    ; Note that $INSTDIR here is not the same as $INSTDIR above. In the
    ; uninstaller, NSIS sets $INSTDIR to the directory containing uninstall.exe.
    DetailPrint "Removing $INSTDIR."
    RMDIR /r "$INSTDIR"
    DetailPrint "Removing $INSTDIR\.."
    RMDIR "$INSTDIR\.."
    Call un.DeleteOmahaRegistryKeys
    Call un.DeleteUninstallRegistryKeys
SectionEnd

Function un.DeleteUninstallRegistryKeys
    DeleteRegKey HKLM "${UNINSTALL_REG_KEY}"
FunctionEnd

Function un.DeleteOmahaRegistryKeys
    DeleteRegKey HKLM "${OMAHA_REG_KEY}\Clients\${OMAHA_APP_ID}"
    DeleteRegKey /ifempty HKLM "${OMAHA_REG_KEY}\Clients"
    DeleteRegKey /ifempty HKLM "${OMAHA_REG_KEY}"
FunctionEnd

Function un.StopService
    SimpleSC::StopService "${SERVICE_NAME}" 1 ${SERVICE_STOP_TIMEOUT}
FunctionEnd

Function un.RemoveService
    SimpleSC::RemoveService "${SERVICE_NAME}"
FunctionEnd