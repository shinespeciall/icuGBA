{   _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: uMemoryViewerForm.pas
  / / __/ // / /  / _  / /| |  Desc: GBA memory viewer form
 /_/\__/\_,_/\___/____/___|_|
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution.  }

unit uMemoryViewerForm;

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Menus, ActnList, Windows, Math, BGRABitmap,
  BGRABitmapTypes, uGlobals, uZoomControl, uMemoryValueEditForm;

type
  TMemoryViewerStates = (mvmRead, mvmWrite, mvmExecute, mvmValue, mvmGlyphs, mvmHexa);
  TMemoryViewerState = set of TMemoryViewerStates;

  TMemoryViewerForm = class(TForm)
    AClear: TAction;
    AShowHelp: TAction;
    AEditMemory: TAction;
    ATestIncreaseBlockPerLine: TAction;
    ATestDecreaseBlocksPerLine: TAction;
    ATestIncreaseBlockHeight: TAction;
    ATestDecreaseBlockHeight: TAction;
    ATestIncreaseBlockWidth: TAction;
    ATestDecreaseBlockWidth: TAction;
    AToggleValue: TAction;
    AToggleGlyphs: TAction;
    AToggleHex: TAction;
    AToggleExecute: TAction;
    AToggleWrite: TAction;
    AToggleRead: TAction;
    ActionList: TActionList;
    RegionComboBox: TComboBox;
    PopupImageList: TImageList;
    MenuItemToggleRead: TMenuItem;
    MenuItemSeparator1: TMenuItem;
    MenuItemEditMemory: TMenuItem;
    MenuItemToggleWrite: TMenuItem;
    MenuItemToggleExecute: TMenuItem;
    MenuItemSeparator3: TMenuItem;
    MenuItemToggleHex: TMenuItem;
    MenuItemToggleGlyphs: TMenuItem;
    MenuItemClear: TMenuItem;
    MenuItemSeparator2: TMenuItem;
    MenuItemToggleValue: TMenuItem;
    PopupMenu1: TPopupMenu;
    RedrawTimer: TTimer;
    procedure AClearExecute(Sender: TObject);
    procedure AEditMemoryExecute(Sender: TObject);
    procedure AEditMemoryUpdate(Sender: TObject);
    procedure ATestExecute(Sender: TObject);
    procedure AToggleOptionExecute(Sender: TObject);
    procedure RegionComboBoxChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure RedrawTimerTimer(Sender: TObject);
    procedure ZoomControlBeforePaint(Sender: TObject);
    procedure ZoomControlMouseLeave(Sender: TObject);
    procedure ZoomControlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
    function ZoomControlPaintPixel(Sender: TObject; APixel: PBGRAPixel): boolean;
    procedure ZoomControlAfterPaint(Sender: TObject);
  private
    FState: TMemoryViewerState;         // Read / write / execute etc.
    FSelectedRegion: TMemoryRegion;     // Selected memory region
    FTimeStampFrom, FTimeStampNow: u32; // Timestamps for colouring
    FZoomControl: TBlockZoomControl;
    FIsMemorySelected: boolean;
    FSelectedMemory: u32;
    FCharacterSet: TBGRABitmap;         // Used character set TODO: application-wise
    procedure FFillRegionComboBox(Sender: TObject);
    procedure FRefreshWindowCaption(Sender: TObject);
  public
  end;

implementation

{$R *.lfm}

function TMemoryViewerForm.ZoomControlPaintPixel(Sender: TObject; APixel: PBGRAPixel): boolean;
  const
    CHexadecimal: string = '0123456789abcdef';
  var
    LMemoryAddress: u32;
    LMemoryValue: u8;
    LColourValue: u8;

  function LGetColour(LNow, LAccessTimestamp: DWord): u8;
    const
      CMaxLevel = 255; // Max colour value
      CMinLevel = 32;  // Min colour value for accessed addresses
    var
      LDelta: s32; // Difference between Now and the last memory access
      LN: f64;     // Interpolation parameter
    begin
      LDelta := LNow - LAccessTimestamp;
      if (LAccessTimestamp <= FTimeStampFrom) then Result := 0
      else begin
        if LDelta > 2500 then Result := CMinLevel
        else if LDelta < 0 then Result := CMaxLevel // Időközben változhatott a legutóbbi hozzáférés ideje, mert a memóriahozzáférést nem kötjük meg CriticalSection-nel
        else begin
          LN := 1 - Power(1 - LDelta / 2500, 3); // Inverse cubed interpolation, 2.5 seconds
          Result := Round(CMinLevel * LN + CMaxLevel * (1 - LN));
        end;
      end;

    end;

  function LAdd_u8(ATo: u8; AValue: u8): u8;
    begin
      Result := EnsureRange(ATo + AValue, 0, 255);
    end;

  procedure LDrawCharacter(APixel: PBGRAPixel; AX, AY, ALeft, ATop, AWidth, AHeight: f64; ACharacter: u8);
    var
      LPixel: TBGRAPixel;
    begin
      if (AX < ALeft) or (AY < ATop) or (AX >= ALeft + AWidth) or (AY >= ATop + AHeight) then exit;

      LPixel := FCharacterSet.GetPixel(integer((ACharacter mod 16) * 8 + Floor((AX - ALeft) / AWidth * 8)), (ACharacter div 16) * 8 + Floor((AY - ATop) / AHeight * 8));

      APixel^.red := LAdd_u8(APixel^.red, LPixel.red div 2);
      APixel^.green := LAdd_u8(APixel^.green, LPixel.green div 2);
      APixel^.blue := LAdd_u8(APixel^.blue, LPixel.blue div 2);
    end;

  begin
    if GRegionData[FSelectedRegion] = nil then begin
      Result := False;
      exit;
    end;

    with Sender as TBlockZoomControl do begin
      LMemoryAddress := BlockWidth * (BlockHeight * (BlocksPerLine * BlockY + BlockX) + Trunc(ModY * BlockHeight)) + Trunc(ModX * BlockWidth);
      if (CoordX >= 0) and (CoordY >= 0) and (BlockX < BlocksPerLine) and (LMemoryAddress < GRegionSize[FSelectedRegion]) then begin
        // Init colour
        Result := True;
        APixel^.red := 0;
        APixel^.green := 0;
        APixel^.blue := 0;

        // Memory value
        if mvmValue in FState then begin
          LColourValue := GRegionData[FSelectedRegion][LMemoryAddress] div 4;
          APixel^.red := LAdd_u8(APixel^.red, LColourValue);
          APixel^.green := LAdd_u8(APixel^.green, LColourValue);
          APixel^.blue := LAdd_u8(APixel^.blue, LColourValue);
        end;

        // Read
        if mvmRead in FState then begin
          LColourValue := LGetColour(FTimeStampNow, GRegionAccessLog[FSelectedRegion][maRead][LMemoryAddress]);
          APixel^.green := LAdd_u8(APixel^.green, LColourValue);
        end;

        // Write
        if mvmWrite in FState then begin
          LColourValue := LGetColour(FTimeStampNow, GRegionAccessLog[FSelectedRegion][maWrite][LMemoryAddress]);
          APixel^.red := LAdd_u8(APixel^.red, LColourValue);
        end;

        // Execute
        if mvmExecute in FState then begin
          LColourValue := LGetColour(FTimeStampNow, GRegionAccessLog[FSelectedRegion][maExecute][LMemoryAddress]);
          APixel^.blue := LAdd_u8(APixel^.blue, LColourValue);
        end;

        if Zoom >= 8 then begin
          LMemoryValue := GRegionData[FSelectedRegion][LMemoryAddress];
          if (mvmGlyphs in FState) and (mvmHexa in FState) then begin
            LDrawCharacter(APixel, frac(CoordX), frac(CoordY), 0, 0, 0.5, 0.5, Ord(CHexadecimal[LMemoryValue div 16 + 1]));
            LDrawCharacter(APixel, frac(CoordX), frac(CoordY), 0.5, 0, 0.5, 0.5, Ord(CHexadecimal[LMemoryValue mod 16 + 1]));
            LDrawCharacter(APixel, frac(CoordX), frac(CoordY), 0.25, 0.5, 0.5, 0.5, LMemoryValue);
          end
          else if (mvmGlyphs in FState) then begin
            LDrawCharacter(APixel, frac(CoordX), frac(CoordY), 0, 0, 1, 1, LMemoryValue);
          end
          else if (mvmHexa in FState) then begin
            LDrawCharacter(APixel, frac(CoordX), frac(CoordY), 0, 0.25, 0.5, 0.5, Ord(CHexadecimal[LMemoryValue div 16 + 1]));
            LDrawCharacter(APixel, frac(CoordX), frac(CoordY), 0.5, 0.25, 0.5, 0.5, Ord(CHexadecimal[LMemoryValue mod 16 + 1]));
          end;
        end;

      end
      else
        Result := False;

    end;
  end;

procedure TMemoryViewerForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
  begin
    CloseAction := caFree;
  end;

procedure TMemoryViewerForm.RegionComboBoxChange(Sender: TObject);
  begin
    FSelectedRegion := TMemoryRegion((Sender as TComboBox).ItemIndex);
    // Deselect memory address
    FIsMemorySelected := False;
    FSelectedMemory := 0;
    FRefreshWindowCaption(Sender);
  end;

procedure TMemoryViewerForm.AClearExecute(Sender: TObject);
  begin
    FTimeStampFrom := GetTickCount;
  end;

procedure TMemoryViewerForm.AEditMemoryExecute(Sender: TObject);
  var
    LForm: TMemoryValueEditForm;
  begin
    LForm := TMemoryValueEditForm.Create(Application.MainForm, FSelectedMemory);
    LForm.Show;
  end;

procedure TMemoryViewerForm.AEditMemoryUpdate(Sender: TObject);
  begin
    (Sender as TAction).Enabled := FIsMemorySelected;
  end;

procedure TMemoryViewerForm.ATestExecute(Sender: TObject);
  begin
    case (Sender as TAction).Tag of
      0: FZoomControl.BlockWidth := FZoomControl.BlockWidth - 1;
      1: FZoomControl.BlockWidth := FZoomControl.BlockWidth + 1;
      2: FZoomControl.BlockHeight := FZoomControl.BlockHeight - 1;
      3: FZoomControl.BlockHeight := FZoomControl.BlockHeight + 1;
      4: FZoomControl.BlocksPerLine := FZoomControl.BlocksPerLine - 1;
      5: FZoomControl.BlocksPerLine := FZoomControl.BlocksPerLine + 1;
    end;
  end;

procedure TMemoryViewerForm.AToggleOptionExecute(Sender: TObject);
  var
    LState: TMemoryViewerState;
  begin
    case (Sender as TAction).Tag of
      0: LState := [mvmRead];
      1: LState := [mvmWrite];
      2: LState := [mvmExecute];
      3: LState := [mvmValue];
      4: LState := [mvmHexa];
      5: LState := [mvmGlyphs];
      else LState := [];
    end;
    FState:=FState >< LState; // Jedi Code Format doesn't like xor set operation
  end;

procedure TMemoryViewerForm.FormCreate(Sender: TObject);
  begin
    FFillRegionComboBox(Sender);
    FZoomControl := TBlockZoomControl.Create(Self);
    with FZoomControl do begin
      Parent := Self;
      Align := alClient;
      OnPaintPixel := @ZoomControlPaintPixel;
      OnBeforePaint := @ZoomControlBeforePaint;
      OnAfterPaint := @ZoomControlAfterPaint;
      OnMouseMove := @ZoomControlMouseMove;
      OnMouseLeave := @ZoomControlMouseLeave;
      PopupMenu := PopupMenu1;
      Zoom := 1;
      Show;
    end;

    FTimeStampFrom := GetTickCount;
    FState := [mvmRead, mvmWrite, mvmExecute, mvmValue, mvmGlyphs, mvmHexa];

    // No memory selected
    FIsMemorySelected := False;
    FSelectedMemory := 0;
    FRefreshWindowCaption(Sender);

    // TODO: Application-wise
    FCharacterSet := TBGRABitmap.Create(GetProjectPath() + '/gfx/8x8_IBM437.png');
  end;

procedure TMemoryViewerForm.FormDestroy(Sender: TObject);
  begin
    FZoomControl.Free;
    FCharacterSet.Free;
  end;

procedure TMemoryViewerForm.RedrawTimerTimer(Sender: TObject);
  begin
    FZoomControl.Invalidate;
  end;

procedure TMemoryViewerForm.ZoomControlAfterPaint(Sender: TObject);
  begin
    LeaveCriticalSection(GCriticalSection);
  end;

procedure TMemoryViewerForm.ZoomControlBeforePaint(Sender: TObject);
  begin
    EnterCriticalSection(GCriticalSection);
    FTimeStampNow := GetTickCount;
  end;

procedure TMemoryViewerForm.ZoomControlMouseLeave(Sender: TObject);
  begin
    FIsMemorySelected := False;
    FSelectedMemory := 0;
    FRefreshWindowCaption(Sender);
  end;

procedure TMemoryViewerForm.ZoomControlMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
  var
    CX, CY: u32;
    MX, MY: u32;
    BX, BY: u32;
    LMemoryAddress: u32;
    LZC: TBlockZoomControl;
  begin
    LZC := Sender as TBlockZoomControl;

    // Cells
    CX := Floor(X / LZC.Zoom + LZC.X);
    CY := Floor(Y / LZC.Zoom + LZC.Y);

    // Block inner cells
    MX := CX mod LZC.BlockWidth;
    MY := CY mod LZC.BlockHeight;

    // Blocks
    BX := CX div LZC.BlockWidth;
    BY := CY div LZC.BlockHeight;

    LMemoryAddress := LZC.BlockWidth * (LZC.BlockHeight * (LZC.BlocksPerLine * BY + BX) + MY) + MX;

    // Update selected memory address
    if (CX < 0) or (CY < 0) or (BX > LZC.BlocksPerLine) or (LMemoryAddress > GRegionSize[FSelectedRegion]) then begin
      FIsMemorySelected := False;
      FSelectedMemory := 0;
    end
    else begin
      FIsMemorySelected := True;
      FSelectedMemory := GRegionBase[FSelectedRegion] + LMemoryAddress;
    end;
    FRefreshWindowCaption(Sender);

  end;

procedure TMemoryViewerForm.FFillRegionComboBox(Sender: TObject);
  var
    LIndex: TMemoryRegion;
  begin
    for LIndex := Low(TMemoryRegion) to High(TMemoryRegion) do begin
      RegionComboBox.Items.Add(Format('0x%.8x - %s (%s)', [GRegionBase[LIndex], GRegionName[LIndex], GRegionAbbr[LIndex]]));
    end;
    RegionComboBox.ItemIndex := 0;
  end;

procedure TMemoryViewerForm.FRefreshWindowCaption(Sender: TObject);
  begin
    if FIsMemorySelected then Caption := Format('Memory [0x%.8x]', [FSelectedMemory])
    else
      Caption := 'Memory';
  end;

end.
