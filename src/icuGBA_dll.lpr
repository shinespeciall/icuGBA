{   _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: icuGBA_dll.lpr
  / / __/ // / /  / _  / /| |  Desc: DLL entry point and exported functions
 /_/\__/\_,_/\___/____/___|_|
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution.  }

library icuGBA_dll;

uses
  Classes, Interfaces, Forms, Windows, uGlobals, uMainForm;

type
  TApplicationThread = class(TThread)
  private
  public
    procedure Execute; override;
  end;

var
  GApplicationThread: TApplicationThread;
  GMainForm: TMainForm;

  procedure TApplicationThread.Execute;
    begin
      MainThreadID := ThreadID;
      RequireDerivedFormResource := True;
      Application.Initialize;
      Application.CreateForm(TMainForm, GMainForm);
      Application.Run;
    end;

  procedure icuGBA_Initialise; stdcall;
    begin
      InitializeCriticalSection(GCriticalSection);
      GApplicationThread := TApplicationThread.Create(True);
      GApplicationThread.FreeOnTerminate := True;
      GApplicationThread.Start;
    end;

  procedure icuGBA_Terminate; stdcall;
    begin
      Application.Terminate;
      GApplicationThread.Terminate;
      //DeleteCriticalSection(GCriticalSection); // Causes access violation
    end;

  function icuGBA_GetAPIRevision: u32; stdcall;
    begin
      Result := CAPIRevision;
    end;

  procedure icuGBA_RegisterMemoryRegion(ARegionType: u8; AData: pointer; ASize: u32); stdcall;
    var
      LRegion: TMemoryRegion;
    begin
      EnterCriticalSection(GCriticalSection);
      try
        LRegion := TMemoryRegion(ARegionType);

        GRegionData[LRegion] := AData;
        GRegionSize[LRegion] := ASize;

        SetLength(GRegionAccessLog[LRegion][maRead], ASize);
        SetLength(GRegionAccessLog[LRegion][maWrite], ASize);
        SetLength(GRegionAccessLog[LRegion][maExecute], ASize);

        FillByte(GRegionAccessLog[LRegion][maRead][0], ASize, 0);
        FillByte(GRegionAccessLog[LRegion][maWrite][0], ASize, 0);
        FillByte(GRegionAccessLog[LRegion][maExecute][0], ASize, 0);
      finally
        LeaveCriticalSection(GCriticalSection);
      end;
    end;

  procedure icuGBA_MemoryAccess(AAccessType: u8; AAddress: u32; ASize: u32); stdcall;
    var
      LAddress: u32;
      LAccessType: TMemoryAccess;
      LRegion: TMemoryRegion;
    begin
      LAccessType := TMemoryAccess(AAccessType);
      for LRegion in TMemoryRegion do begin
        if (AAddress >= GRegionBase[LRegion]) and (AAddress < GRegionBase[LRegion] + GRegionSize[LRegion]) then begin
          LAddress := AAddress - GRegionBase[LRegion];
          // Fastest but not secure, may cause access violation errors (no wrapping)
          FillDWord(GRegionAccessLog[LRegion][LAccessType][LAddress], ASize, GetTickCount);
        end;
      end;
    end;

exports icuGBA_Initialise,
  icuGBA_Terminate,
  icuGBA_GetAPIRevision,
  icuGBA_RegisterMemoryRegion,
  icuGBA_MemoryAccess;

begin
end.
