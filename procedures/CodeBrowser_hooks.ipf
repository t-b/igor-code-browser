#pragma rtGlobals=3
#pragma version=1.0
#pragma IgorVersion = 6.3.0
#pragma IndependentModule=CodeBrowserModule

// This file was created by () byte physics Thomas Braun, support@byte-physics.de
// (c) 2013

static Function IgorBeforeQuitHook(unsavedExp, unsavedNotebooks, unsavedProcedures)
	variable unsavedExp, unsavedNotebooks, unsavedProcedures

	string expName

	debugPrint("called")
	debugPrint("unsavedExp: " + num2str(unsavedExp))

	BeforePanelClose()
	DoWindow/K CodeBrowser
	AfterPanelClose()

	if(unsavedExp || unsavedNotebooks || unsavedProcedures)
		return 0
	endif

	expName = IgorInfo(1)
	if(!cmpstr(expName, "Untitled"))
		return 0
	endif

	// experiment saved and pxp still exists -> silently save it
	// does not support unpacked experiments
	GetFileFolderInfo/P=home/Q/Z expName + ".pxp"
	if(!V_Flag)
		SaveExperiment
		return 1
	endif

	return 0
End

static Function IgorBeforeNewHook(igorApplicationNameStr)
	string igorApplicationNameStr

	debugPrint("called")
	BeforePanelClose()

	return 0
End

Function initializePanel()

	debugprint("called")

	Execute/Z/Q "SetIgorOption IndependentModuleDev=1"
	if(!(V_flag == 0))
		debugPrint("Error: SetIgorOption IndependentModuleDev returned " + num2str(V_flag))
	endif

	Execute/Z/Q "SetIgorOption recreateListboxHScroll=1"
	if(!(V_flag == 0))
		debugPrint("Error: SetIgorOption recreateListboxHScroll returned " + num2str(V_flag))
	endif

	SetIgorHook AfterCompiledHook=updatePanel
	debugPrint("AfterCompiledHook: " + S_info)

	updatePanel()

	setGlobalStr("search", "")
End

// Prepare for panel closing.
//
// note: Must be called before the panel is killed or the experiment is closed.
Function BeforePanelClose()
	SetIgorHook/K AfterCompiledHook=updatePanel
	if(strlen(S_info) > 0)
		debugPrint("registered hooks with hookType=AfterCompiledHook: " + S_info)
	else
		debugPrint("all hookType=AfterCompiledHook deleted")
	endif
End

// Clean up after closing panel
//
// note: Must be called after the panel was closed
Function AfterPanelClose()
	variable cleanOnExit

	if(!existsPanel())
		return 0
	endif

	cleanOnExit = !!getGlobalVar("cleanOnExit")
	QuitPackagePrefs()
	if(cleanOnExit)
		KillStorage()
		KillPanelObjects()
		DeletePKGfolder()
	endif
End

// Kill panel-bound variables and waves
//
// @see KillStorage
//
// note: if the waves and variables are still bound to a panel, this function
//       will only reset them.
Function KillPanelObjects()
	Wave/T decl = getDeclWave()
	Wave/I line = getLineWave()

	// reset
	setGlobalStr("search","")
	setGlobalVar("initialized", 0)

	// kill
	KillWaves/Z decl, line
	killGlobalStr("search")
	killGlobalVar("initialized")
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
			BeforePanelClose()
			AfterPanelClose()
			hookResult = 1
			break
		case 6:				// resize
			hookResult = ResizeControls#ResizeControlsHook(s)
			break
	endswitch

	return hookResult		// 0 if nothing done, else 1
End
