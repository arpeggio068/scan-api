#RequireAdmin
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#Include <WinAPI.au3>
#Include <SendMessage.au3>
#include <FileConstants.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
;#include <Excel.au3>
;#include "OpenCV-Match_UDF_Mod.au3"
;#include <CppKeySend.au3>

Opt("MouseCoordMode", 1)
Opt("WinTitleMatchMode", 2)
HotKeySet("{ESC}", "Hkey")

Global $gHTTPNode = ObjCreate("WinHttp.WinHttpRequest.5.1")
Global $sLogQueue = @ScriptDir &"\queue.txt"
Global $oLogQueue

Global $sHosXpTitle = "HOSxPMedicationOrderQueueGeneratorForm"
Global $sHookTitle = "ScanWedgeClient" ;
Global $sApiTitle = "Pharm Q Server"

Global $gPopupHandled = False   ; popup ถูกจัดการแล้วหรือไม่
Global $bRunningKillFinance = False

Func Hkey()
	FileClose($oLogQueue)
	MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, "Hkey", "Stop Process")
	Exit 0
EndFunc

Func FindPopup()
    Local $aList = WinList()
    For $i = 1 To $aList[0][0]
        Local $hWnd = $aList[$i][1]
        Local $sTitle = $aList[$i][0]
        Local $sClass = _WinAPI_GetClassName($hWnd)
        ; กรอง: ต้องเป็น HOSxP + Class #32770 (Dialog)
        If StringInStr($sTitle, $sHosXpTitle) And $sClass = "#32770" Then
            ConsoleWrite("Found Popup Handle: " & $hWnd & " Title: " & $sTitle & " Class: " & $sClass & @CRLF)
            Return $hWnd
        EndIf
    Next
    Return 0
EndFunc

Func PostToApi($str="/complete")
    Local $sUrl = "http://127.0.0.1:3076"&$str
    Local $sData = "{}" ; ส่ง JSON ว่าง ๆ ไป

    $gHTTPNode.Open("POST", $sUrl, False)
    $gHTTPNode.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
    $gHTTPNode.Send($sData)

    ConsoleWrite("bot response: " & $gHTTPNode.ResponseText & @CRLF)
    Return $gHTTPNode.ResponseText
EndFunc

Func KillFinance1()
    Local $bFoundFinance = False
    Local $aList = WinList()

    For $i = 1 To $aList[0][0]
        Local $hWnd = $aList[$i][1]
        If $hWnd <> 0 Then
            Local $sClass = _WinAPI_GetClassName($hWnd)
            If $sClass = "#32770" And StringInStr($aList[$i][0], "HOSxPMedicationOrderQueueGeneratorForm") Then
                ConsoleWrite("found popup: " & $hWnd & " -> WinClose/WinKill" & @CRLF)
                WinClose($hWnd)
                Sleep(500)
                If WinExists($hWnd) Then
                    WinKill($hWnd)
                    ConsoleWrite("WinKill popup" & @CRLF)
                EndIf
                $bFoundFinance = True
                ExitLoop
            EndIf
        EndIf
    Next

    If $bFoundFinance Then
        ; มีการปิด popup อย่างน้อย 1 ครั้ง
        MsgBox($MB_ICONWARNING + $MB_TOPMOST, "Patient Info", "Finance Locked.", 3)
        PostToApi("/financeLock")
        Return True
    Else
        Return False
    EndIf
EndFunc

Func HideHosXp()
	 Local $hEcel = WinGetHandle($sHosXpTitle)
	 ;Local $hEcel = WinGetHandle("[CLASS:XLMAIN]")
	if $hEcel Then WinSetState($hEcel, "", @SW_MINIMIZE)
EndFunc

Func HideCmd1()
	 Local $hEcel = WinGetHandle($sHookTitle)
	 ;Local $hEcel = WinGetHandle("[CLASS:XLMAIN]")
	if $hEcel Then WinSetState($hEcel, "", @SW_MINIMIZE)
EndFunc

Func HideCmd2()
	 Local $hEcel = WinGetHandle($sApiTitle)
	 ;Local $hEcel = WinGetHandle("[CLASS:XLMAIN]")
	if $hEcel Then WinSetState($hEcel, "", @SW_MINIMIZE)
EndFunc

Func SwapXP($sHosXpTitle)
		;_ArrayDisplay($aList)
	Local $aList = WinList($sHosXpTitle) ;Winlist all hos os
	Local $aList_Length = $aList[0][0]

	If $aList_Length > 0 Then
				For $i = 1 To $aList_Length
					$sTitle = $aList[$i][0]
					$hHandle = $aList[$i][1]
						If $sTitle <> "" And BitAND(WinGetState($hHandle), 2) Then
							;MsgBox($MB_SYSTEMMODAL, "", "Title: " & $aList[$i][0] & @CRLF & "Handle: " & $aList[$i][1])
							WinActivate($sTitle)
							Sleep(1000)
						    ;WinMove($sTitle, "", $aXpPos[0], $aXpPos[1], $aXpPos[2], $aXpPos[3])
							ExitLoop
						EndIf
				Next
	Else
			FileClose($oLogQueue)
		    MsgBox($MB_ICONERROR + $MB_TOPMOST, "Warning!","Not found window:"&@CRLF&$sHosXpTitle,10)
		    Exit 0
    EndIf
EndFunc

Func BotProcessing()
  $oLogQueue = FileOpen($sLogQueue, $FO_READ)
   If $oLogQueue = -1 Then
			MsgBox($MB_ICONERROR + $MB_TOPMOST, "Error", "An error occurred when reading the file."& @CRLF & $sLogQueue)
			Return False
   EndIf
   Local $sQueue = FileRead($oLogQueue)
   Sleep(100)
   ConsoleWrite("bot queue: "&$sQueue&@CRLF)
   HideCmd1()
   HideCmd2()
   SwapXP($sHosXpTitle)
   Sleep(200)
   Local $hWndXp = WinGetHandle($sHosXpTitle)
   Local $hCtrl = ControlGetHandle($hWndXp, "", "[CLASS:TcxTextEdit; INSTANCE:4]") ;specify outer rectangle
   ControlSetText($hWndXp, "", $hCtrl, $sQueue)
   Sleep(500)
   ControlClick($hWndXp,"",$hCtrl,"left")
   Sleep(700)
   ;ControlSend($hWndXp,"",$hCtrl, $sQueue)
   Send("{ENTER}")
   Local $hListShow
   Local $bKill = False
   While 1
	   Sleep(500)
	   if KillFinance1() Then $bKill = True
	   $hListShow = ControlGetHandle($hWndXp, "", "[CLASS:TcxCurrencyEdit; INSTANCE:8]")
       If $hListShow And _WinAPI_IsWindowVisible($hListShow) Then ExitLoop
   WEnd

   FileClose($oLogQueue)
   If $bKill Then
      Return True
   Else
     PostToApi("/complete")
     Return True
  EndIf
EndFunc
MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, "Start bot", "Bot queue going to start please wait...", 2)
if BotProcessing() Then
  MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, "Success", "Bot record successfully.", 2)
EndIf
Exit 0