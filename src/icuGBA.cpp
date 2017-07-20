/*  _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: icuGBA.cpp
  / / __/ // / /  / _  / /| |  Desc: Implementation file of the VBA-M wrapper
 /_/\__/\_,_/\___/____/___|_|  
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution. */

#include <windows.h>
#include "icuGBA.h"

picuGBA_InitialiseFunc icuGBA_Initialise;
picuGBA_TerminateFunc icuGBA_Terminate;
picuGBA_GetAPIRevisionFunc icuGBA_GetAPIRevision;
picuGBA_RegisterMemoryRegionFunc icuGBA_RegisterMemoryRegion;
picuGBA_MemoryAccessFunc icuGBA_MemoryAccess;

void icuGBA_InitDLL() {	
    HINSTANCE hGetProcIDDLL = LoadLibrary("icuGBA.dll"); 

	icuGBA_GetAPIRevision = (picuGBA_GetAPIRevisionFunc)(GetProcAddress(HMODULE(hGetProcIDDLL), "icuGBA_GetAPIRevision"));
	
	if (icuGBA_GetAPIRevision() == ICUGBA_API_RESIVION) {
		icuGBA_Initialise = (picuGBA_InitialiseFunc)(GetProcAddress(HMODULE(hGetProcIDDLL), "icuGBA_Initialise"));
		icuGBA_Terminate = (picuGBA_TerminateFunc)(GetProcAddress(HMODULE(hGetProcIDDLL), "icuGBA_Terminate"));
		icuGBA_RegisterMemoryRegion = (picuGBA_RegisterMemoryRegionFunc)(GetProcAddress(HMODULE(hGetProcIDDLL), "icuGBA_RegisterMemoryRegion"));
		icuGBA_MemoryAccess = (picuGBA_MemoryAccessFunc)(GetProcAddress(HMODULE(hGetProcIDDLL), "icuGBA_MemoryAccess"));
	} else {
		MessageBox(NULL, "Incompatible icuGBA.dll API revision.", "icuGBA", MB_ICONERROR | MB_OK | MB_DEFBUTTON1);
		exit(1);
	};	
}
