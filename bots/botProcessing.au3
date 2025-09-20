#RequireAdmin
#include <Excel.au3>
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#Include <WinAPI.au3>
#Include <SendMessage.au3>
#include <FileConstants.au3>
#include <Array.au3>
#include <StringConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include "OpenCV-Match_UDF_Mod.au3"
#include <CppKeySend.au3>

Opt("MouseCoordMode", 1)
Opt("WinTitleMatchMode", 2)
HotKeySet("{ESC}", "Hkey")

Global $gHTTPNode = ObjCreate("WinHttp.WinHttpRequest.5.1")
Global $sLogQueue = @ScriptDir &"\queue.txt"
Global $oLogQueue

Global $sHosXpTitle = "HOSxPMedicationOrderQueueGeneratorForm"   ;HOSxPMedicationOrderQueueGeneratorForm - BMS-HOSxP XE 4.0
Global $sHookTitle = "ScanWedgeClient" ;
Global $sApiTitle = "Pharm Q Server"

Global $gPopupHandled = False   ; popup ถูกจัดการแล้วหรือไม่
Global $bRunningKillFinance = False

Func Hkey()
	FileClose($oLogQueue)
	MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, "Hkey", "Stop Process")
	Exit 0
EndFunc
;#32770
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
                ; ปิด popup
                WinClose($hWnd)
                Sleep(500)
                If WinExists($hWnd) Then
                    WinKill($hWnd)
                    ConsoleWrite("WinKill popup" & @CRLF)
                EndIf
                $bFoundFinance = True
                ExitLoop ; เจอแล้วออก loop ทันที
            EndIf
        EndIf
    Next

    If $bFoundFinance Then
        ; มีการปิด popup อย่างน้อย 1 ครั้ง
        MsgBox($MB_ICONWARNING + $MB_TOPMOST, "Patient Info", "Finance Locked.", 10)
        FileClose($oLogQueue)
        PostToApi("/financelock")
        Return True
    Else
        ; ไม่เจอ popup
        Return False
    EndIf
EndFunc

Func BotProcessing()
  $oLogQueue = FileOpen($sLogQueue, $FO_READ)
   If $oLogQueue = -1 Then
			MsgBox($MB_ICONERROR + $MB_TOPMOST, "Error", "An error occurred when reading the file."& @CRLF & $sLogQueue)
			Return
   EndIf
   Local $sQueue = FileRead($oLogQueue)
   Sleep(100)
   ConsoleWrite("bot queue: "&$sQueue&@CRLF)
   Local $hWndXp = WinGetHandle($sHosXpTitle)
   Local $hCtrl = ControlGetHandle($hWndXp, "", "[CLASS:TcxTextEdit; INSTANCE:4]") ;specify outer rectangle
   WinActivate($hWndXp)
   Sleep(1000)
   ControlSetText($hWndXp, "", $hCtrl, $sQueue)
   Sleep(500)
   ControlClick($hWndXp,"",$hCtrl,"left")
   Sleep(1000)
   ;ControlSend($hWndXp,"",$hCtrl, $sQueue)
   Send("{ENTER}")
   Local $hListShow
   While 1
	   Sleep(1000)
	   KillFinance1()
	   $hListShow = ControlGetHandle($hWndXp, "", "[CLASS:TcxCurrencyEdit; INSTANCE:8]")
       If $hListShow And _WinAPI_IsWindowVisible($hListShow) Then ExitLoop
   WEnd

   FileClose($oLogQueue)
   PostToApi("/complete")
EndFunc

MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, "Start bot", "Bot queue going to start please wait...", 2)
BotProcessing()
MsgBox($MB_ICONINFORMATION + $MB_TOPMOST, "Success", "Bot record successfully.", 2)
Exit 0