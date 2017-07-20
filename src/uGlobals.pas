{   _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: uGlobals.pas
  / / __/ // / /  / _  / /| |  Desc: Global constants, types, variables
 /_/\__/\_,_/\___/____/___|_|
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution.  }

unit uGlobals;

interface

uses Classes, SysUtils, StrUtils, FileUtil, Windows;

const
  CAPIRevision = 1;
  CVersionMajor = 0;
  CVersionMinor = 1;

type
  u8  = byte;
  s8  = shortint;
  u16 = word;
  s16 = smallint;
  u32 = longword;
  s32 = longint;
  u64 = qword;
  s64 = int64;
  f32 = single;
  f64 = double;

  pu8  = ^u8;
  ps8  = ^s8;
  pu16 = ^u16;
  ps16 = ^s16;
  pu32 = ^u32;
  ps32 = ^s32;
  pu64 = ^u64;
  ps64 = ^s64;
  pf32 = ^f32;
  pf64 = ^f64;

  TValueType     = (vtU8, vtU16, vtU32, vtS8, vtS16, vtS32);
  TValueEncoding = (veDecimal, veHexadecimal, veBinary);

  TMemoryRegion = (mrBIOS, mrWRAM, mrIRAM, mrIO, mrPAL, mrVRAM, mrOAM, mrROM, mrEEPROM, mrFLASH);
  TMemoryAccess = (maRead, maWrite, maExecute);

var
  GCriticalSection: TRTLCriticalSection;

  GRegionBase:      array[TMemoryRegion] of u32 = ($00000000, $02000000, $03000000, $04000000, $05000000, $06000000, $07000000, $08000000, $0D000000, $0E000000);
  GRegionSize:      array[TMemoryRegion] of u32 = ($0, $0, $0, $0, $0, $0, $0, $0, $0, $0); // Initialised by the emulator
  GRegionName:      array[TMemoryRegion] of string = ('System ROM', 'External Working RAM', 'Internal Working RAM', 'I/O and Registers', 'Palette RAM', 'Video RAM', 'Object attribute RAM', 'Game Pak ROM', 'Game Pak RAM', 'Game Pak RAM');
  GRegionAbbr:      array[TMemoryRegion] of string = ('BIOS', 'WRAM', 'IRAM', 'IO', 'PAL', 'VRAM', 'OAM', 'ROM', 'EEPROM', 'FLASH');
  GRegionData:      array[TMemoryRegion] of pu8;
  GRegionAccessLog: array[TMemoryRegion] of array[TMemoryAccess] of array of u32;

  GValueNames:     array[TValueType] of string = ('8-bit unsigned', '16-bit unsigned', '32-bit unsigned', '8-bit signed', '16-bit signed', '32-bit signed');
  GValueEncodings: array[TValueEncoding] of string = ('Decimal', 'Hexadecimal', 'Binary');

function GetProjectPath: string;
function GBAAddressToPointer(AAddress: u32): pointer;
function ValueToString(AValue: pointer; AType: TValueType; AEncoding: TValueEncoding): string;
function U8ToString(AValue: u8; AEncoding: TValueEncoding = veDecimal): string;
function S8ToString(AValue: s8; AEncoding: TValueEncoding = veDecimal): string;
function U16ToString(AValue: u16; AEncoding: TValueEncoding = veDecimal): string;
function S16ToString(AValue: s16; AEncoding: TValueEncoding = veDecimal): string;
function U32ToString(AValue: u32; AEncoding: TValueEncoding = veDecimal): string;
function S32ToString(AValue: s32; AEncoding: TValueEncoding = veDecimal): string;
procedure StringToValue(AString: string; AValue: pointer; AType: TValueType; AEncoding: TValueEncoding);
function StringToU8(AString: string; AEncoding: TValueEncoding = veDecimal): u8;
function StringToS8(AString: string; AEncoding: TValueEncoding = veDecimal): s8;
function StringToU16(AString: string; AEncoding: TValueEncoding = veDecimal): u16;
function StringToS16(AString: string; AEncoding: TValueEncoding = veDecimal): s16;
function StringToU32(AString: string; AEncoding: TValueEncoding = veDecimal): u32;
function StringToS32(AString: string; AEncoding: TValueEncoding = veDecimal): s32;

implementation

function GetProjectPath: string;
  begin
    SetLength(Result, 256);
    FillByte(Result[1], 256, 0);
    GetModuleFileName(HINSTANCE, @Result[1], 256);
    Result := ExpandFileName(ExtractFilePath(Result) + '..');
  end;

function GBAAddressToPointer(AAddress: u32): pointer;
  var
    LRegion, LOffset: u32;
    LFoundRegion: TMemoryRegion;
    LFound: boolean;
  begin
    LRegion := AAddress shr 24;
    LOffset := AAddress and $00FFFFFF;

    LFound := True;
    case LRegion of
      0: LFoundRegion  := mrBIOS;
      2: LFoundRegion  := mrWRAM;
      3: LFoundRegion  := mrIRAM;
      4: LFoundRegion  := mrIO;
      5: LFoundRegion  := mrPAL;
      6: LFoundRegion  := mrVRAM;
      7: LFoundRegion  := mrOAM;
      8: LFoundRegion  := mrROM;
      13: LFoundRegion := mrEEPROM;
      14: LFoundRegion := mrFLASH;
      else LFound := False;
    end;

    if LFound and (GRegionData[LFoundRegion] <> nil) then Result := @GRegionData[LFoundRegion][LOffset mod GRegionSize[LFoundRegion]]
    else
      Result := nil;
  end;

function ValueToString(AValue: pointer; AType: TValueType; AEncoding: TValueEncoding): string;
  begin
    case AEncoding of
      veDecimal: begin
        case AType of
          vtU8: Result  := IntToStr(pu8(AValue)^);
          vtS8: Result  := IntToStr(ps8(AValue)^);
          vtU16: Result := IntToStr(pu16(AValue)^);
          vtS16: Result := IntToStr(ps16(AValue)^);
          vtU32: Result := IntToStr(pu32(AValue)^);
          vtS32: Result := IntToStr(ps32(AValue)^);
        end;
      end;
      veHexadecimal: begin
        case AType of
          vtU8, vtS8: Result   := IntToHex(pu8(AValue)^, 2);
          vtU16, vtS16: Result := IntToHex(pu16(AValue)^, 4);
          vtU32, vtS32: Result := IntToHex(pu32(AValue)^, 8);
        end;
      end;
      veBinary: begin
        case AType of
          vtU8, vtS8: Result   := IntToBin(pu8(AValue)^, 8);
          vtU16, vtS16: Result := IntToBin(pu16(AValue)^, 16);
          vtU32, vtS32: Result := intToBin(pu32(AValue)^, 32);
        end;
      end;
    end;
  end;

function U8ToString(AValue: u8; AEncoding: TValueEncoding = veDecimal): string;
  begin
    Result := ValueToString(@AValue, vtU8, AEncoding);
  end;

function S8ToString(AValue: s8; AEncoding: TValueEncoding = veDecimal): string;
  begin
    Result := ValueToString(@AValue, vtS8, AEncoding);
  end;

function U16ToString(AValue: u16; AEncoding: TValueEncoding = veDecimal): string;
  begin
    Result := ValueToString(@AValue, vtU16, AEncoding);
  end;

function S16ToString(AValue: s16; AEncoding: TValueEncoding = veDecimal): string;
  begin
    Result := ValueToString(@AValue, vtS16, AEncoding);
  end;

function U32ToString(AValue: u32; AEncoding: TValueEncoding = veDecimal): string;
  begin
    Result := ValueToString(@AValue, vtU32, AEncoding);
  end;

function S32ToString(AValue: s32; AEncoding: TValueEncoding = veDecimal): string;
  begin
    Result := ValueToString(@AValue, vtS32, AEncoding);
  end;

procedure StringToValue(AString: string; AValue: pointer; AType: TValueType; AEncoding: TValueEncoding);
  begin
    case AEncoding of
      veDecimal: begin
        case AType of
          vtU8: pu8(AValue)^   := u8(StrToInt(AString));
          vtS8: ps8(AValue)^   := s8(StrToInt(AString));
          vtU16: pu16(AValue)^ := u16(StrToInt(AString));
          vtS16: ps16(AValue)^ := s16(StrToInt(AString));
          vtU32: pu32(AValue)^ := u32(StrToInt64(AString));
          vtS32: ps32(AValue)^ := s32(StrToInt64(AString));
        end;
      end;
      veHexadecimal: begin
        case AType of
          vtU8, vtS8: pu8(AValue)^    := u8(Hex2Dec(AString));
          vtU16, vtS16: pu16(AValue)^ := u16(Hex2Dec(AString));
          vtU32, vtS32: pu32(AValue)^ := u32(Hex2Dec(AString));
        end;
      end;
      veBinary: begin
        case AType of
          vtU8, vtS8: pu8(AValue)^    := u8(Numb2Dec(AString, 2));
          vtU16, vtS16: pu16(AValue)^ := u16(Numb2Dec(AString, 2));
          vtU32, vtS32: pu32(AValue)^ := u32(Numb2Dec(AString, 2));
        end;
      end;
    end;
  end;

function StringToU8(AString: string; AEncoding: TValueEncoding = veDecimal): u8;
  begin
    StringToValue(AString, @Result, vtU8, AEncoding);
  end;

function StringToS8(AString: string; AEncoding: TValueEncoding = veDecimal): s8;
  begin
    StringToValue(AString, @Result, vtS8, AEncoding);
  end;

function StringToU16(AString: string; AEncoding: TValueEncoding = veDecimal): u16;
  begin
    StringToValue(AString, @Result, vtU16, AEncoding);
  end;

function StringToS16(AString: string; AEncoding: TValueEncoding = veDecimal): s16;
  begin
    StringToValue(AString, @Result, vtS16, AEncoding);
  end;

function StringToU32(AString: string; AEncoding: TValueEncoding = veDecimal): u32;
  begin
    StringToValue(AString, @Result, vtU32, AEncoding);
  end;

function StringToS32(AString: string; AEncoding: TValueEncoding = veDecimal): s32;
  begin
    StringToValue(AString, @Result, vtS32, AEncoding);
  end;

end.
