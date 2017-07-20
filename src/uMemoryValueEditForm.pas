{   _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: uMemoryValueEditForm.pas
  / / __/ // / /  / _  / /| |  Desc: Form for modifying GBA memory values
 /_/\__/\_,_/\___/____/___|_|
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution.  }

unit uMemoryValueEditForm;

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, ActnList, StrUtils, uGlobals;

type
  TMemoryValueEditForm = class(TForm)
    AApply: TAction;
    AClose: TAction;
    ARefresh: TAction;
    ActionList1: TActionList;
    RefreshBitBtn: TBitBtn;
    ApplyBitBtn: TBitBtn;
    ComboBoxEncoding: TComboBox;
    ComboBoxType: TComboBox;
    Edit1: TEdit;
    procedure AApplyExecute(Sender: TObject);
    procedure AApplyUpdate(Sender: TObject);
    procedure ARefreshExecute(Sender: TObject);
    procedure ComboBoxEncodingChange(Sender: TObject);
    procedure ComboBoxTypeChange(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: char);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  private
    FMemoryAddress: u32;
    FValueEncoding: TValueEncoding;
    FValueType: TValueType;
    procedure SetValueEncoding(AValue: TValueEncoding);
    procedure SetValueType(AValue: TValueType);
    procedure FRefreshEdit(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent; AMemoryAddress: u32);
    property MemoryAddress: u32 read FMemoryAddress;
    property ValueType: TValueType read FValueType write SetValueType;
    property ValueEncoding: TValueEncoding read FValueEncoding write SetValueEncoding;
  end;

implementation

{$R *.lfm}

procedure TMemoryValueEditForm.ComboBoxEncodingChange(Sender: TObject);
  begin
    ValueEncoding := TValueEncoding((Sender as TComboBox).ItemIndex);
    FRefreshEdit(Sender);
  end;

procedure TMemoryValueEditForm.ARefreshExecute(Sender: TObject);
  begin
    FRefreshEdit(Sender);
  end;

procedure TMemoryValueEditForm.AApplyExecute(Sender: TObject);
  var
    LMemoryPointer: pointer;
  begin
    try
      LMemoryPointer := GBAAddressToPointer(FMemoryAddress); // NIL case checked in AApplyUpdate
      StringToValue(Edit1.Caption, LMemoryPointer, FValueType, FValueEncoding);
    except
      Beep;
    end;
  end;

procedure TMemoryValueEditForm.AApplyUpdate(Sender: TObject);
  begin
    (Sender as TAction).Enabled := GBAAddressToPointer(FMemoryAddress) <> nil;
  end;

procedure TMemoryValueEditForm.ComboBoxTypeChange(Sender: TObject);
  begin
    ValueType := TValueType((Sender as TComboBox).ItemIndex);
    FRefreshEdit(Sender);
  end;

procedure TMemoryValueEditForm.Edit1KeyPress(Sender: TObject; var Key: char);
  begin
    if Key = #13 then AApply.Execute;
  end;

procedure TMemoryValueEditForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
  begin
    CloseAction := caFree;
  end;

procedure TMemoryValueEditForm.SetValueEncoding(AValue: TValueEncoding);
  begin
    FValueEncoding := AValue;
    ComboBoxEncoding.ItemIndex := byte(AValue);
  end;

procedure TMemoryValueEditForm.SetValueType(AValue: TValueType);
  begin
    FValueType := AValue;
    ComboBoxType.ItemIndex := byte(AValue);
  end;

procedure TMemoryValueEditForm.FRefreshEdit(Sender: TObject);
  var
    LMemoryPointer: pointer;
  begin
    LMemoryPointer := GBAAddressToPointer(FMemoryAddress);

    if LMemoryPointer = nil then Edit1.Caption := ''
    else
      Edit1.Caption := ValueToString(LMemoryPointer, FValueType, FValueEncoding);
  end;

constructor TMemoryValueEditForm.Create(TheOwner: TComponent; AMemoryAddress: u32);
  var
    LValueType: TValueType;
    LValueEncoding: TValueEncoding;
  begin
    inherited Create(TheOwner);
    FMemoryAddress := AMemoryAddress;
    Caption := format('Editing 0x%.8x', [FMemoryAddress]);

    for LValueType in TValueType do ComboBoxType.Items.Add(GValueNames[LValueType]);
    for LValueEncoding in TValueEncoding do ComboBoxEncoding.Items.Add(GValueEncodings[LValueEncoding]);
    ValueEncoding := veHexadecimal;
    ValueType := vtU32;
    FRefreshEdit(Self);
  end;

end.
