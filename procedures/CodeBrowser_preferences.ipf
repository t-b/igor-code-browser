#pragma rtGlobals=3
#pragma version=1.0
#pragma IgorVersion = 6.3.0
#pragma IndependentModule=CodeBrowserModule

// This file was created by () byte physics Thomas Braun, support@byte-physics.de
// (c) 2013

static Constant kPrefsVersion = 102
static StrConstant kPackageName = "CodeBrowser"
static StrConstant kPrefsFileName = "CodeBrowser.bin"
static Constant kPrefsRecordID = 0

Structure CodeBrowserPrefs
	uint32	version		// Preferences structure version number. 100 means 1.00.
	double panelCoords[4]	// left, top, right, bottom
	uint32 panelCheckboxSort 	// status of checkbox in createPanel()
	uint32 reserved[99]	// Reserved for future use
EndStructure

//	DefaultPackagePrefsStruct(prefs)
//	Sets prefs structure to default values.
static Function DefaultPackagePrefsStruct(prefs)
	STRUCT CodeBrowserPrefs &prefs
	Variable scale

	prefs.version = kPrefsVersion

#if (IgorVersion() >= 7.0)
	scale = ScreenResolution / PanelResolution(GetPanel())
#else
	scale = ScreenResolution / 72
#endif
	prefs.panelCoords[0] = panelLeft * scale
	prefs.panelCoords[1] = panelTop * scale
	prefs.panelCoords[2] = (panelLeft + panelWidth) * scale
	prefs.panelCoords[3] = (panelTop + panelHeight) * scale

	prefs.panelCheckboxSort = 1

	Variable i
	for(i=0; i<99; i+=1)
		prefs.reserved[i] = 0
	endfor
End

// Fill package prefs structures to match state of panel.
static Function SyncPackagePrefsStruct(prefs)
	STRUCT CodeBrowserPrefs &prefs
	Variable scale
	// Panel does exists. Set prefs to match panel settings.
	prefs.version = kPrefsVersion

	GetWindow $GetPanel() wsize // returns points

#if (IgorVersion() >= 7.0)
	scale = ScreenResolution / PanelResolution(GetPanel())
#else
	scale = ScreenResolution / 72
#endif
	prefs.panelCoords[0] = V_left * scale
	prefs.panelCoords[1] = V_top * scale
	prefs.panelCoords[2] = V_right * scale
	prefs.panelCoords[3] = V_bottom * scale
	
	prefs.panelCheckboxSort = returnCheckBoxSort()
End

// InitPackagePrefsStruct(prefs)
// Sets prefs structures to match state of panel or to default values if panel does not exist.
Function FillPackagePrefsStruct(prefs)
	STRUCT CodeBrowserPrefs &prefs

	DoWindow $GetPanel()
	if (V_flag == 0)
		// Panel does not exist. Set prefs struct to default.
		DefaultPackagePrefsStruct(prefs)
	else
		// Panel does exists. Sync prefs struct to match panel state.
		SyncPackagePrefsStruct(prefs)
	endif
End

Function LoadPackagePrefsFromDisk(prefs)
	STRUCT CodeBrowserPrefs &prefs
	Variable scale
	// This loads preferences from disk if they exist on disk.
	LoadPackagePreferences kPackageName, kPrefsFileName, kPrefsRecordID, prefs

	// If error or prefs not found or not valid, initialize them.
	if (V_flag!=0 || V_bytesRead==0 || prefs.version!=kPrefsVersion)
		FillPackagePrefsStruct(prefs)	// Set based on panel if it exists or set to default values.
		SavePackagePrefsToDisk(prefs)	// Create initial prefs record.
	endif


#if (IgorVersion() >= 7.0)
	scale = ScreenResolution / PanelResolution(GetPanel())
#else
	scale = ScreenResolution / 72
#endif
	prefs.panelCoords[0] /= scale
	prefs.panelCoords[1] /= scale
	prefs.panelCoords[2] /= scale
	prefs.panelCoords[3] /= scale

End

Function SavePackagePrefsToDisk(prefs)
	STRUCT CodeBrowserPrefs &prefs

	SavePackagePreferences kPackageName, kPrefsFileName, kPrefsRecordID, prefs
End

// Used to test SavePackagePreferences /KILL flag added in Igor Pro 6.10B04.
Function KillPackagePrefs()
	STRUCT CodeBrowserPrefs prefs
	SavePackagePreferences /KILL kPackageName, kPrefsFileName, kPrefsRecordID, prefs
End
