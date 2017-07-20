/*  _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: icuGBA.h
  / / __/ // / /  / _  / /| |  Desc: Header of the VBA-M wrapper
 /_/\__/\_,_/\___/____/___|_|
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution. */

#ifndef ICUGBA_H
#define ICUGBA_H

#define ICUGBA_API_RESIVION 1

// Memory region defines
#define MR_BIOS 0
#define MR_WRAM 1
#define MR_IRAM 2
#define MR_IO   3
#define MR_PAL  4
#define MR_VRAM 5
#define MR_OAM  6
#define MR_ROM  7

// Memory access defines
#define MA_READ    0
#define MA_WRITE   1
#define MA_EXECUTE 2

//procedure icuGBA_Initalise; stdcall; 
typedef void (__stdcall *picuGBA_InitialiseFunc)();
extern picuGBA_InitialiseFunc icuGBA_Initialise;

//procedure icuGBA_Terminate; stdcall;
typedef void (__stdcall *picuGBA_TerminateFunc)();
extern picuGBA_TerminateFunc icuGBA_Terminate;

//function icuGBA_GetAPIRevision:u32; stdcall; 
typedef unsigned int (__stdcall *picuGBA_GetAPIRevisionFunc)();
extern picuGBA_GetAPIRevisionFunc icuGBA_GetAPIRevision;

//procedure icuGBA_RegisterMemoryRegion(ARegionType: u8; AData: pointer; ASize: u32); stdcall;  
typedef void (__stdcall *picuGBA_RegisterMemoryRegionFunc)(unsigned char ARegionType, void* AData, unsigned int ASize);
extern picuGBA_RegisterMemoryRegionFunc icuGBA_RegisterMemoryRegion;

//procedure icuGBA_MemoryAccess(AAccessType: u8; AAddress: u32; ASize:u32); stdcall; 
typedef void (__stdcall *picuGBA_MemoryAccessFunc)(unsigned char AAccessType, unsigned int AAddress, unsigned int ASize);
extern picuGBA_MemoryAccessFunc icuGBA_MemoryAccess;

void icuGBA_InitDLL();

#endif
