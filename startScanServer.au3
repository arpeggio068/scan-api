#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icons\bot1.ico
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIMisc.au3>
#Include <WinAPI.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
Opt("WinTitleMatchMode", 2)
Global $sHookTitle = "ScanWedgeClient" ;
Global $sApiTitle = "Pharm Q Server"

Func ShowStartupPopup()
    Local $sTitle = "Start hook server"
    Local $sText = "Starting ScanWedgeClient hook server..." & @CRLF & @CRLF & "Please wait 3 seconds"
    SplashTextOn($sTitle, $sText, 400, 120)
    Sleep(3000)
    SplashOff()
EndFunc

; -------------------------
; -------------------------
Func StartHookConsole()
    Local $aList = WinList($sHookTitle)
    Local $aList_Length = $aList[0][0]

    If $aList_Length > 0 Then
        For $i = 1 To $aList_Length
            Local $sTitle = $aList[$i][0]
            Local $hHandle = $aList[$i][1]

            If $sTitle <> "" And BitAND(WinGetState($hHandle), 2) Then
                ConsoleWrite("[Info] Found existing window: " & $sTitle & @CRLF)
				WinSetState($sTitle, "", @SW_MINIMIZE)
                Sleep(200)
                Return
            EndIf
        Next
    EndIf

    Local $sExe = @ScriptDir & '\bots\ScanWedgeClient.exe'
    Local $sWorkDir = @ScriptDir & '\bots'

    If Not FileExists($sExe) Then
        ConsoleWrite("[Error] File not found: " & $sExe & @CRLF)
        MsgBox($MB_ICONERROR, "Error", "Cannot find: " & $sExe & @CRLF & "Please check path.")
        Return
    EndIf

    Local $iPID = Run('"' & $sExe & '"', $sWorkDir, @SW_SHOWNORMAL)
    If $iPID = 0 Then
        ConsoleWrite("[Error] Failed to start: " & $sExe & @CRLF)
    Else
        ConsoleWrite("[Info] Started ScanWedgeClient.exe, PID=" & $iPID & @CRLF)
    EndIf

	Local $hHook = WinWait($sHookTitle, "", 5)
	if $hHook Then WinSetState($hHook, "", @SW_MINIMIZE)
EndFunc

Func StartNodeApi()
	Local $aList = WinList($sApiTitle) ;Winlist all hos os
	;_ArrayDisplay($aList)
	Local $aList_Length = $aList[0][0]
	If $aList_Length > 0 Then
				For $i = 1 To $aList_Length
					Local $sTitle = $aList[$i][0]
					Local $hHandle = $aList[$i][1]
						If $sTitle <> "" And BitAND(WinGetState($hHandle), 2) Then
							WinSetState($sTitle, "", @SW_MINIMIZE)
							Sleep(200)
							ExitLoop
						EndIf
				Next
	Else
	   Local $CMD =  'cd '&@ScriptDir&' && ' & _
        'npm start'
	   Run('"' & @ComSpec & '" /k ' & $CMD)
	   Sleep(100)
	   Local $hHook = WinWait($sApiTitle, "", 5)
	   if $hHook Then WinSetState($sApiTitle, "", @SW_MINIMIZE)
	EndIf
EndFunc

Func StopServer()
	Local $aList = WinList($sApiTitle) ;Winlist all hos os
	;_ArrayDisplay($aList)
	Local $aList_Length = $aList[0][0]
	 If $aList_Length > 0 Then
				For $i = 1 To $aList_Length
					Local $sTitle = $aList[$i][0]
					Local $hHandle = $aList[$i][1]
						If $sTitle <> "" And BitAND(WinGetState($hHandle), 2) Then
							WinKill($sTitle)
							Sleep(200)
							ExitLoop
						EndIf
				Next
	EndIf
    Run(@ComSpec & ' /c taskkill /IM node.exe /F', "", @SW_HIDE)
    ConsoleWrite("Node.js server stopped by taskkill" & @CRLF)
    Sleep(50)
	Local $aList2 = WinList($sHookTitle)
	;_ArrayDisplay($aList)
	Local $aList2_Length = $aList2[0][0]
	 If $aList2_Length > 0 Then
				For $i = 1 To $aList2_Length
					Local $sTitle = $aList2[$i][0]
					Local $hHandle = $aList2[$i][1]
						If $sTitle <> "" And BitAND(WinGetState($hHandle), 2) Then
							WinKill($sTitle)
							Sleep(200)
							ExitLoop
						EndIf
				Next
	EndIf
EndFunc

Func MsgStopServer()
	Local $iAnswer = MsgBox($MB_OKCANCEL + $MB_ICONQUESTION, _
    "Confirm", "Are you sure to stop scan server?")
	If $iAnswer = $IDOK Then
		StopServer()
	Else
		MsgBox($MB_ICONWARNING, "Cancel", "Please stop scan server by yourself")
		StartHookConsole()
	    Sleep(100)
	    StartNodeApi()
	EndIf
EndFunc

; -------------------------
; MAIN ฟังก์ชันเริ่ม
; -------------------------
Local $hHook = WinGetHandle($sHookTitle)
Local $hAPI = WinGetHandle($sApiTitle)

If $hHook Or $hAPI Then
	MsgStopServer()
Else
	MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, "Start scan server", "Starting ScanWedgeClient server...", 3)
	;ShowStartupPopup()
	StartHookConsole()
	Sleep(200)
	StartNodeApi()
EndIf
Exit 0

