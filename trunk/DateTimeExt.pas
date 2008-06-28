{$IFDEF FPC}{$MODE DELPHI}{$ENDIF FPC}
(************************************************************************

    Date/Time Extension for Delphi
    Copyright 1998, 2005 by Luis Caballero Martínez

    Date/Time conversion routines (rawflickr release)

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
  copyright (C) 1998-2007 Luis Caballero Martínez. All Rights Reserved.

*************************** END LICENSE BLOCK ***************************)

{@abstract(Date/Time conversion routines)
 @author(Luis Caballero <luiscamar@users.sourceforge.net>)
 @created(1998-05-27)
 @lastmod(2007-01-18)

 Copyright 1998, 2005 by Luis Caballero Martínez. All rights reserved.
 Released under a Mozilla Public License 1.1

}
unit DateTimeExt;

interface

uses {$IFDEF WIN32}
     Windows,
     {$ENDIF}
     SysUtils;

type

  {Helper class for use of date ranges as fields, function parameters, etc.}
  TDateRange = class
  private
    FMin, FMax: TDateTime;
  public
    property MinDate: TDateTime read FMin write FMin;{<Minimum date}
    property MaxDate: TDateTime read FMax write FMax;{<Maximum date}
    constructor Create; overload; {<Default constructor, for overloading}
    {@abstract(Range constructor)
     No check is made to see if ToDate >= FromDate}
    constructor Create(FromDate, ToDate: TDateTime); overload;
  end;

{@abstract(Returns the local equivalent of a UTC DateTime)
 This function is accurate only in Windows NT; in Windows 95, 98 and ME
 it'll fail if the date to convert is in daylight saving range and the
 system's current is not or viceversa.

 The bias of the fail will be the same as that between both date ranges
 p.e. if you are in Europe, the system's date is Dec. 28th and pass Aug. 18
 to the function (or viceversa), the difference will be abs(CEST - CET) }
function UTCToLocal(UTC: TDateTime): TDateTime;
{@abstract(Returns the UTC equivalent of a local DateTime)
 Accurate only on Windows NT systems.
 @seealso(UTCToLocal)}
function LocalToUTC(Local: TDateTime): TDateTime;
{@abstract(Returns a Delphi TDateTime corresponding to a MySQL date/time string)
 This function can be used also with other date-string formats,
 but don't push it too far or it'll break down...}
function MySQLToDateTime(MySQLDate: String): TDateTime;
{@abstract(Converts a TDateTime to a date/time string in MySQL format)}
function DateTimeToMySQL(DateTime: TDateTime): String;
{@abstract(Returns a TDateTime equivalent to a Unix timestamp)
 This function depends on Delphi's internal represention of TDateTime.}
function UnixToDateTime(UnixDate: Cardinal): TDateTime;
{@abstract(Converts a TDateTime into a Unix timestamp)
 This function depends on Delphi's internal represention of TDateTime.
@raises(EConvertError if trying to convert a date prior Jan, 1, 1970)}
function DateTimeToUnix(DateTime: TDateTime): Cardinal;

{@abstract(Error string used when DateTimeToUnix raises EConvertError)}
resourceString sDateTooOld = 'Can''t convert dates prior 1970';

const
  {@abstract(TDateTime equivalent of a "zero" Unix timestamp.)
   It was calculated with @code(EncodeDate(1970, 01, 01))}
  UnixDateDelta: TDateTime = 25569.00;

implementation

{**************************************}
{*    TDateRange = class              *}
{**************************************}

constructor TDateRange.Create(FromDate, ToDate: TDateTime);
begin
  inherited Create;
  FMin := FromDate;
  FMax := ToDate;
end;

constructor TDateRange.Create;
begin
  Create(0.0, 0.0);
end;

{**************************************}
{*    Other functions                 *}
{**************************************}

{$IFDEF WIN32}
function IsWinNT: Boolean;
begin
  Result := (Win32Platform = VER_PLATFORM_WIN32_NT);
end;
{$ELSE}
function IsWinNT: Boolean; begin Result := False end;
{$ENDIF}

{ Gets the local equivalent of a given UTC date & time.
  It's accurate only in Windows NT; in Windows 95, 98, Me
  it'll fail if the date to convert were in daylight saving
  range and the actual is not or viceversa. The bias of the
  fail will be the same as that between both date ranges.
  p.e. if you are in december and pass an august date or
  viceversa in Europe the difference will be abs(CEST - CET) }
function UTCToLocal(UTC: TDateTime): TDateTime;
var ut, lt: TSystemTime;
    tzi: TTimeZoneInformation;
    bias: integer;
begin
  DateTimeToSystemTime(UTC, ut);
  if IsWinNT then
    SystemTimeToTzSpecificLocalTime(nil, ut, lt)
  else begin
    lt := ut;
    bias := 0;
    case GetTimeZoneInformation(tzi) of
    TIME_ZONE_ID_UNKNOWN:  bias := tzi.Bias;
    TIME_ZONE_ID_STANDARD: bias := tzi.Bias + tzi.StandardBias;
    TIME_ZONE_ID_DAYLIGHT: bias := tzi.Bias + tzi.DaylightBias;
    else RaiseLastWin32Error; { TIME_ZONE_ID_INVALID }
    end;
    with lt do begin
      wHour := wHour - (bias div 60);
      wMinute := wMinute - (bias mod 60);
    end;
  end;
  Result := SystemTimeToDateTime(lt);
end;

{ Reverse of UTCToLocal, same notes apply }
function LocalToUTC(Local: TDateTime): TDateTime;
var ut, lt: TSystemTime;
    tzi: TTimeZoneInformation;
    bias: integer;
    NTBias: TDateTime;
begin
  DateTimeToSystemTime(Local, lt);
  if IsWinNT then begin
    { Get the difference between a UTC and a local and apply; }
    { only XP-SP2 and up have TZSpecificLocalTimeToSystemTime }
    SystemTimeToTzSpecificLocalTime(nil, lt, ut);
    NTBias := SystemTimeToDateTime(ut) - SystemTimeToDateTime(lt);
    DateTimeToSystemTime(Local - NTBias, ut);
  end else begin
    ut := lt;
    bias := 0;
    case GetTimeZoneInformation(tzi) of
    TIME_ZONE_ID_UNKNOWN:  bias := tzi.Bias;
    TIME_ZONE_ID_STANDARD: bias := tzi.Bias + tzi.StandardBias;
    TIME_ZONE_ID_DAYLIGHT: bias := tzi.Bias + tzi.DaylightBias;
    else RaiseLastWin32Error;
    end;
    with ut do begin
      wHour := wHour + (bias div 60);
      wMinute := wMinute + (bias mod 60);
    end;
  end;
  Result := SystemTimeToDateTime(ut);
end;

{ Transfers a TMySQL DateTime to a TDateTime
  (in fact, it can translate quite a bunch date string formats,
  but don't push it too far or it'll break down) }
function MySQLToDateTime(MySQLDate: String): TDateTime;
begin
  Result := VarToDateTime(MySQLDate);
end;

{ And viceversa: TDateTime to MySQL.
  Note the ":" to get fixed ':' instead of the local separator }
function DateTimeToMySQL(DateTime: TDateTime): String;
begin
  Result := FormatDateTime('yyyy-mm-dd hh":"nn":"ss', DateTime);
end;

function UnixToDateTime(UnixDate: Cardinal): TDateTime;
//var Days, Hour: Cardinal;
begin
(*
  Days := Unix div SecsPerDay;        {Get the number of days}
  Hour := Unix - (Days * SecsPerDay); {Discount to get the seconds}
  Result := UnixDateDelta + Days +
            (Hour/SecsPerDay);        {Convert secs. in fraction of day}
(**)
  {Probably quicker:}
  Result := 1.0*(UnixDate / SecsPerDay) + UnixDateDelta;
end;

function DateTimeToUnix(DateTime: TDateTime): Cardinal;
//var Days, Hour: Cardinal;
begin
  if DateTime < UnixDateDelta then
    raise EConvertError.Create(sDateTooOld)
  else begin
    Result := Round((DateTime - UnixDateDelta)* SecsPerDay)
  end;
end;

end.
