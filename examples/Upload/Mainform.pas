{ $Id$ } 
unit Mainform;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Menus, Buttons, Rawflickr, ComCtrls, ImgList, ToolWin,
  JPEG;

type
  TMain = class(TForm)
    OpenDialog: TOpenDialog;
    Bevel: TBevel;
    Image: TImage;
    MetaPanel: TPanel;
    lbTitle: TLabel;
    lbDescription: TLabel;
    lbTags: TLabel;
    lbSafety: TLabel;
    lbContent: TLabel;
    edTitle: TEdit;
    edDescription: TMemo;
    edTags: TMemo;
    gbVisibility: TGroupBox;
    cbPrivate: TCheckBox;
    cbGlobalHide: TCheckBox;
    cbFamily: TCheckBox;
    cbFriends: TCheckBox;
    cbSafety: TComboBox;
    cbContent: TComboBox;
    ToolBar: TToolBar;
    tbOpen: TToolButton;
    ToolImages: TImageList;
    tbUpload: TToolButton;
    tbSep1: TToolButton;
    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure tbOpenClick(Sender: TObject);
    procedure tbUploadClick(Sender: TObject);
  private
    { Private declarations }
    Flickr: TFlickrEx;
    UpFile: String;
    procedure FitImage;
  public
    { Public declarations }
  end;

var
  Main: TMain;

{$I APICONST.INC}

resourcestring
  sNoKey = 'You need a valid API key and secret to run this program';

implementation

{$R *.DFM}

procedure TMain.FitImage;
var tmpPic: TPicture;
    w, h: Integer;
    ratio: Double;
begin
  tmpPic := TPicture.Create;
  try
    tmpPic.LoadFromFile(UpFile);
    w := tmpPic.Graphic.Width;
    h := tmpPic.Graphic.Height;
    if (w > 500) or (h > 500) then begin
      if w > h then ratio := 500/w
               else ratio := 500/h;
      w := Round(ratio * w);
      h := Round(ratio * h);
    end;
    with Image.Picture.Bitmap do begin
      PixelFormat := pf24bit;
      Width := w;
      Height := h;
      Canvas.StretchDraw(Rect(0,0,w,h), tmpPic.Graphic);
    end;
  finally
    tmpPic.Free;
  end;
end;

procedure TMain.FormCreate(Sender: TObject);
begin
  Flickr := TFlickrEx.Create(APIKEY, SECRET);
  if (Flickr.ApiKey = '') or (Flickr.Secret = '') then
    ShowMessage(sNoKey);
  OpenDialog.Filter := GraphicFilter(TGraphic);
  tbUpload.Enabled := False;
  cbSafety.ItemIndex  := 0;
  cbContent.ItemIndex := 0;
end;

procedure TMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  {Flickr.Free;{ Not needed, since Flickr is declared inside the form}
end;

procedure TMain.EditEnter(Sender: TObject);
begin
  TEdit(Sender).Color := $c0f0ff;
end;

procedure TMain.EditExit(Sender: TObject);
begin
  TEdit(Sender).Color := clWindow;
end;

procedure TMain.tbOpenClick(Sender: TObject);
var tmp: TJPEGImage;
begin
  with OpenDialog do
    if Execute then begin
      UpFile := FileName;
      FitImage;
    end;
end;

procedure TMain.tbUploadClick(Sender: TObject);
var tmpStream: TFileStream;
    rsp: String;
    Visible: TVisibility;
    Safety: TSafetyLevel;
    Content: TContentType;
begin
  Visible := [];
  if not cbPrivate.Checked then
    Visible := [toPublic]
  else begin
    Visible := Visible + [toPrivate];
    if cbFamily.Checked then Visible := Visible + [toFamily];
    if cbFriends.Checked then Visible := Visible + [toFriends];
  end;
  Safety := TSafetyLevel(cbSafety.ItemIndex);
  Content := TContentType(cbContent.ItemIndex);
  tmpStream := TFileStream.Create(UpFile, fmOpenRead or fmShareDenyWrite);
  try
    rsp := Flickr.Photos.Uploader.Upload(tmpStream,
                                  ExtractFileName(UpFile),
                                  edTitle.Text,
                                  edDescription.Text,
                                  edTags.Lines.Text,
                                  Visible);
  finally
    tmpStream.Free;
  end;
  ShowMessage(rsp);
  Flickr.Photos.CheckError(rsp);
end;

end.
