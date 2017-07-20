{   _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: uZoomControl.pas
  / / __/ // / /  / _  / /| |  Desc: Zooming bitmaps with pixel-drawing events
 /_/\__/\_,_/\___/____/___|_|
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution.  }

unit uZoomControl;

interface

uses
  Classes, SysUtils, Controls, LCLType, Math, BGRABitmapTypes, BGRABitmap, uGlobals;

type
  TPixelPaintEvent = function(Sender: TObject; APixel: PBGRAPixel): boolean of object;

  TZoomControl = class(TCustomControl)
  private
    FDragging: boolean;
    FLastMousePos: TPoint;
    FOnAfterPaint: TNotifyEvent;
    FOnBeforePaint: TNotifyEvent;
    FOnPaintPixel: TPixelPaintEvent;
    FBackBuffer: TBGRABitmap;
    FZoom: f64;
    FX, FY: f64;
    LCoordX, LCoordY: f64;

    procedure FSetTransparentPattern(APixel: PBGRAPixel; AX, AY: u32);
    procedure FCalcYVariables(AY: u32); virtual;
    procedure FCalcXVariables(AX: u32); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function CanFocus: boolean; override;

    procedure Paint; override;
    procedure EraseBackground(DC: HDC); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: integer; MousePos: TPoint): boolean; override;
    procedure DblClick; override;

    property X: f64 read FX write FX;
    property Y: f64 read FY write FY;
    property Zoom: f64 read FZoom write FZoom;

    property OnBeforePaint: TNotifyEvent read FOnBeforePaint write FOnBeforePaint;
    property OnAfterPaint: TNotifyEvent read FOnAfterPaint write FOnAfterPaint;
    property OnPaintPixel: TPixelPaintEvent read FOnPaintPixel write FOnPaintPixel;

    property CoordX: f64 read LCoordX;
    property CoordY: f64 read LCoordY;
  end;

  TBlockZoomControl = class(TZoomControl)
  private
    FBlocksPerLine: u32;
    FBlockWidth, FBlockHeight: u32;
    FBlockX, FBlockY: u32;
    FModX, FModY: f64;

    procedure FCalcYVariables(AY: u32); override;
    procedure FCalcXVariables(AX: u32); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property BlockWidth: u32 read FBlockWidth write FBlockWidth;
    property BlockHeight: u32 read FBlockHeight write FBlockHeight;
    property BlocksPerLine: u32 read FBlocksPerLine write FBlocksPerLine;

    property BlockX: u32 read FBlockX;
    property BlockY: u32 read FBlockY;
    property ModX: f64 read FModX;
    property ModY: f64 read FModY;
  end;

implementation

constructor TZoomControl.Create(AOwner: TComponent);
  begin
    inherited Create(AOwner);
    FBackBuffer := TBGRABitmap.Create;
    FX := 0;
    FY := 0;
    FZoom := 1;
  end;

destructor TZoomControl.Destroy;
  begin
    inherited Destroy;
    FBackBuffer.Free;
  end;

procedure TZoomControl.FSetTransparentPattern(APixel: PBGRAPixel; AX, AY: u32);
  begin
    if ((AX + AY) div 4) mod 2 = 0 then APixel^ := BGRA(15, 15, 15)
    else
      APixel^ := BGRA(10, 10, 10);
  end;

procedure TZoomControl.FCalcYVariables(AY: u32);
  begin
    LCoordY := FY + AY / FZoom;
  end;

procedure TZoomControl.FCalcXVariables(AX: u32);
  begin
    LCoordX := FX + AX / FZoom;
  end;

function TZoomControl.CanFocus: boolean;
  begin
    Result := True;
  end;

procedure TZoomControl.Paint;
  var
    LX, LY: integer;
    LPixel: PBGRAPixel;
  begin
    inherited Paint;

    if Assigned(FOnBeforePaint) then FOnBeforePaint(Self);

    FBackBuffer.SetSize(Width, Height);
    LPixel := FBackBuffer.Data;

    // FOnPaintPixel assigned
    if Assigned(FOnPaintPixel) then begin
      for LY := Height - 1 downto 0 do begin
        FCalcYVariables(LY);
        for LX := 0 to Width - 1 do begin
          FCalcXVariables(LX);
          if not FOnPaintPixel(Self, LPixel) then FSetTransparentPattern(LPixel, LX, LY);
          Inc(LPixel);
        end;
      end;
    end
    // No FOnPaintPixel, transparent
    else begin
      for LY := Height - 1 downto 0 do begin
        for LX := 0 to Width - 1 do begin
          FSetTransparentPattern(LPixel, LX, LY);
          Inc(LPixel);
        end;
      end;
    end;

    FBackBuffer.InvalidateBitmap;
    FBackBuffer.Draw(Canvas, 0, 0, True);

    if Assigned(FOnAfterPaint) then FOnAfterPaint(Self);
  end;

procedure TZoomControl.EraseBackground(DC: HDC);
  begin
    //inherited EraseBackground(DC); // Don't erase the background
  end;

procedure TZoomControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
  begin
    inherited MouseDown(Button, Shift, X, Y);
    if Button = mbLeft then begin
      FDragging := True;
      FLastMousePos.X := X;
      FLastMousePos.Y := Y;
      SetFocus; // Makes zooming faster somehow (TODO: investigate)
    end;
  end;

procedure TZoomControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
  begin
    inherited MouseUp(Button, Shift, X, Y);
    if Button = mbLeft then begin
      FDragging := False;
    end;
  end;

procedure TZoomControl.MouseMove(Shift: TShiftState; X, Y: integer);
  var
    LDelta: TPoint;
  begin
    inherited MouseMove(Shift, X, Y);
    if FDragging then begin
      LDelta.X := X - FLastMousePos.X;
      LDelta.Y := Y - FLastMousePos.Y;

      FX := FX - LDelta.X / FZoom;
      FY := FY - LDelta.Y / FZoom;

      FLastMousePos.X := X;
      FLastMousePos.Y := Y;
      Invalidate;
    end;
  end;

function TZoomControl.DoMouseWheel(Shift: TShiftState; WheelDelta: integer; MousePos: TPoint): boolean;
  var
    LNewZoom: f64;
    LFactorX, LFactorY: f64;
  begin
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);

    if WheelDelta > 0 then LNewZoom := FZoom / 0.95;
    if WheelDelta < 0 then LNewZoom := FZoom * 0.95;

    LFactorX := MousePos.X / Width;
    LFactorY := MousePos.Y / Height;
    FX := FX + (Width / FZoom) * LFactorX - (Width / LNewZoom) * LFactorX;
    FY := FY + (Height / FZoom) * LFactorY - (Height / LNewZoom) * LFactorY;

    FZoom := LNewZoom;
    Invalidate;
  end;

procedure TZoomControl.DblClick;
  begin
    inherited DblClick;
    FZoom := 1;
    FX := 0;
    FY := 0;
    Invalidate;
  end;

constructor TBlockZoomControl.Create(AOwner: TComponent);
  begin
    inherited Create(AOwner);
    BlockWidth := 256;
    BlockHeight := 256;
    BlocksPerLine := 12;
  end;

destructor TBlockZoomControl.Destroy;
  begin
    inherited Destroy;
  end;

procedure TBlockZoomControl.FCalcXVariables(AX: u32);
  begin
    inherited FCalcXVariables(AX);
    FBlockX := Floor(LCoordX / FBlockWidth);
    FModX := LCoordX / FBlockWidth - FBlockX; // LCoordX fmod FBlockWidth
  end;

procedure TBlockZoomControl.FCalcYVariables(AY: u32);
  begin
    inherited FCalcYVariables(AY);
    FBlockY := Floor(LCoordY / FBlockHeight);
    FModY := LCoordY / FBlockHeight - FBlockY; // LCoordY fmod FBlockHeight
  end;

end.
