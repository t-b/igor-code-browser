#pragma rtGlobals=3
#pragma version=1.0
#pragma IgorVersion = 6.3.0
#pragma IndependentModule=CodeBrowserModule

// This file was created by () byte physics Thomas Braun, support@byte-physics.de
// (c) 2013

Menu "CodeBrowser"
	// CTRL+0 is the keyboard shortcut
	"Open/0", /Q, CodeBrowserModule#CreatePanel()
End

// Markers for the different listbox elements
StrConstant strConstantMarker = "\\W539"
StrConstant constantMarker    = "\\W534"
StrConstant functionMarker    = "\\W529"
StrConstant macroMarker       = "\\W519"
StrConstant windowMarker      = "\\W520"
StrConstant procMarker        = "\\W521"
StrConstant structureMarker   = "\\W522"
StrConstant menuMarker        = "\\W523"

// the idea here: static functions have less intense colors
StrConstant plainColor     = "0,0,0"             // black
StrConstant staticColor    = "47872,47872,47872" // grey

StrConstant tsColor        = "0,0,65280"         // blue
StrConstant tsStaticColor  = "32768,40704,65280" // light blue

StrConstant overrideColor  = "65280,0,0"         // red
StrConstant overrideTSColor= "26368,0,52224"     // purple

StrConstant pkgFolder         = "root:Packages:CodeBrowser"
// 2D Wave
// first column : marker depending on the function/macro type
// second column: full declaration of the  function/macro
// one row for each function/macro
StrConstant declarations      = "declarations"
// 1D Wave in each row having the line of the function or -1 for macros
StrConstant declarationLines  = "lines"
// database-like global multidimensional waves for storing parsing results to minimize time.
static StrConstant CsaveStrings 	= "saveStrings"
static Strconstant CSaveVariables 	= "saveVariables"
static StrConstant CsaveWaves 		= "saveWaves"
// Maximum Waves that will be saved in Experiment. first in first out.
static Constant CsaveMaximum = 1024

Constant    openKey           = 46 // ".", the dot

// List of igor7 structure elements.
static strConstant cstrTypes = "Variable|String|WAVE|NVAR|SVAR|DFREF|FUNCREF|STRUCT|char|uchar|int16|uint16|int32|uint32|int64|uint64|float|double"
// Loosely based on the WM procedure from the documentation
// Returns a human readable string for the given parameter/return type.
// See the documentation for FunctionInfo for the exact values.
Function/S interpretParamType(ptype, paramOrReturn, funcInfo)
	variable ptype, paramOrReturn
	string funcInfo

	string typeName
	string typeStr = ""

	if(paramOrReturn != 0 && paramOrReturn != 1)
		Abort "paramOrReturn must be 1 or 0"
	endif

	if(ptype & 0x4000)
		typeStr += "wave"

		// type addon
		if(ptype & 0x1)
			typeStr += "/C"
		endif

		 // text wave for parameters only. Seems to be a bug in the documentation or Igor. Already reported to WM.
		if(ptype == 0x4000 && paramOrReturn)
			typeStr += "/T"
		elseif(ptype & 0x4)
			typeStr += "/D"
		elseif(ptype & 0x2)
//			this is the default wave type, this is printed 99% of the time so we don't output it
//			typeStr += "/R"
		elseif(ptype & 0x8)
			typeStr += "/B"
		elseif(ptype & 0x10)
			typeStr += "/W"
		elseif(ptype & 0x20)
			typeStr += "/I"
		elseif(ptype & 0x80) // undocumented
			typeStr += "/WAVE"
		elseif(ptype & 0x100)
			typeStr += "/DF"
		endif

		if(ptype & 0x40)
			typeStr += "/U"
		endif

//		if(getGlobalVar("debuggingEnabled") == 1)
//			string msg
//			sprintf msg, "type:%d, str:%s", ptype, typeStr
//			debugPrint(msg)
//		endif

		return typeStr
	endif

	// special casing
	if(ptype == 0x5)
		return "imag"
	elseif(ptype == 0x1005)
		return "imag&"
	endif

	if(ptype & 0x2000)
		typeStr += "str"
	elseif(ptype & 0x4)
		typeStr += "var"
	elseif(ptype & 0x100)
		typeStr += "dfref"
	elseif(ptype & 0x200)
		if(GetStructureArgument(funcInfo, typeName))
			typeStr += typeName
		else
			typeStr += "struct"
		endif
	elseif(ptype & 0x400)
		typeStr += "funcref"
	endif

	if(ptype & 0x1)
		typeStr += " imag"
	endif

	if(ptype & 0x1000)
		typeStr += "&"
	endif

	return typeStr
End

// Convert the SPECIAL tag from FunctionInfo
Function/S interpretSpecialTag(specialTag)
	string specialTag

	strswitch(specialTag)
		case "no":
			return ""
			break
		default:
			return specialTag
			break
	endswitch
End

// Convert the THREADSAFE tag from FunctionInfo
Function/S interpretThreadsafeTag(threadsafeTag)
	string threadsafeTag

	strswitch(threadsafeTag)
		case "yes":
			return "threadsafe"
			break
		case "no":
			return ""
			break
		default:
			debugPrint("Unknown default value")
			return ""
			break
	endswitch
End

// Convert the SUBTYPE tag from FunctionInfo
Function/S interpretSubtypeTag(subtypeTag)
	string subtypeTag

	strswitch(subtypeTag)
		case "NONE":
			return ""
			break
		default:
			return subtypeTag
			break
	endswitch
End

// Returns a human readable interpretation of the function info string
Function/S interpretParameters(funcInfo)
	string funcInfo

	variable numParams = NumberByKey("N_PARAMS", funcInfo)
	variable i
	string str = "", key, paramType

	variable numOptParams = NumberByKey("N_OPT_PARAMS", funcInfo)

	for(i = 0; i < numParams; i += 1)
		sprintf key, "PARAM_%d_TYPE", i
		paramType = interpretParamType(NumberByKey(key, funcInfo), 1, funcInfo)

		if(i == numParams - numOptParams)
			str += "["
		endif

		str += paramType

		if(i != numParams - 1)
			str += ", "
		endif
	endfor

	if(numOptParams > 0)
		str += "]"
	endif

	return str
End

// check if Function has as a structure as first parameter
//
// the structure definition has to be in the first line after the function definition
//
// @param[in]  funcInfo        output of FunctionInfo for the function in question
// @param[out] structureName   matched name of the structure as string.
//                             Not changed if 0 is returned.
//
// @returns 1 if function has such a parameter, 0 otherwise
Function GetStructureArgument(funcInfo, structureName)
	string funcInfo
	string &structureName

	string declaration, re, str0

	if(NumberByKey("PARAM_0_TYPE", funcInfo) & (0x200 | 0x1000)) // struct | pass-by-reference
		declaration = getFunctionLine(1, funcInfo)
		re = "(?i)^\s*struct\s+(\w+)\s+"
		SplitString/E=(re) declaration, str0
		if(V_flag == 1)
			structureName = str0
			return 1
		endif
	endif

	return 0
End

// Returns a cmd for the given fill *and* stroke color
Function/S getColorDef(color)
	string color

	string str
	sprintf str, "\k(%s)\K(%s)", color, color

	return str
End

// Creates a colored marker based on the function type
Function/S createMarkerForType(type)
	string type

	string marker
	if(strsearch(type, "function", 0) != -1)
		marker = functionMarker
	elseif(strsearch(type, "macro", 0) != -1)
		marker = macroMarker
	elseif(strsearch(type, "window", 0) != -1)
		marker = windowMarker
	elseif(strsearch(type, "proc", 0) != -1)
		marker = procMarker
	elseif(strsearch(type, "strconstant", 0) != -1)
		marker = strConstantMarker
	elseif(strsearch(type, "constant", 0) != -1)
		marker = constantMarker
	elseif(strsearch(type, "structure", 0) != -1)
		marker = structureMarker
	elseif(strsearch(type, "menu", 0) != -1)
		marker = menuMarker
		return getColorDef(plainColor) + marker
	endif

	// plain definitions
	if(cmpstr(type,"function") == 0 || cmpstr(type,"macro") == 0 || cmpstr(type,"window") == 0 || cmpstr(type,"proc") == 0 || cmpstr(type,"constant") == 0 || cmpstr(type,"strconstant") == 0 || cmpstr(type,"structure") == 0)
		return getColorDef(plainColor) + marker
	endif

	if(strsearch(type,"threadsafe",0) != -1)
		if(strsearch(type,"static",0) != -1) // threadsafe + static
			return getColorDef(tsStaticColor) + marker
		elseif(strsearch(type,"override",0) != -1) // threadsafe + override
			return getColorDef(overrideTSColor) + marker
		else
			return getColorDef(tsColor) + marker // plain threadsafe
		endif
	elseif(strsearch(type,"static",0) != -1)
		return getColorDef(staticColor) + marker // plain static
	elseif(strsearch(type,"override",0) != -1)
		return getColorDef(overrideColor) + marker // plain override
	endif

	Abort "Unknown type"
End

// Pretty printing of function/macro with additional info
Function/S formatDecl(funcOrMacro, params, subtypeTag, returnType)
	string funcOrMacro, params, subtypeTag, returnType

	if(!isEmpty(subtypeTag))
		subtypeTag = " : " + subtypeTag
	endif

	string decl
	if(strlen(returnType) == 0)
		sprintf decl, "%s(%s)%s", funcOrMacro, params, subtypeTag
	else
		sprintf decl, "%s(%s) -> %s%s", funcOrMacro, params, returnType, subtypeTag
	endif

	return decl
End

// Adds all kind of information to a list of function in current procedure
Function addDecoratedFunctions(module, procedure, declWave, lineWave)
	string module, procedure
	Wave/T declWave
	Wave/D lineWave

	String options, funcList
	string func, funcDec, fi
	string threadsafeTag, specialTag, params, subtypeTag, returnType
	variable i, idx, numMatches, numEntries

	// list normal, userdefined, override and static functions
	options  = "KIND:18,WIN:" + procedure
	funcList = FunctionList("*", ";", options)
	numMatches = ItemsInList(funcList)
	numEntries = DimSize(declWave, 0)
	Redimension/N=(numEntries + numMatches, -1) declWave, lineWave

	idx = numEntries
	for(i = 0; i < numMatches; i += 1)
		func = StringFromList(i, funcList)
		fi = FunctionInfo(module + "#" + func, procedure)
		if(!cmpstr(func, "Procedures Not Compiled"))
			fi = ReplaceNumberByKey("PROCLINE", fi, 0)
		endif
		if(isEmpty(fi))
			debugPrint("macro or other error for " + module + "#" + func)
		endif
		returnType    = interpretParamType(NumberByKey("RETURNTYPE", fi), 0, fi)
		threadsafeTag = interpretThreadsafeTag(StringByKey("THREADSAFE", fi))
		specialTag    = interpretSpecialTag(StringByKey("SPECIAL", fi))
		subtypeTag    = interpretSubtypeTag(StringByKey("SUBTYPE", fi))
		params        = interpretParameters(fi)
		declWave[idx][0] = createMarkerForType("function" + specialTag + threadsafeTag)
		declWave[idx][1] = formatDecl(func, params, subtypeTag, returnType)
		lineWave[idx]    = NumberByKey("PROCLINE", fi)
		idx += 1
	endfor

	string msg
	sprintf msg, "decl rows=%d\r", DimSize(declWave, 0)
	debugPrint(msg)
End

// Adds Constants/StrConstants by searching for them in the Procedure with a Regular Expression
Function addDecoratedConstants(module, procedureWithoutModule, declWave, lineWave)
	String module, procedureWithoutModule
	WAVE/T declWave
	WAVE/D lineWave

	Variable numLines, i, idx, numEntries, numMatches
	String procText, re, def, name

	// get procedure code
	procText = getProcedureText("", 0, module, procedureWithoutModule)
	numLines = ItemsInList(procText, "\r")

	// search code and return wavLineNumber
	Make/FREE/N=(numLines)/T text = StringFromList(p, procText, "\r")
	// help for regex on https://regex101.com/
	re = "^(?i)[[:space:]]*((?:override\s+)?(?:static)?[[:space:]]*(?:Str)?Constant)[[:space:]]+([^=\s]*)\s*=\s*(?:\"(?:[^\"\\\\]|\\\\.)+\"|0[xX][0-9a-fA-F]+|[0-9]+)\s*(?:[\/]{2}.*)?"
	Grep/Q/INDX/E=re text
	Wave W_Index
	Duplicate/FREE W_Index wavLineNumber
	KillWaves/Z W_Index
	KillStrings/Z S_fileName
	WaveClear W_Index
	if(!V_Value) // no matches
		return 0
	endif

	numMatches = DimSize(wavLineNumber, 0)
	numEntries = DimSize(declWave, 0)
	Redimension/N=(numEntries + numMatches, -1) declWave, lineWave

	idx = numEntries
	for(i = 0; i < numMatches; i += 1)
		SplitString/E=re text[wavLineNumber[i]], def, name

		declWave[idx][0] = createMarkerForType(LowerStr(def))
		declWave[idx][1] = name
		lineWave[idx]    = wavLineNumber[i]
		idx += 1
	endfor

	KillWaves/Z W_Index
End

Function addDecoratedMacros(module, procedureWithoutModule, declWave, lineWave)
	String module, procedureWithoutModule
	WAVE/T declWave
	WAVE/D lineWave

	Variable numLines, idx, numEntries, numMatches
	String procText, re, def, name, arguments, type

	// get procedure code
	procText = getProcedureText("", 0, module, procedureWithoutModule)
	numLines = ItemsInList(procText, "\r")

	// search code and return wavLineNumber
	Make/FREE/N=(numLines)/T text = StringFromList(p, procText, "\r")
	// regexp: match case insensitive (?i) spaces don't matter. search for window or macro or proc. Macro Name is the the next non-space character followed by brackets () where the arguments are. At the end there might be a colon, specifying the type of macro and a comment beginning with /
	// macro should have no arguments. Handled for backwards compatibility.
	// help for regex on https://regex101.com/
	re = "^(?i)[[:space:]]*(window|macro|proc)[[:space:]]+([^[:space:]]+)[[:space:]]*\((.*)\)[[:space:]]*[:]?[[:space:]]*([^[:space:]\/]*).*"
	Grep/Q/INDX/E=re text
	Wave W_Index
	Duplicate/FREE W_Index wavLineNumber
	KillWaves/Z W_Index
	KillStrings/Z S_fileName
	WaveClear W_Index
	if(!V_Value) // no matches
		return 0
	endif

	numMatches = DimSize(wavLineNumber, 0)
	numEntries = DimSize(declWave, 0)
	Redimension/N=(numEntries + numMatches, -1) declWave, lineWave

	for(idx = numEntries; idx < (numEntries + numMatches); idx += 1)
		SplitString/E=re text[wavLineNumber[(idx - numEntries)]], def, name, arguments, type
		// def containts window/macro/proc
		// type contains Panel/Layout for subclasses of window macros
		declWave[idx][0] = createMarkerForType(LowerStr(def))
		declWave[idx][1] = name + "(" +  trimArgument(arguments, ",", strListSepStringOutput = ", ") + ")" + " : " + type
		lineWave[idx]    = wavLineNumber[(idx - numEntries)]
	endfor
End

Function addDecoratedStructure(module, procedureWithoutModule, declWave, lineWave, [parseVariables])
	String module, procedureWithoutModule
	WAVE/T declWave
	WAVE/D lineWave
	Variable parseVariables
	if(paramIsDefault(parseVariables) | parseVariables != 1)
		parseVariables = 1 // added for debugging
	endif

	variable numLines, idx, numEntries, numMatches
	string procText, reStart, reEnd, name, StaticKeyword

	// get procedure code
	procText = getProcedureText("", 0, module, procedureWithoutModule)
	numLines = ItemsInList(procText, "\r")
	if(numLines == 0)
		debugPrint("no Content in Procedure " + procedureWithoutModule)
	endif

	// search code and return wavLineNumber
	Make/FREE/N=(numLines)/T text = StringFromList(p, procText, "\r")
	// regexp: match case insensitive (?i) leading spaces don't matter. optional static statement. search for structure name which contains no spaces. followed by an optional space and nearly anything like inline comments
	// help for regex on https://regex101.com/
	reStart = "^(?i)[[:space:]]*((?:static[[:space:]])?)[[:space:]]*structure[[:space:]]+([^[:space:]\/]+)[[:space:]\/]?.*"
	Grep/Q/INDX/E=reStart text
	Wave W_Index
	Duplicate/FREE W_Index wavStructureStart
	KillWaves/Z W_Index
	KillStrings/Z S_fileName
	WaveClear W_Index
	if(!V_Value) // no matches
		return 0
	endif
	numMatches = DimSize(wavStructureStart, 0)

	// optionally analyze structure elements
	if(parseVariables)
		// regexp: match case insensitive endstructure followed by (space or /) and anything else or just a lineend
		// does not match endstructure23 but endstructure//
		reEnd = "^(?i)[[:space:]]*(?:endstructure(?:[[:space:]]|\/).*)|endstructure$"
		Grep/Q/INDX/E=reEnd text
		Wave W_Index
		Duplicate/FREE W_Index wavStructureEnd
		KillWaves/Z W_Index
		KillStrings/Z S_fileName
		WaveClear W_Index
		if(numMatches != DimSize(wavStructureEnd, 0))
			numMatches = 0
			return 0
		endif
	endif

	numEntries = DimSize(declWave, 0)
	Redimension/N=(numEntries + numMatches, -1) declWave, lineWave

	for(idx = numEntries; idx < (numEntries + numMatches); idx +=1)
		SplitString/E=reStart text[wavStructureStart[(idx - numEntries)]], StaticKeyword, name
		declWave[idx][0] = createMarkerForType(LowerStr(StaticKeyword) + "structure") // no " " between static and structure needed
		declWave[idx][1] = name

		// optionally parse structure elements
		if(parseVariables)
			Duplicate/FREE/R=[(wavStructureStart[(idx - numEntries)]),(wavStructureEnd[(idx - numEntries)])] text, temp
			declWave[idx][1] += getStructureElements(temp)
			WaveClear temp
		endif

		lineWave[idx] = wavStructureStart[(idx - numEntries)]
	endfor

	WaveClear wavStructureStart, wavStructureEnd
End

Function addDecoratedMenu(module, procedureWithoutModule, declWave, lineWave)
	String module, procedureWithoutModule
	WAVE/T declWave
	WAVE/D lineWave

	Variable numLines, idx, numEntries, numMatches
	String procText, re, def, name, type
	String currentMenu = ""

	// get procedure code
	procText = getProcedureText("", 0, module, procedureWithoutModule)
	numLines = ItemsInList(procText, "\r")

	// search code and return wavLineNumber
	Make/FREE/N=(numLines)/T text = StringFromList(p, procText, "\r")
	// regexp: match case insensitive (?i) spaces don't matter. search for menu or submenu with a name in double quotes.
	// help for regex on https://regex101.com/
	re = "^(?i)[[:space:]]*(menu|submenu)[[:space:]]+\"((?:[^\"\\\\]|\\\\.)+)\"(?:[[:space:]]*[,][[:space:]]*(hideable|dynamic|contextualmenu))?"
	Grep/Q/INDX/E=re text
	numMatches = !!V_Value
	Wave W_Index
	Duplicate/FREE W_Index wavLineNumber
	KillWaves/Z W_Index
	if(!numMatches)
		return 0
	endif

	numMatches = DimSize(wavLineNumber, 0)
	numEntries = DimSize(declWave, 0)
	Redimension/N=(numEntries + numMatches, -1) declWave, lineWave

	for(idx = numEntries; idx < (numEntries + numMatches); idx += 1)
		SplitString/E=re text[wavLineNumber[(idx - numEntries)]], def, name, type
		def = LowerStr(def)
		if(!cmpstr(def, "menu"))
			currentMenu = name
		endif
		declWave[idx][0] = createMarkerForType(def)
		declWave[idx][1] = "Menu " + currentMenu
		if(!cmpstr(def, "submenu"))
			declWave[idx][1] += ":" + name
		endif
		if(cmpstr(type, ""))
			declWave[idx][1] += "(" + type + ")"
		endif

		lineWave[idx] = wavLineNumber[(idx - numEntries)]
	endfor
End

// input wave (wavStructure) contains text of Structure lineseparated.
// wavStructure begins with "Structure" definition in first line and ends with "EndStructure" in last line.
Function/S getStructureElements(wavStructure)
	WAVE/T wavStructure
	String regExp = "", strType
	String lstVariables, lstTypes, lstNames
	Variable numElements, numMatches, numVariables, i, j

	// check for minimum structure definition structure/endstructure
	numElements = Dimsize(wavStructure, 0)
	if(numElements <= 2)
		DebugPrint("Structure has no Elements")
		return ""
	endif

	// search code and return wavLineNumber and wavContent
	Duplicate/T/FREE/R=[1, (numElements - 1)] wavStructure wavContent
	regExp = "^(?i)[[:space:]]*(" + cstrTypes + ")[[:space:]]+(?:\/[a-z]+[[:space:]]*)*([^\/]*)(?:[\/].*)?"
	Grep/Q/INDX/E=regExp wavContent
	Wave W_Index
	Duplicate/FREE W_Index wavLineNumber
	KillWaves/Z W_Index
	KillStrings/Z S_fileName
	WaveClear W_Index
	if(!V_Value) // no matches
		DebugPrint("Structure with no Elements found")
		return "()"
	endif

	// extract Variable types and names inside each content line to return lstTypes and lstNames
	lstTypes = ""
	lstNames = ""
	numMatches = DimSize(wavLineNumber, 0)
	for(i = 0; i < numMatches; i += 1)
		SplitString/E=regExp wavContent[(wavLineNumber[i])], strType, lstVariables
		numVariables = ItemsInList(lstVariables, ",")
		for(j = 0; j < numVariables; j += 1)
			lstTypes = AddListItem(strType, lstNames)
			lstNames = AddListItem(getVariableName(StringFromList(j, lstVariables, ",")), lstNames)
		endfor
	endfor

	// sort elements depending on checkbox status
	lstNames = RemoveEnding(lstNames, ", ") // do not sort last element.
	if(returnCheckBoxSort())
		lstNames = Sortlist(lstNames, ", ",16)
	endif

	// format output
	lstTypes = RemoveEnding(lstTypes, ";")
	lstNames = RemoveEnding(lstNames, ";")
	lstNames = ReplaceString(";", lstNames, ", ")
	lstTypes = ReplaceString(";", lstTypes, ", ")

	return "{" + lstNames + "}"
End

Function/S getVariableName(strDefinition)
	String strDefinition
	String strVariableName, strStartValue
	String regExp

	regExp = "^(?i)[[:space:]]*([^\=\/[:space:]]+)[[:space:]]*(?:\=[[:space:]]*([^\,\=\/[:space:]]+))?.*"
	SplitString/E=regExp strDefinition, strVariableName, strStartValue

	// there must be sth. wrong if the variable could not be found.
	if(strlen(strVariableName) == 0)
		DebugPrint("Could not analyze Name of Variable in String: '" + strDefinition + "'")
		Abort "Could not analyze Name of Variable in String: " + strDefinition
	endif

	return	 strVariableName
End

static Function resetLists(decls, lines)
	Wave/T decls
	Wave/D lines
	Redimension/N=(0, -1) decls, lines
End

static Function sortListByLineNumber(decls, lines)
	Wave/T decls
	Wave/D lines

	// check if sort is necessary
	if(Dimsize(decls, 0) * Dimsize(lines, 0) == 0)
		return 0
	endif

	Duplicate/T/FREE/R=[][0] decls, declCol0
	Duplicate/T/FREE/R=[][1] decls, declCol1
	Sort/A lines, lines, declCol0, declCol1
	decls[][0] = declCol0[p][0]
	decls[][1] = declCol1[p][0]
End

static Function sortListByName(decls, lines)
	Wave/T decls
	Wave/D lines

	// check if sort is necessary
	if(Dimsize(decls, 0) * Dimsize(lines, 0) == 0)
		return 0
	endif

	Duplicate/T/FREE/R=[][0] decls, declCol0
	Duplicate/T/FREE/R=[][1] decls, declCol1
	Sort/A declCol1, lines, declCol0, declCol1
	decls[][0] = declCol0[p][0]
	decls[][1] = declCol1[p][0]
End

// Parses all procedure windows and write into the decl and line waves
Function/S parseProcedure(procedure, [checksumIsCalculated])
	STRUCT procedure &procedure
	Variable checkSumIsCalculated

	if(ParamIsDefault(checksumIsCalculated))
		checkSumIsCalculated = 0
	endif
	if(!checkSumIsCalculated)
		DebugPrint("CheckSum needs to be calculated")
	endif

	// start timer
	Variable timer = timerStart()

	// load global lists
	Wave/T decls = getDeclWave()
	Wave/I lines = getLineWave()

	// scan and add elements to lists
	resetLists(decls, lines)
	addDecoratedFunctions(procedure.module, procedure.fullName, decls, lines)
	addDecoratedConstants(procedure.module, procedure.name, decls, lines)
	addDecoratedMacros(procedure.module, procedure.name, decls, lines)
	addDecoratedStructure(procedure.module, procedure.name, decls, lines)
	addDecoratedMenu(procedure.module, procedure.name, decls, lines)

	// stop timer
	setParsingTime(timerStop(timer))
End

// Identifier = module#procedure
static Function saveResults(procedure)
	STRUCT procedure &procedure

	Wave/T declWave = getDeclWave()
	Wave/I lineWave = getLineWave()

	Wave/WAVE SaveWavesWave     = getSaveWaves()
	Wave/T 	  SaveStringsWave   = getSaveStrings()
	Wave      SaveVariablesWave	= getSaveVariables()

	Variable endOfWave = Dimsize(SaveWavesWave, 0)

	debugPrint("saving Results for " + procedure.id)

	// prepare Waves for data storage.
	if(procedure.row < 0)
		// maximum data storage was reached, push elements to free last item.
		savePush()
		procedure.row = endOfWave - 1
	elseif(procedure.row == endOfWave)
		// redimension waves to fit new elements
		Redimension/N=((endOfWave + 1), -1) SaveStringsWave
		Redimension/N=((endOfWave + 1), -1) SaveWavesWave
		Redimension/N=((endOfWave + 1), -1) SaveVariablesWave
	endif

	// save Results. Waves as References to free waves and the Id-Identifier
	Duplicate/FREE declWave myFreeDeclWave
	Duplicate/FREE lineWave myFreeLineWave
	SaveStringsWave[procedure.row][0] 	= procedure.id
	SaveStringsWave[procedure.row][1] 	= getChecksum()
	SaveWavesWave[procedure.row][0] = myFreeDeclWave
	SaveWavesWave[procedure.row][1] = myFreeLineWave
	SaveVariablesWave[procedure.row][0] = 1 // mark as valid
	SaveVariablesWave[procedure.row][1] = getParsingTime() // time in micro seconds
	SaveVariablesWave[procedure.row][2] = getCheckSumTime() // time in micro seconds

	// if function list could not be acquired don't save the checksum
	if(!DimSize(declWave, 0) || !cmpstr(declWave[0][1], "Procedures Not Compiled()")) ///@todo check in all rows.
		DebugPrint("Function list is not complete")
		SaveStringsWave[procedure.row][1] = "no checksum"
	endif
End

// Load the specified procedure from storage waves
//
// return errorCode
//         1 Load successfull
//         0 save state loaded with zero elements
//        -1 Could not load save state
//        -2 CheckSum missmatch. CheckSum has been calculated and was stored in
//           global variable
static Function saveLoad(procedure)
	STRUCT procedure &procedure

	Variable numResults
	string CheckSum

	Wave/T declWave = getDeclWave()
	Wave/I lineWave = getLineWave()

	Wave/WAVE SaveWavesWave     = getSaveWaves()
	Wave/T    SaveStringsWave   = getSaveStrings()
	Wave      SaveVariablesWave	= getSaveVariables()

	// if maximum storage capacity was reached (procedure.row == -1) or
	// Element not found (procedure.row == endofWave) --> nothing loadable
	if((procedure.row < 0) || (procedure.row == Dimsize(SaveStringsWave, 0)) || (Dimsize(SaveStringsWave, 0) == 0))
		debugPrint("save state not found")
		return -1
	endif
	if(isCompiled() && !SaveVariablesWave[procedure.row][0])
		// procedure marked as not valid by
		// AfterCompiledHook --> updatePanel --> saveReParse
		// --> CheckSum needs to be compared.

		if(!setChecksum(procedure))
			debugPrint("error creating CheckSum")
			return -1
		endif
		CheckSum = getCheckSum()
		if(!!cmpstr(SaveStringsWave[procedure.row][1], CheckSum))
			debugPrint("CheckSum missmatch: Procedure has to be reloaded.")
			return -2
		endif
		debugPrint("CheckSum match: " + CheckSum)

		SaveVariablesWave[procedure.row][0] = 1
		debugPrint("Procedure " + procedure.fullname + " marked as valid.")
	endif

	numResults = Dimsize(SaveWavesWave[procedure.row][0], 0)
	Redimension/N=(numResults, -1) declWave, lineWave
	if(numResults == 0)
		debugPrint("no elements in save state")
		return 0
	endif

	WAVE/T load0 = SaveWavesWave[procedure.row][0]
	WAVE/I load1 = SaveWavesWave[procedure.row][1]
	declWave[][0] = load0[p][0]
	declWave[][1] = load0[p][1]
	lineWave[] = load1[p]

	debugPrint("save state loaded successfully")
	return 1
End

//	Identifier = module#procedure
static Function getSaveRow(Identifier)
	String Identifier

	Wave/T SaveStrings = getSaveStrings()
	Variable found, endOfWave, element

	FindValue/TEXT=Identifier/TXOP=4/Z SaveStrings
	if(V_Value == -1)
		debugPrint("Element not found")
		return Dimsize(SaveStrings, 0)
	endif
	element = V_Value

	// check for inconsistency.
	if(element > CsaveMaximum )
		debugPrint("Storage capacity exceeded")
		// should only happen if(CsaveMaximum) was touched on runtime.
		// Redimension/Deletion of Wave could be possible.
		return (CsaveMaximum - 1)
	endif

	return element
End

// drop first item at position 0. push all elements upward by 1 element. Free last Position.
static Function savePush()
	Wave/T SaveStrings = getSaveStrings()
	Wave/WAVE SaveWavesWave = getSaveWaves()
	Wave SaveVariables = getSaveVariables()
	Variable i, endOfWave = Dimsize(SaveStrings, 0)

	// moving items.
	MatrixOp/O SaveVariables = rotateRows(SaveVariables, (endofWave - 1))
	// MatrixOP is strictly numeric (but fast)
	for(i=0; i<endofWave;i+=1)
		SaveWavesWave[i][]	= SaveWavesWave[(i + 1)][q]
		SaveStrings[i][] 	= SaveStrings[(i + 1)][q]
	endfor
End

Function saveReParse()
	Wave savedVariables = getSaveVariables()
	savedVariables[][0] = 0
End

// Kill all storage objects
//
// note: if objects are in use they can not be killed.
// 		 therefore the function resets all variables before killing
Function KillStorage()
	Wave savedVariablesWave = getSaveVariables()
	Wave/T SavedStringsWave = getSaveStrings()
	Wave/WAVE SavedWavesWave = getSaveWaves()

	// reset
	saveReParse()
	setGlobalStr("parsingChecksum", "")
	setGlobalVar("checksumTime", NaN)
	setGlobalVar("parsingTime", NaN)

	// kill
	Killwaves/Z savedVariablesWave, SavedStringsWave, SavedWavesWave
	killGlobalStr("parsingChecksum")
	killGlobalVar("checksumTime")
	killGlobalvar("parsingTime")
End

/// @brief Return a list of procedures with the module suffix " [.*]" removed
//
/// @see ProcedureListRemoveEnding
Function/S ProcedureListRemoveModule(list)
	string list

	variable i, idx
	string item, niceList=""

	for(i = 0; i < ItemsInList(list); i += 1)
		item = StringFromList(i, list)
		item = RemoveEverythingAfter(item, " [")
		niceList = AddListItem(item, niceList, ";", inf)
	endfor

	return niceList
End

/// @brief Return a list of procedures with the ending ".ipf" removed
//
/// @see ProcedureListRemoveModule
Function/S ProcedureListRemoveEnding(list)
	string list

	variable i, idx
	string item, niceList=""

	for(i = 0; i < ItemsInList(list); i += 1)
		item = StringFromList(i, list)
		item = RemoveEverythingAfter(item, ".ipf")
		niceList = AddListItem(item, niceList, ";", inf)
	endfor

	return niceList
End

// Get the specified line of code from a function
//
// @see getProcedureText
//
// @param funcInfo  output of FunctionInfo for the function in question
// @param lineNo    line number relative to the function definition
//                  set to -1 to return lines before the procedure that are not part of the preceding macro or function
//                  see `DisplayHelpTopic("ProcedureText")`
//
// @returns lines of code from a function inside a procedure file
Function/S getFunctionLine(lineNo, funcInfo)
	variable lineNo
	string funcInfo

	string funcName, module, procedure, context
	variable linesOfContext

	funcName = StringByKey("NAME", funcInfo)
	module = StringByKey("INDEPENDENTMODULE", funcInfo)
	procedure = StringByKey("PROCWIN", funcInfo)

	linesOfContext = lineNo < 0 ? lineNo : 0
	context = getProcedureText(funcName, linesOfContext, module, procedure)

	if(lineNo < 0)
		return context
	endif

	return StringFromList(lineNo, context, "\r")
End

// get code of procedure in module
//
// see `DisplayHelpTopic("ProcedureText")`
//
// @param funcName       Name of Function. Leave blank to get full procedure text
// @param linesOfContext line numbers in addition to the function definition. Set to 0 to return only the function.
//                       set to -1 to return lines before the procedure that are not part of the preceding macro or function
// @param module         independent module
// @param procedure      procedure without module definition
// @return multi-line string with function definition
Function/S getProcedureText(funcName, linesOfContext, module, procedure)
	string funcName, module, procedure
	variable linesOfContext

	if(!isProcGlobal(module))
		debugPrint(procedure + " is not in ProcGlobal")
		procedure = procedure + " [" + module + "]"
	endif

	return ProcedureText(funcName, linesOfContext, procedure)
End

// Returns 1 if the procedure file has content which we can show, 0 otherwise
Function updateListBoxHook()
	STRUCT procedure procedure
	Variable returnState

	String searchString = ""

	// load global lists (for sort)
	Wave/T decls = getDeclWave()
	Wave/I lines = getLineWave()

	// get procedure information
	procedure.fullName = getCurrentItem(procedure = 1)
	procedure.name     = ProcedureWithoutModule(procedure.fullName)
	procedure.module   = ModuleWithoutProcedure(procedure.fullName)
	procedure.id       = procedure.module + "#" + RemoveEverythingAfter(procedure.name, ".ipf")
	procedure.row      = getSaveRow(procedure.id)

	// load procedure
	returnState = saveLoad(procedure)
	if(returnState < 0)
		debugPrint("parsing Procedure")
		parseProcedure(procedure)
		// return state -2 means checksum already calculated and stored in global variable.
		if(!(returnState == -2))
			setCheckSum(procedure)
		endif
		// save information in "database"
		saveResults(procedure)
	endif

	// check if search is necessary
	searchString = getGlobalStr("search")
	if(strlen(searchString) > 0)
		searchAndDelete(decls, lines, searchString)
	endif

	// switch sort type
	if(returnCheckBoxSort())
		sortListByName(decls, lines)
	else
		sortListByLineNumber(decls, lines)
	endif

	return DimSize(decls, 0)
End

Function searchAndDelete(decls, lines, searchString)
	Wave/T decls
	Wave/I lines
	String searchString

	Variable i, numEntries

	numEntries = Dimsize(decls, 0)
	if(numEntries == 0)
		return 0
	endif

	for(i = numEntries - 1; i > 0; i -= 1)
		if(strsearch(decls[i][1], searchString, 0, 2) == -1)
			DeletePoints/M=0 i, 1, decls, lines
		endif
	endfor

	// prevent loss of dimension if no match was found at all.
	if(strsearch(decls[0][1], searchString, 0, 2) == -1)
		if(Dimsize(decls, 0) == 1)
			Redimension/N=(0, -1) decls, lines
		else
			DeletePoints/M=0 i, 1, decls, lines
		endif
	endif
End

Function DeletePKGfolder()
	if(CountObjects(pkgFolder, 1) + CountObjects(pkgFolder, 2) + CountObjects(pkgFolder, 3) == 0)
		KillDataFolder/Z $pkgFolder
	endif
	if(CountObjects("root:Packages", 4) == 0)
		KillDataFolder root:Packages
	endif
End

// Shows the line/function for the function/macro with the given index into decl
// With no index just the procedure file is shown
Function showCode(procedure, [index])
	string procedure
	variable index

	if(ParamIsDefault(index))
		DisplayProcedure/W=$procedure
		return NaN
	endif

	Wave/T decl  = getDeclWave()
	Wave/I lines = getLineWave()

	if(!(index >= 0) || index >= DimSize(decl, 0) || index >= DimSize(lines, 0))
		Abort "Index out of range"
	endif

	if(lines[index] < 0)
		string func = getShortFuncOrMacroName(decl[index][1])
		DisplayProcedure/W=$procedure func
	else
		DisplayProcedure/W=$procedure/L=(lines[index])
	endif
End

// Returns a list of all procedures windows in ProcGlobal context
Function/S getGlobalProcWindows()
	string procList = getProcWindows("*","INDEPENDENTMODULE:0")

	return AddToItemsInList(procList, suffix=" [ProcGlobal]")
End

// Returns a list of all procedures windows in the given independent module
Function/S getIMProcWindows(moduleName)
	string moduleName

	string regexp
	sprintf regexp, "* [%s]", moduleName
	return 	getProcWindows(regexp,"INDEPENDENTMODULE:1")
End

// Low level implementation, returns a sorted list of procedure windows matching regexp and options
Function/S getProcWindows(regexp, options)
	string regexp, options

	string procList = WinList(regexp, ";", options)
	return SortList(procList, ";", 4)
End

// Returns a list of independent modules
// Includes ProcGlobal but skips all WM modules and the current module in release mode
Function/S getModuleList()
	String moduleList

	moduleList = IndependentModuleList(";")
	moduleList = ListMatch(moduleList, "!WM*", ";") // skip WM modules
	moduleList = ListMatch(moduleList, "!RCP*", ";") // skip WM's Resize Controls modul
	String module = GetIndependentModuleName()

	moduleList = "ProcGlobal;" + SortList(moduleList)

	return moduleList
End

// Returns declarations: after parsing the object names and variables are stored in this wave.
// Return refrence to (text) Wave/T
Function/Wave getDeclWave()
	DFREF dfr = createDFWithAllParents(pkgFolder)
	WAVE/Z/T/SDFR=dfr wv = $declarations

	if(!WaveExists(wv))
		Make/T/N=(128, 2) dfr:$declarations/Wave=wv
	endif

	return wv
End

// Returns linenumbers: each parsing result of decl has a corresponding line number.
// Return refrence to (integer) Wave/I
Function/Wave getLineWave()
	DFREF dfr = createDFWithAllParents(pkgFolder)
	WAVE/Z/I/SDFR=dfr wv = $declarationLines

	if(!WaveExists(wv))
		Make/I dfr:$declarationLines/Wave=wv
	endif

	return wv
End

// 2D-Wave with Strings
// Return refrence to (string) Wave/T
static Function/Wave getSaveStrings()
	DFREF dfr = createDFWithAllParents(pkgFolder)
	WAVE/Z/T/SDFR=dfr wv = $CsaveStrings

	if(!WaveExists(wv))
		// Textwave:
		// Column 1: Id (Identification String)
		// Column 2: CheckSum
		Make/T/N=(0,2) dfr:$CsaveStrings/Wave=wv
	endif

	return wv
End

// 2D-Wave with references to Declaration- and LineNumber-Waves as free waves.
// Return refrence to (wave) Wave/WAVE
static Function/Wave getSaveWaves()
	DFREF dfr = createDFWithAllParents(pkgFolder)
	WAVE/Z/WAVE/SDFR=dfr wv = $CsaveWaves

	if(!WaveExists(wv))
		Make/WAVE/N=(0,2) dfr:$CsaveWaves/Wave=wv // wave of wave references
		// Wave with Free Waves:
		// Column 1: decl (a (text) Wave/T with the results of parsing the procedure file)
		// Column 1: line (a (integer) Wave/I with the corresponding line numbers within the procedure file)
	endif

	return wv
End

// 2D-Wave where Numbers can be stored.
// Return refrence to (numeric) Wave
static Function/Wave getSaveVariables()
	DFREF dfr = createDFWithAllParents(pkgFolder)
	WAVE/Z/SDFR=dfr wv = $CsaveVariables

	if(!WaveExists(wv))
		// Numeric Wave:
		// Column 1: valid (0: no, 1: yes) used to mark waves for parsing after "compile" was done.
		// Column 2: time for parsing (time consumption of compilation in us)
		// Column 3: time for checksum
		Make/N=(0,3) dfr:$CsaveVariables/Wave=wv
	endif

	return wv
End

// Get a list of all procedure files of the given independent module/ProcGlobal
//
// @param module    Independent Module or ProcGlobal Namespace
// @param addModule [optional, default 0] add the module to the list
//                  Module is added as Module#Procedure in a way similar to Module#Function()
Function/S getProcList(module, [addModule])
	string module
	variable addModule

	string procedures

	addModule = ParamIsDefault(addModule) ? 0 : !!addModule

	if(isProcGlobal(module))
		module = "ProcGlobal"
		procedures = getGlobalProcWindows()
	else
		procedures = getIMProcWindows(module)
	endif

	if(addModule)
		procedures = ProcedureListRemoveEnding(procedures)
		module = module + "#"
		procedures = AddToItemsInList(procedures, prefix=module)
	endif
	return procedures
End

static Function getParsingTime()
	return getGlobalVar("parsingTime")
End

static Function setParsingTime(numTime)
	Variable numTime

	debugPrint("parsing time:" + num2str(numTime))
	return setGlobalVar("parsingTime", numTime)
End

static Function getCheckSumTime()
	return getGlobalVar("checksumTime")
End

static Function setCheckSumTime(numTime)
	Variable numTime
	return setGlobalVar("checksumTime", numTime)
End

static Function setCheckSum(procedure)
	STRUCT procedure &procedure

	String procText, checksum
	Variable returnValue, timer

	timer = timerStart()

	procText = getProcedureText("", 0, procedure.module, procedure.name)
	returnValue = setGlobalStr("parsingChecksum", Hash(procText, 1))

	setCheckSumTime(timerStop(timer))

	return (returnValue == 1)
End

static Function/S getCheckSum()
	return getGlobalStr("parsingChecksum")
End

static Structure procedure
	String id
	Variable row
	String name
	String module
	String fullName
Endstructure
