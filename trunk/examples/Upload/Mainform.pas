{ $Id$ }
{--------------------------------------------------------------------------}
{                                                                          }
{ Upload example for Rawflickr                                             }
{                                                                          }
{ The contents of this archive are subject to the Mozilla Public License   }
{ Version 1.1 (the "License"); you may not use this file except in         }
{ compliance with the License. You may obtain a copy of the License        }
{ at http://www.mozilla.org/MPL/                                           }
{                                                                          }
{ Software distributed under the License is distributed on an "AS IS"      }
{ basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See      }
{ the License for the specific language governing rights and limitations   }
{ under the License.                                                       }
{                                                                          }
{ The Original Code covered by this license is the "Upload" Delphi project }
{ including all the associated source files and documentation,             }
{ First released in March, 2009                                            }
{                                                                          }
{ The Initial Developer of the Original Code is Luis Caballero Martínez.   }
{                                                                          }
{ Portions created by the Initial Developer are                            }
{ Copyright (C) 2009 Luis Caballero Martínez. All Rights Reserved.         }
{                                                                          }
{--------------------------------------------------------------------------}

{ Check this defines and modify them to suit. }
{$DEFINE WC} {Local define to $INCLUDE my own API key & secret :-)}
{$DEFINE ImgExt} {If set, use GIFImage and PNGImage}
{$DEFINE UPTO23}

unit Mainform;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Menus, Buttons, Rawflickr, ComCtrls, ImgList, ToolWin,
{$IFDEF ImgExt} JPEG, GIFImage, PNGImage;
{$ELSE}         JPEG;
{$ENDIF}


type
  TMain = class(TForm)
    Bevel: TBevel;
    Image: TImage;
    MetaPanel: TPanel;
      lbTitle: TLabel;
      edTitle: TEdit;
      lbDescription: TLabel;
      edDescription: TMemo;
      lbTags: TLabel;
      edTags: TMemo;
      gbVisibility: TGroupBox;
        cbPrivate: TCheckBox;
        cbFamily: TCheckBox;
        cbFriends: TCheckBox;
        lbGlobalHide: TLabel;
        cbGlobalHide: TComboBox;
      lbSafety: TLabel;
      cbSafety: TComboBox;
      lbContent: TLabel;
      cbContent: TComboBox;
    ToolBar: TToolBar;
      tbUser: TToolButton;
      tbSep1: TToolButton;
      tbOpen: TToolButton;
      tbUpload: TToolButton;
      tbSep2: TToolButton;
      lbName: TLabel;
    ToolImages: TImageList;
    OpenDialog: TOpenDialog;
    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure tbUserClick(Sender: TObject);
    procedure tbOpenClick(Sender: TObject);
    procedure tbUploadClick(Sender: TObject);
  private
    { Private declarations }
    Flickr: TFlickrEx;
    UpFile: String;
    procedure FitImage;
    {function UserAuth: Boolean;{}
  public
    { Public declarations }
  end;

var
  Main: TMain;

{$IFDEF WC}
  {$I MyAPICONST.INC}
{$ELSE}
  {$I APICONST.INC} { REMEMBER TO EDIT YOUR KEY/SECRET INTO APICONST.INC !!!!!}
{$ENDIF}

resourcestring
  sNoKey = 'You need a valid API key and secret to run this program';

implementation

{$R *.DFM}

{ This procedure resizes the image to fit in the 500x500 ectangle, if needed }
procedure TMain.FitImage;
var tmpPic: TPicture;
    w, h: Integer;
    ratio: Double;
begin
  tmpPic := TPicture.Create;
  try
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
      tbUpload.Enabled := True;
    except
      if Assigned(Image.Picture.Graphic) and Image.Picture.Graphic.Empty then
        tbUpload.Enabled := False;
    end;
  finally
    tmpPic.Free;
  end;
end;

procedure TMain.FormCreate(Sender: TObject);
begin
{$IFDEF UPTO23}
  Flickr := TFlickrEx.Create(APIKEY, SECRET, st23);
  if (Flickr.ApiKey = '') then
    ShowMessage(sNoKey);
{$ELSE}
  Flickr := TFlickrEx.Create(APIKEY, SECRET); {stFlickr is the default}
  if (Flickr.ApiKey = '') or (Flickr.Secret = '') then
    ShowMessage(sNoKey);
{$ENDIF}
  { Not really a good idea unless your Delphi install has support for,
    at least, GIF and PNG images. }
  OpenDialog.Filter := GraphicFilter(TGraphic);
  tbUpload.Enabled := False;
  cbGlobalHide.ItemIndex := 0;
  cbSafety.ItemIndex  := 0;
  cbContent.ItemIndex := 0;
end;

procedure TMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  {Flickr.Free;{ Not needed, since Flickr is declared inside the form}
end;

{ This nifty trick, by means of a visual clue, makes it easier to know
  which box you're actually editing }
procedure TMain.EditEnter(Sender: TObject);
begin
  TEdit(Sender).Color := $c0f0ff;
end;

procedure TMain.EditExit(Sender: TObject);
begin
  TEdit(Sender).Color := clWindow;
end;

{ This procedure shows a simple way to authenticate a use regardless of
  whether she has authorized the application. }
procedure TMain.tbUserClick(Sender: TObject);
var f: TextFile;
    tmpToken: String;
begin
  { First, we look for a previously obtained token, if any. }
  AssignFile(f, ExtractFilePath(Application.ExeName) + 'user.txt');
  try
    try
      Reset(f);
      ReadLn(f, tmpToken);
    except
      { Of course, real apps should manage exceptions better; here we just
        assume that there was no "user.txt" and, thence, no token }
      Rewrite(f);
      tmpToken := ''
    end;
    { Token or no, we must authenticate; fortunately (for you :) the whole
      process is managed is managed with just ONE call.}
    if Flickr.Authorize('write', tmpToken) then begin
      lbName.Caption := 'Hi, ' + Flickr.User.UserName + '!';
      { This is a extremely simple example so we just store the token in a
        single-line file: the bare minimum}
      Rewrite(f);
      Writeln(f, Flickr.Token);
    end else
      {Authorize failed! Let's raise the exception to know why.}
      Flickr.Auth.CheckError(Flickr.Auth.LastResponse);
  finally
    CloseFile(f);
  end;
end;

procedure TMain.tbOpenClick(Sender: TObject);
begin
  with OpenDialog do
    if Execute then begin
      UpFile := FileName;
      FitImage;
    end;
end;

{ This is it: the user asks to upload the image and we do it *here* }
procedure TMain.tbUploadClick(Sender: TObject);
var tmpStream: TFileStream;
    rsp: String;
    Visible: TVisibility;
    Safety: TSafetyLevel;
    Content: TContentType;
    ToHide: TSearchStatus;
begin
  Application.ProcessMessages;
  { First, we prepare some vars of the correct type from the info in form
    We should also check the file type and convert it if need be, but I'm
    lazy today :-) }
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
  ToHide := TSearchStatus(cbGlobalHide.ItemIndex);
  tmpStream := TFileStream.Create(UpFile, fmOpenRead or fmShareDenyWrite);
  try try { It's not a typo; there really are two "try"s there :) }
      { Now, let's do the actual upload. This might a while: let the user know}
      Screen.Cursor := crHourGlass;
      rsp := Flickr.Photos.Uploader.Upload(tmpStream,
                                    ExtractFileName(UpFile),
                                    edTitle.Text, edDescription.Text,
                                    edTags.Lines.Text, Visible,
                                    Safety, Content, ToHide);
      {
        We should now redirect the user to Flickr (or ask if he wants) to
        check if all the data arrived OK and edit it if need be.
        To form the URI to which to send the user we would now parse rsp
        to get the photoid and launch a browser to:
        http://www.flickr.com/tools/uploader_edit.gne?ids=9999999 or
        http://www.23hq.com/tools/uploader_edit.gne?ids=9999999        
        where 9999999 is the photoid we have just extracted from rsp.
      }
    except
      Screen.Cursor := crDefault;
      raise;
    end;
  finally
    Screen.Cursor := crDefault;
    tmpStream.Free;
  end;
  ShowMessage(rsp);
  Flickr.Photos.CheckError(rsp);
end;

end.
