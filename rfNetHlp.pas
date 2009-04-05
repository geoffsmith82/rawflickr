{ $Id$ }
{************************************************************************

    Internet Helper for RawFlickr, v1.04
    Copyright 2005,2008 Luis Caballero Martínez

    Network access extensions for Rawflickr.

    This unit was designed to use and interact with:
    - Internet Direct (Indy) version 9.0
          http://www.indyproject.org/
    - Synapse Release 36
          http://www.ararat.cz/synapse/

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

  The Original Code is DateTimeExt.pas, first released in 1998

  The Initial Developer of the Original Code is Luis Caballero Martínez.

  Portions created by the Initial Developer are
  copyright (C) 2005,2008 Luis Caballero Martínez. All Rights Reserved.

*************************** END LICENSE BLOCK ***************************}

{@abstract(Internet Helper for Rawflickr)
 @author(Luis Caballero <luiscamar@users.sourceforge.net>)
 @created(2005-03)
 @lastmod(2006-02)

This unit serves to isolates the main rawflickr.pas from the network
lybrary used to actually access the Internet, the rationale being that
thus the task of porting Rawflickr to other environments is eased.

Later versions may be implemented as an abstract class or a plugable
architecture, but for now it's just a set of function calls extracted from
my Network Extensions Library.

@bold(Credits:)
@unorderedlist(
@item Internet Direct (Indy) version 9.0.18, http://www.indyproject.org/
@item Synapse Release 36, http://www.ararat.cz/synapse/
)
@bold(Important Note):
Synapse support has been temporarily taken away; it'll be reintroduced in one
of the next releseases. If you can't wait, feel free to introduce it yourself
and pass it back to the source tree (contact me for details)
}
unit rfNetHlp;
{ TODO : Enable the use of libraries other than Indy }
{ TODO : Modify it to make easier the use of proxy servers.}

{ Uncomment JUST ONE of the following }
{$DEFINE INDY}
{.DEFINE SYNAPSE}

interface

uses
  SysUtils, Classes,
  {$IFDEF INDY}
    IdMultipartFormData, IdHTTP;
  {$ELSE}
  {$IFDEF SYNAPSE}
    httpSend;
  {$ENDIF ~Synapse}
  {$ENDIF ~Indy}


type

  {@abstract(Valid HTTP request methods)}
  TReqMethod = (rqGet, rqPost, rqPut, rqHead, rqOther);

  EDownloadError = class(Exception);

{@abstract(Launchs the default browser and navigates to an URL.)
 This call is used by @link(rawflickr), during the authorization
 process, to navigate to the "login link".

 The actual implementation depends of Win32's URL Moniker }
function LaunchBrowser(URL: WideString): Boolean;

{@abstract(Download a web document into a stream via HTTP)
 @param(url URI of the file to retrieve.)
 @param(DestStream Destination stream.)
 @param(Params Parameters to pass to the remote host.)
 @param(Method HTTP method to use for the request.)
 @returns(@true on completion or @false on error if no exception is raised.)
 @raises(Exception The class of the exception depends of the underlying
         HTTP or streams implementations.)
}
function DownloadURL(url: String; DestStream: TStream;
                     Params: TStrings = nil;
                     Method: TReqMethod = rqPost): boolean; overload;
{@abstract(Download a remote file to a local one via HTTP)
 @param(url URI of the file to retrieve.)
 @param(DestFileName Name of the destination local file.)
 @param(Params Parameters to pass to the remote host.)
 @param(Method HTTP method to use for the request.)
 @returns(@true on completion or @false on error if no exception is raised.)
 @raises(Exception The class of the exception depends of the underlying
         HTTP, streams or filesystem implementations.)
}
function DownloadURL(url: String; DestFileName: String;
                     Params: TStrings = nil;
                     Method: TReqMethod = rqPost): boolean; overload;

{ Calls to Web Sites' APIs like p.e. Flickr's }
{@abstract(Calls an HTTP service--url-encoded params)
 This set of functions work as those of the @link(DownloadURL) group
 but return a string with the server's response, thus making it easier
 to feed it to a parser.

 This variant executes the HTTP @code(Method) passing the parameters
 @code(Params) in url-encoded form.
 }
function WebMethodCall(const BaseURL: String; Params: TStrings;
                       Method: TReqMethod = rqPost): String; overload;
{@abstract(Calls an HTTP service--w/out params)
 This set of functions work as those of the @link(DownloadURL) group
 but return a string with the server's response, thus making easier
 to feed it to a parser.

 This variant executes the HTTP @code(Method) passing no parameters, unless
 already encoded by the user in @code(BaseURL).
 }
function WebMethodCall(const BaseURL: String;
                       Method: TReqMethod = rqPost): String; overload;
{@abstract(Calls an HTTP service--Multipart/Form-Data)
 This set of functions work as those of the @link(DownloadURL) group
 but return a string with the server's response, thus making easier
 to feed it to a parser.

 This variant pass the HTTP Post parameters as a Multipart/Form-Data stream;
 it's used, generally, to upload a file to a web server.
 }
function WebMethodCall(const BaseURL: String;
                       FormData: TIdMultiPartFormDataStream): String; overload;

implementation

uses
  UrlMon, IdURI;

const
  MethodNames: array[rqGet..rqOther] of string =
    ('Get', 'Post', 'Put', 'Head', 'Other');

// Launch browser and navigate to URL
function LaunchBrowser(URL: WideString): Boolean;
const S_OK: HResult = 0;
begin
  Result := HlinkNavigateString(nil, PWideChar(URL)) = S_OK;
end;

{.IFDEF INDY}
function GetHTTPClient: TIdHTTP;
begin
  Result := TIdHTTP.Create(nil);
  //Result.Request.UserAgent := 'Mozilla/3.0 (compatible; Indy Library)';
end;
{.ENDIF}

// Download URL to a TStream;
function DownloadURL(url: String; DestStream: TStream;
                     Params: TStrings = nil;
                     Method: TReqMethod = rqPost): boolean; overload;
var http: TIdHTTP;
    //fullURI: String;
begin
  http := GetHTTPClient;
  try
    Result := False;
    case Method of
    rqGet : http.Get(url, DestStream);
    rqPost: http.Post(url, Params, DestStream);
    rqHead: begin
              http.Head(url);
              http.Response.RawHeaders.SaveToStream(DestStream);
            end;
    end;
    Result := True;
  finally http.Free end;
end;

// Download URI to a file
function DownloadURL(url: String; DestFileName: String;
                     Params: TStrings = nil;
                     Method: TReqMethod = rqPost): boolean; overload;
var fs : TFileStream;
begin
  fs := TFileStream.Create(DestFileName, fmCreate or fmShareExclusive);
  try
    Result := DownloadURL(url, fs, Params, Method);
  finally
    fs.Free
  end;
end;

{@DEBUG
var callNo: Integer = 0;{}
{ Retrieve content from a URL. Request params are passed in TStrings }
function WebMethodCall(const BaseURL: String; Params: TStrings;
                       Method: TReqMethod = rqPost): String;{}
var http: TIdHTTP;
//    logStr: TStringList;
begin
  Result := '';
  http := GetHTTPClient;
  try
    case Method of
    rqGet  : Result := http.Get(BaseURL);
    rqPost : begin
               http.HTTPOptions := [];
               Result := http.Post(BaseURL, Params);
             end;
    end;
{@DEBUG LCM
    logStr := TStringList.Create;
    try
      logStr.BeginUpdate;
      logStr.Add(Format('POST %s HTTP/1.0',[http.Request.URL]));
      logStr.AddStrings(http.Request.RawHeaders);
      logStr.SaveToFile(Format('request%.2d.log', [callNo]));
      logStr.EndUpdate;
      inc(callNo);
    finally
      logStr.Free;
    end;
{@DEBUG LCM /}
  finally http.Free end;
end;

// Retrieve content from a URL. No params are passed unless coded in BaseURL.
function WebMethodCall(const BaseURL: String;
                       Method: TReqMethod = rqPost): String;
begin
  Result := WebMethodCall(BaseURL, TStrings(nil), Method);
end;

// Post Multipart/Form-Data content to BaseURL.
function WebMethodCall(const BaseURL: String;
                       FormData: TIdMultiPartFormDataStream): String; overload;
var http: TIdHTTP;
begin
  Result := '';
  http := GetHTTPClient;
  try
    Result := http.Post(BaseURL, FormData);
  finally
    http.Free
  end;
end;

end.

