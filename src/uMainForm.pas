{   _          ________  ___
   (_)_____ __/ ___/ _ )/   |  File: uMainForm.pas
  / / __/ // / /  / _  / /| |  Desc: Main form of icuGBA
 /_/\__/\_,_/\___/____/___|_|
   Memory Analysis Tool for    For copyright details see the file LICENSE and
   Nintendo Game Boy Advance   AUTHORS included with the source distribution.  }

unit uMainForm;

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  ActnList, uGlobals, uMemoryViewerForm, uMemoryValueEditForm;

type
  TMainForm = class(TForm)
    AOpenAboutWindow: TAction;
    AOpenCustomDisplayWindow: TAction;
    AOpenMemoryWindow: TAction;
    ActionList: TActionList;
    ToolbarImageList: TImageList;
    MainToolBar: TToolBar;
    MemoryToolButton: TToolButton;
    AboutToolButton: TToolButton;
    procedure AOpenAboutWindowExecute(Sender: TObject);
    procedure AOpenMemoryWindowExecute(Sender: TObject);
  private
  public
  end;

implementation

{$R *.lfm}

procedure TMainForm.AOpenMemoryWindowExecute(Sender: TObject);
  var
    LNewForm: TMemoryViewerForm;
  begin
    LNewForm := TMemoryViewerForm.Create(Self);
    LNewForm.Show;
  end;

procedure TMainForm.AOpenAboutWindowExecute(Sender: TObject);
  begin
    // TODO: Make a proper about window
    ShowMessage(Format('icuGBA v%d.%d', [CVersionMajor, CVersionMinor]) + LineEnding + 'https://sourceforge.net/projects/icugba/');
  end;

end.
