#pragma rtGlobals=3
#pragma version=1.0
#pragma IgorVersion = 6.3.0
#pragma IndependentModule=CodeBrowserModule

// This file was created by () byte physics Thomas Braun, support@byte-physics.de
// (c) 2013

static Function IgorBeforeQuitHook(igorApplicationNameStr)
	string igorApplicationNameStr

	preparePanelClose()
	return 0
End

static Function IgorBeforeNewHook(igorApplicationNameStr)
	string igorApplicationNameStr

	preparePanelClose()
	return 0
End

static Function BeforeExperimentSaveHook(rN,fileName,path,type,creator,kind)
	Variable rN,kind
	String fileName,path,type,creator

	markAsUnInitialized()
	return 0
End

Function initializePanel()

	debugprint("called")

	Execute/Z/Q "SetIgorOption IndependentModuleDev=1"
	if (!(V_flag == 0))
		debugPrint("Error: SetIgorOption returned " + num2str(V_flag))
	endif
	
	SetIgorHook AfterCompiledHook=updatePanel
	debugPrint("AfterCompiledHook: " + S_info)

	updatePanel()
End

// Prepare for panel closing, must be called before the panel is killed or the experiment closed
Function preparePanelClose()

	SetIgorHook/K AfterCompiledHook=updatePanel
	debugPrint("AfterCompiledHook: " + S_info)

	// storage data should not be saved in experiment
	saveResetStorage()

	DoWindow $GetPanel()
	if(V_flag == 0)
		return 0
	endif

	// save panel coordinates to disk
	STRUCT CodeBrowserPrefs prefs
	FillPackagePrefsStruct(prefs)
	SavePackagePrefsToDisk(prefs)
	
	// reset global gui variables
	searchReset()
End

Function panelHook(s)
	STRUCT WMWinHookStruct &s

	Variable hookResult = 0

	switch(s.eventCode)
		case 0:				// activate
			if(isInitialized())
				break
			endif
			initializePanel()
			markAsInitialized()
			break
		case 2:				// kill
			preparePanelClose()
			hookResult = 1
			break
		case 6:				// resize
			hookResult = ResizeControls#ResizeControlsHook(s)
			break
	endswitch

	return hookResult		// 0 if nothing done, else 1
End
