{$IFDEF FPC}{$MODE DELPHI}{$ENDIF FPC}
{ $Id$ }
(************************************************************************

    Strings Extension - String Array Objects for Delphi
    Copyright 1998-2006 by Luis Caballero Martínez

    Lightweight replacement of TStrings & TStringsList and miscelaneous
	string handling routines (rawflickr release).
	
***************************** BEGIN LICENSE BLOCK ***********************
  Version: MPL 1.1

  The contents of this archive are subject to the Mozilla Public License
  Version 1.1 (the "License"); you may not use this file except in
  compliance with the License. You may obtain a copy of the License
  at http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS IS"
  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
  the License for the specific language governing rights and limitations
  under the License.

  The Original Code is StringsExt.pas, first released in 1998

  The Initial Developer of the Original Code is Luis Caballero Martínez.

  Portions created by the Initial Developer are
  copyright (C) 1998-2006 Luis Caballero Martínez. All Rights Reserved.

*************************** END LICENSE BLOCK ***************************)
{
@abstract(String Array Objects for Delphi)
 @author(Luis Caballero <luiscamar@users.sourceforge.net>)
@created(Summer of 1998)
@lastmod(2006-06-28)

Lightweight replacement of TStrings & TStringsList and miscelaneous
string handling routines (rawflickr release)

Copyright 1998, 2006 by Luis Caballero Martínez. All Rights Reserved
Released under a Mozilla Public License 1.1

}
unit StringsExt;

interface

uses Windows,{WideCharToMultibyte, MultibyteToWideChar and CP_UTF8}
     Consts, {Some resourcestrings for exception.CreateFmt}
     SysUtils,
     Classes;

type

  TStringArray = class; {forward }

  TStringsParser = function(Source: TStringArray): String;

  {@abstract(This class implements methods and functions to acccess easily
   a dynamic array of Strings)
   You can think of it as the poor-man's version of @code(TStrings) with just
   the Strings--no @code(Objects), no @code(StringsAdapter), etc. It isn't
   even thread-safe, so be warned. }
  TStringArray = class
  private
    FParser: TStringsParser;
    FStrings: array of String;
    FCount: Integer;
    FCapacity: Integer;
    function CheckIndex(Index: Integer): Boolean;
  protected
    procedure UpdateCount; virtual;
    procedure Grow(Count: Integer); virtual;
    function GetStr(Index: Integer): String; virtual;
    procedure SetStr(Index: Integer; Value: String); virtual;
    function GetCount: Integer;  virtual;
    function GetName(Index: Integer): String;
    function GetValue(const Name: String): String;
    procedure SetValue(const Name: String; Value: String);
    function ParseArray: String;
    function GetText: String;
    procedure SetText(Text: String);
  public
    constructor Create; overload;
    constructor Create(Count: Integer); overload;
    procedure Add(const S: string); virtual;
    procedure AddStrings(Source: TStrings); overload; virtual;
    procedure AddStrings(Source: TStringArray); overload; virtual;
    procedure Assign(Source: TStringArray); overload; virtual;
    procedure Assign(Source: TPersistent); overload; virtual;
    procedure AssignTo(Dest: TStringArray); overload; virtual;
    procedure AssignTo(Dest: TPersistent); overload; virtual;
    procedure Clear; virtual;
    procedure Delete(Index: Integer); virtual;
    function IndexOf(const S: string): Integer; virtual;
    function IndexOfName(const Name: string): Integer;
    procedure Insert(Index: Integer; const S: string); virtual;
    property Count: Integer read GetCount;
    property Names[Index: Integer]: string read GetName;
    property Values[const Name: string]: string read GetValue write SetValue;
    property Strings[Index: Integer]: string read GetStr write SetStr; default;
    property ParsedString: String read ParseArray;
    property Parser: TStringsParser read FParser write FParser;
    property Text: String read GetText write SetText;
  end;

  //TParamEncoding = (peLocale, peISO8859, peUnicode, peUtf8);
  {}
  TParamEncoding = (peNone, peANSI, peUtf8);

  {@abstract(Specialized class to hold and manage parameters of web calls)}
  TWebParams = class
  private
    FParams: TStringArray;
    FEncoding: TParamEncoding;
  protected
    procedure SetEncoding(Enc: TParamEncoding);
    function GetCount: Integer;
    function GetParam(const Name: String; Index: Integer): String;
    procedure SetParam(const Name: String; Index: Integer; Value: string);
    function GetAsURL: String;
    procedure SetAsURL(const Source: String);
    //function ParseToURL(Source: TStringArray): String; dynamic;
    function GetText: String;
    procedure SetText(Text: String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize;
    procedure AddStrings(Strings: TStrings); dynamic;
    procedure Insert(Index: Integer; const S: string); dynamic;
    procedure InsertValue(Index: Integer; const Name, Value: string);
    property Encoding: TParamEncoding read FEncoding write SetEncoding
                                      default peNone; //peLocale;
    property Count: Integer read GetCount;
    property Required[const Name: String]: String index 0 read GetParam
                                                          write SetParam;
    property Optional[const Name: String]: String index 1 read GetParam
                                                          write SetParam;
    property Parameters: TStringArray read FParams;
    property URLEncoded: String read GetAsURL write SetAsURL;
    property Text: String read GetText write SetText;
  end;

function StringToUTF8(const Source: String): String;
function UTF8ToString(const Source: String): String;
{ Encodes a string for insertion in a URL.
  This function isn't intended to encode full URIs, but the strings
  used to build them. If you pass a whole URI the result will probably
  not be usable as a URI anymore.
  See the overloaded TStrings version for a sample of use.}
function URLEncode(const s: String): String; overload;
{ Returns the TStrings 'Params' text encoded as a URL request params string.
  Note that it'll add a field even if its value is an empty string.

  The actual encoding is made in the overloaded 'String parameter' variant.}
function URLEncode(Params: TStrings): String; overload;

implementation

const CR = #13;
      LF = #10;
      CRLF = CR + LF;
      LFCR = LF + CR;
      rfAll: TReplaceFlags = [rfReplaceAll];

// TStringArray = class
function TStringArray.CheckIndex(Index: Integer): Boolean;
begin

  Result := (Low(FStrings) <= High(FStrings)) and {A little safeguard...}
            ((Index >= Low(FStrings)) and
             (Index <= High(FStrings)));
end;

procedure TStringArray.UpdateCount;
begin
  FCount := (High(FStrings) - Low(FStrings)) + 1;
end;

procedure TStringArray.Grow(Count: Integer);
begin
  Count := Count + FCount;
  SetLength(FStrings, Count);
  UpdateCount;
end;

function TStringArray.GetStr(Index: Integer): String;
begin
  if CheckIndex(Index) then
    Result := FStrings[Index]
  else
    raise EListError.CreateFmt(SListIndexError,[Index])
end;

procedure TStringArray.SetStr(Index: Integer; Value: String);
begin
  if CheckIndex(Index) then
    FStrings[Index] := Value
  else
    raise EListError.CreateFmt(SListIndexError,[Index])
end;

function TStringArray.GetCount: Integer;
begin
  UpdateCount;
  Result := FCount;
end;

function TStringArray.GetName(Index: Integer): String;
var p: Integer;
begin
  Result := GetStr(Index);
  p := AnsiPos('=', Result);
  if p > 0 then SetLength(Result, p-1)
           else SetLength(Result, 0);
end;

function TStringArray.GetValue(const Name: String): String;
var i: Integer;
begin
  i := IndexOfName(Name);
  if i >= 0 then
    Result := Copy(FStrings[I], Length(Name) + 2, MaxInt)
  else
    Result := '';
end;

procedure TStringArray.SetValue(const Name: String; Value: String);
var i: Integer;
begin
  i := IndexOfName(Name);
  if i >= 0 then FStrings[I] := Name + '=' + Value
            else Add(Name + '=' + Value);
end;

function TStringArray.GetText: String;
var i: Integer;
begin
  Result := '';
  for i := Low(FStrings) to High(FStrings) do
    if i < High(FStrings) then
      Result := Result + FStrings[i] + CRLF
    else
      Result := Result + FStrings[i];
end;

procedure TStringArray.SetText(Text: String);
var p: Integer;
    s: String;
begin
  Clear;
  Text := StringReplace(Text, CRLF, LF, rfAll);
  Text := StringReplace(Text, LFCR, LF, rfAll);
  Text := StringReplace(Text, CR,   LF, rfAll);
  Text := StringReplace(Text, #00,  LF, rfAll);
  repeat
    p := AnsiPos(#10, Text);
    if p <> 0 then begin
      s := Copy(Text, 1, p - 1);
      Add(s);
      System.Delete(Text, 1, p);
    end;
  until p = 0;
  if Text <> '' then Add(Text);
end;

function TStringArray.ParseArray: String;
begin
  if Assigned(Parser) then Result := FParser(Self)
                      else Result := GetText;
end;

procedure TStringArray.Add(const S: string);
begin
  Grow(1);
  FStrings[High(FStrings)] := S;
  UpdateCount;
end;

procedure TStringArray.AddStrings(Source: TStrings);
var i, from: Integer;
begin
  if (Source <> nil) and (Source.Count > 0) then begin
    from := GetCount;
    Grow(Source.Count);
    for i := 0 to Source.Count - 1 do
      SetStr(from + i, Source[i]);
  end;
end;

procedure TStringArray.AddStrings(Source: TStringArray);
var i, from: Integer;
begin
  if (Source <> nil) and (Source.Count > 0) then begin
    from := GetCount;
    Grow(Source.Count);
    for i := 0 to Source.Count - 1 do
      SetStr(from + i, Source[i]);
  end;
end;


procedure TStringArray.Assign(Source: TStringArray);
begin
  Clear;
  AddStrings(Source);
end;

procedure TStringArray.Assign(Source: TPersistent);
begin
  if Source.InheritsFrom(TStrings) then begin
     Clear;
     AddStrings(TStrings(Source));
  end else
    raise EConvertError.CreateFmt(SAssignError,
                                  [Source.ClassName, ClassName]);
end;

procedure TStringArray.AssignTo(Dest: TStringArray);
begin
  Dest.Clear;
  Dest.AddStrings(Self);
end;

procedure TStringArray.AssignTo(Dest: TPersistent);
begin
  if Dest.InheritsFrom(TStrings) then
    TStrings(Dest).Text := GetText
  else
    raise EConvertError.CreateFmt(SAssignError,
                                  [ClassName, Dest.ClassName]);
end;

procedure TStringArray.Clear;
begin
  if FCount > 0 then SetLength(FStrings, 0);
  UpdateCount;
end;

procedure TStringArray.Delete(Index: Integer);
var i: Integer;
begin
  if CheckIndex(Index) then begin
    for i := (Index + 1) to High(FStrings) do
      FStrings[i] := FStrings[i+1];
    Grow(-1);
  end else
    raise EListError.CreateFmt(SListIndexError,[Index])
end;

function TStringArray.IndexOf(const S: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := Low(FStrings) to High(FStrings) do
    if FStrings[i] = S then begin
      Result := i;
      Break;
    end;
end;

function TStringArray.IndexOfName(const Name: string): Integer;
var i: Integer;
begin
  Result := -1;
  for i := Low(FStrings) to High(FStrings) do
    if GetName(i) = Name then begin
      Result := i;
      Break;
    end;
end;

procedure TStringArray.Insert(Index: Integer; const S: string);
var i: Integer;
begin
  if CheckIndex(Index) then begin
    Grow(1);
    for i := FCount - 2 downto Index do
      FStrings[i+1] := FStrings[i];
    FStrings[Index] := S;
  end else
    raise EListError.CreateFmt(SListIndexError,[Index])
end;

constructor TStringArray.Create;
begin
  inherited;
  FParser := nil;
  FCount := 0;
  FCapacity := 0;
end;

constructor TStringArray.Create(Count: Integer);
begin
  Create;
  Grow(Count);
end;

//  TWebParams = class
//    private FParams: TStringArray;

procedure TWebParams.SetEncoding(Enc: TParamEncoding);
begin
  if FEncoding <> Enc then begin
    FEncoding := Enc;
  end;
end;

function TWebParams.GetCount: Integer;
begin
  Result := FParams.Count;
end;

function TWebParams.GetParam(const Name: String; Index: Integer): String;
begin
  Result := FParams.Values[Name];
end;

procedure TWebParams.SetParam(const Name: String; Index: Integer; Value: string);
var p: Integer;
begin
  case Index of
  { Required parameter; add/update even if empty }
  0 : FParams.Values[Name] := Value;
  { Optional parameter; add/keep/update only if it's non-empty}
  1 : if Value <> '' then { if not empty, add/update }
        FParams.Values[Name] := Value
      else begin { If empty and already there, it'll be deleted }
        p := FParams.IndexOfName(Name);
        if p >= 0 then FParams.Delete(p);
      end;
  end;
(* Another implementation:
  FParams.Values[Name] := Value;
  if (Index = 1) and (Value = '') then begin
    p := FParams.IndexOfName(Name);
    if p >= 0 then FParams.Delete(p);
  end;
*)
end;

{ DONE -oLCM : Not yet as per RFC 3986, but close enough...;-)
  WAS: Implement (or use) a real URI coder/parser,
       instead of the actual silly thing. [See RFC 3986]
}
function TWebParams.GetAsURL: String;
var i: Integer;
    name: String;
begin
  Result := '';
  if GetCount > 0 then begin
    for i := 0 to FParams.Count - 1 do begin
      if Result <> '' then Result := Result + '&';
                      //else Result := '?';
      name := FParams.Names[i];
      Result := Result +
                URLEncode(name) + '=' +
                URLEncode(FParams.Values[name]);
    end;
  end;
(* -- See what I was talking about in the TODO line? --
  Result := '?' + StringReplace(FParams.Text, CRLF, '&', rfAll);
  if LastDelimiter('&', Result) = Length(Result) then
    SetLength(Result, Length(Result) - 1);
  Result := StringReplace(Result, ' ', '%20', rfAll);
(**)
end;

{ TODO -oLCM : Implement (or use) a real URI parser,
               instead of the actual silly thing. [See RFC3986]}
procedure TWebParams.SetAsURL(const Source: String);
var tmpStr: String;
begin
  tmpStr := StringReplace(Source, '&', LF, rfAll);
  if AnsiPos('?', tmpStr) = 1 then
    Delete(tmpStr, 1, 1);
  FParams.Text := StringReplace(tmpStr, '%20', ' ', rfAll);;
end;

function TWebParams.GetText: String;
begin
  Result := FParams.Text;
end;

procedure TWebParams.SetText(Text: String);
begin
  FParams.Text := Text;
end;

procedure TWebParams.Initialize;
begin
  FParams.Clear;
end;

procedure TWebParams.AddStrings(Strings: TStrings);
begin
  FParams.AddStrings(Strings);
  FParams.Text := FParams.Text; { Don't remember why... to normalize EOLs ? }
end;

procedure TWebParams.Insert(Index: Integer; const S: string);
begin
  FParams.Insert(Index, S);
end;

procedure TWebParams.InsertValue(Index: Integer; const Name, Value: string);
var p: Integer;
begin
  p := FParams.IndexOfName(Name);
  if p >= 0 then FParams.Delete(p);
  FParams.Insert(Index, Name + '=' + Value);
end;

constructor TWebParams.Create;
begin
  inherited;
  FParams := TStringArray.Create;
  FEncoding := peNone; //peLocale;
end;

destructor TWebParams.Destroy;
begin
  FreeAndNil(FParams);
  inherited;
end;

{ String handling extensions}

{@COMPAT: Needs MLU under Win95 }
function StringToUTF8(const Source: String): String;
var WideSrc: Widestring;
    DestLen: Integer;
begin
  Result := '';
  if Length(Source) > 0 then begin
    { ANSI -> UCS2 }
    WideSrc := Source;
    { UCS2 -> UTF8 }
    DestLen := WideCharToMultiByte(CP_UTF8, 0, PWideChar(WideSrc), -1,
                                   nil, 0,nil, nil);
    if DestLen = 0 then RaiseLastWin32Error;
    SetLength(Result, DestLen);
    WideCharToMultiByte(CP_UTF8, 0, PWideChar(WideSrc), -1,
                        PChar(Result), DestLen, nil, nil);
  end;
end;

{@COMPAT: Needs MLU under Win95 }
function UTF8ToString(const Source: String): String;
var WideDest: Widestring;
    DestLen: Integer;
begin
  { UTF8 -> UCS2 }
  DestLen := MultiByteToWideChar(CP_UTF8, 0, PChar(Source), -1, nil, 0);
  if DestLen = 0 then RaiseLastWin32Error;
  SetLength(WideDest, DestLen);
  MultiByteToWideChar(CP_UTF8, 0, PChar(Source), -1,
                                  PWideChar(Widedest), DestLen);
  Result := WideDest; { UCS2 -> ANSI }
end;

{ This function encodes a single string.
  See the overloaded version for a sample of use.}
function URLEncode(const s: String): String; overload;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    case s[i] of
    ' ': Result := Result + '+';
    '0'..'9',
    'A'..'Z',
    'a'..'z': Result := Result + s[i];
    else Result := Result + '%' + IntToHex(ord(s[i]),2);
    end;
end;

function URLEncode(Params: TStrings): String; overload;
var i: Integer;
    name: String;
begin
  Result := '';
  if Params.Count > 0 then begin
    for i := 0 to Params.Count - 1 do begin
      if Result <> '' then Result := Result + '&';
                      //else Result := '?';
      name := Params.Names[i];
      Result := Result +
                URLEncode(name) + '=' +
                URLEncode(Params.Values[name]);
    end;
  end;
(* -- Older stupid impl. --
  Result := '?' + StringReplace(Params.Text, #13#10, '&', [rfReplaceAll]);
  if LastDelimiter('&', Result) = Length(Result) then
    SetLength(Result, Length(Result) - 1);
(**)
end;



end.
