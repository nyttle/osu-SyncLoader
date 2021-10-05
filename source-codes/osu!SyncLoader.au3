#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Icon=osu!icon.ico
#AutoIt3Wrapper_Res_Description=osu!SyncLoader by Tree
#AutoIt3Wrapper_Res_Comment=To configure, Alt+Tab while in-game, navigate to the commandline windows then type in 'config' and press Enter
#AutoIt3Wrapper_Res_ProductVersion=1.1
#AutoIt3Wrapper_Res_Fileversion=1.1
#include <Array.au3>
#include <File.au3>
#include <String.au3>
#include <ButtonConstants.au3>
#include <GUIConstantsEx.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <InetConstants.au3>
#NoTrayIcon

Global $Title = "osu!SyncLoader by Tree"
Global $syncDir = ""
Global $osuDir = ""
Global $osuExe = ""

Global $GUI

Global $skipUpdate = False

Global $currentVersion = FileGetVersion(@ScriptFullPath)
Global $cloudINF = "https://www.dropbox.com/s/mg5rysk2m29i3sc/slversion.inf?dl=1"
Global $cloudVersion = BinaryToString(InetRead($cloudINF, 1)) & ".0.0"
Global $cloudEXE = "https://github.com/nyttle/osu-SyncLoader/raw/main/osu!SyncLoader.exe"

Global $configDir = @LocalAppDataDir & "\osu!"
Global $configFile = $configDir & "\osu!Sync Loader.config"

Global $status_0 = "waiting for server..."
Global $status_1 = "downloading updates..."
Global $status_2 = "updating..."
Global $status_3 = "reading config..."
Global $status_4 = "loading SyncLoader..."

Global $updBatch = "@echo off" & @CRLF & _
		"title " & $Title & @CRLF & _
		"cls" & @CRLF & _
		"echo|set /p a=updating... " & @CRLF & _
		"ping localhost -n 2 > nul" & @CRLF & _
		"if not exist " & @ScriptName & " goto err" & @CRLF & _
		"if not exist sl.upd goto err" & @CRLF & _
		"goto loop" & @CRLF & _
		"" & @CRLF & _
		":err" & @CRLF & _
		"echo error occurred (-1)" & @CRLF & _
		"start /b " & @ScriptName & " --update=-1" & @CRLF & _
		"exit" & @CRLF & _
		"" & @CRLF & _
		":loop" & @CRLF & _
		"echo|set /p a=waiting for the program to close..." & @CRLF & _
		"del /q " & @ScriptName & @CRLF & _
		"if exist " & @ScriptName & " goto loop" & @CRLF & _
		"" & @CRLF & _
		"move sl.upd " & @ScriptName & " > nul" & @CRLF & _
		"start /b " & @ScriptName & " --update=1" & @CRLF & _
		"echo done!" & @CRLF & _
		'del "%~f0" & exit'


If $CMDLINERAW = "--reset-config" Or $CMDLINERAW = "-r" Or $CMDLINERAW = "/r" Then
	FileDelete($configFile)
	DirRemove($configDir)
EndIf

If $CMDLINERAW = "--update=-1" Then
	MsgBox(64, $Title, "Detected error in updating. Will ignore updates until next time.")
	$skipUpdate = True
EndIf

If $CMDLINERAW = "--update=1" Then
	MsgBox(64, $Title, "Updated successfully!", 1000)
	$skipUpdate = True
EndIf

_Main()
Exit

Func _Main()
	$GUI = GUICreate($Title, 315, 105)
	$status_lb = GUICtrlCreateLabel("Status:", 32, 24, 62, 33, $SS_CENTERIMAGE)
	GUICtrlSetFont(-1, 14, 400, 0, "Times New Roman")
	GUICtrlSetColor(-1, 0x000000)
	$status = GUICtrlCreateLabel($status_0, 96, 23, 177, 37, $SS_CENTERIMAGE)
	GUICtrlSetFont(-1, 11, 400, 0, "Times New Roman")
	GUICtrlSetColor(-1, 0x000000)
	$progress = GUICtrlCreateProgress(0, 80, 313, 10)
	$group1 = GUICtrlCreateGroup("", -8, 8, 321, 65)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	GUISetState(@SW_SHOW)

	_reload()
;~ 	For $i = 0 To 100 Step 1
;~ 		GUICtrlSetData($progress, $i)
;~ 		Sleep(1)
;~ 	Next
;~ 	GUICtrlSetData($progress, 0)

	If $skipUpdate = False Then _checkupdate($status, $progress)

	If Not FileExists($configFile) Then
		DirCreate($configDir)
		_FileCreate($configFile)
		FileWriteLine($configFile, "[Loader.Config]" & @CRLF & "SyncPath=" & $syncDir & @CRLF & "osu!Path=" & $osuDir)
		IniWrite("config.ini", "IngameOverlay.OverlayConfig", "OsuExecPath", $osuDir)
	EndIf

	_reload()


	$osuLocation = ""

	If _isOsuPath($osuDir) = 0 Or Not $osuDir Then
		While Not $osuLocation
			$osuLocation = FileOpenDialog($Title & " | Select osu!.exe", @AppDataDir, "(osu!.exe)", 3, "osu!.exe")
			If Not $osuLocation Then
				$ans = MsgBox(68, $Title, "Do you want to quit osu!Sync Loader?")
				If $ans = 6 Then Exit
			EndIf
		WEnd
		$osuDir = StringLeft($osuLocation, StringLen($osuLocation) - StringLen("osu!.exe"))
	EndIf

	$syncLocation = ""
	If Not $syncDir Or Not FileExists($syncDir & "\Sync.exe") Then
		While Not $syncLocation
			$syncLocation = FileOpenDialog($Title & " | Select Sync.exe", $osuDir, "(Sync.exe)", 3, "Sync.exe")
			If Not $syncLocation Then
				$ans = MsgBox(68, $Title, "Do you want to quit osu!Sync Loader?")
				If $ans = 6 Then Exit
			EndIf
		WEnd
		$syncDir = StringLeft($syncLocation, StringLen($syncLocation) - StringLen("Sync.exe"))
	EndIf

	_update()


	GUICtrlSetData($status, $status_4)
	Local $PID = Run($syncDir & "\Sync.exe")
	For $i = 0 To 100
		GUICtrlSetData($progress, $i)
		Sleep(1)
	Next
	Run($osuExe)
	Sleep(200)
	Local $wHWD = _WinGetByPID($PID)

	WinActivate($wHWD)
	Send("o osu {ENTER}")
	WinSetState($wHWD, "", @SW_MINIMIZE)
	GUISetState(@SW_HIDE)

	Sleep(3000)
	Do
		Sleep(500)
	Until Not ProcessExists("osu!.exe")

	WinClose($wHWD)
	Sleep(3000)
	If ProcessExists($PID) Then ProcessClose($PID)
	Exit

EndFunc   ;==>_Main

Func _checkupdate($lb, $progress)
	If Not ($currentVersion = $cloudVersion) Then
		GUICtrlSetData($lb, $status_1)
		$data = InetGet($cloudEXE, @ScriptDir & "\sl.upd")

		GUICtrlSetData($lb, $status_2)
		FileWrite("upd.bat", $updBatch)
		Run("upd.bat")
		Exit
	EndIf

	Return 0

EndFunc   ;==>_checkupdate

Func _reload()
	$syncDir = IniRead($configFile, "Loader.Config", "SyncPath", "")
	$osuDir = IniRead($configFile, "Loader.Config", "osu!Path", "")
	;$currentVersion = FileGetVersion(@ScriptFullPath)
EndFunc   ;==>_reload

Func _update()
	;IniWrite($configFile, "Loader.Config", "Version", FileGetVersion(@ScriptFullPath))
	IniWrite($configFile, "Loader.Config", "SyncPath", $syncDir)
	IniWrite($configFile, "Loader.Config", "osu!Path", $osuDir)
	IniWrite($syncDir & "\config.ini", "IngameOverlay.OverlayConfig", "OsuExecPath", $osuDir & "osu!.exe")
	$osuExe = IniRead($configFile, "Loader.Config", "osu!Path", $osuDir) & "osu!.exe"
EndFunc   ;==>_update

Func _isOsuPath($iPath)
	Return FileExists($iPath)
EndFunc   ;==>_isOsuPath

Func ByteToMByte($b)
	Return $b / (10 ^ 6)
EndFunc   ;==>ByteToMByte


Func _WinGetByPID($iPID, $iArray = 1) ; 0 Will Return 1 Base Array & 1 Will Return The First Window.
	Local $aError[1] = [0], $aWinList, $sReturn
	If IsString($iPID) Then
		$iPID = ProcessExists($iPID)
	EndIf
	$aWinList = WinList()
	For $A = 1 To $aWinList[0][0]
		If WinGetProcess($aWinList[$A][1]) = $iPID And BitAND(WinGetState($aWinList[$A][1]), 2) Then
			If $iArray Then
				Return $aWinList[$A][1]
			EndIf
			$sReturn &= $aWinList[$A][1] & Chr(1)
		EndIf
	Next
	If $sReturn Then
		Return StringSplit(StringTrimRight($sReturn, 1), Chr(1))
	EndIf
	Return SetError(1, 0, $aError)
EndFunc   ;==>_WinGetByPID
