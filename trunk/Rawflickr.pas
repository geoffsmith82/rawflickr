{ $Id$ }
{--------------------------------------------------------------------------}
{                                                                          }
{ Rawflickr - Flickr API Interface Library v1.2                            }
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
{ The Original Code covered by this license is rawflickr.pas, first        }
{ released in October 2005.                                                }
{                                                                          }
{ The Initial Developer of the Original Code is Luis Caballero Martínez.   }
{                                                                          }
{ Portions created by the Initial Developer are                            }
{ Copyright (C) 2005-2008 Luis Caballero Martínez. All Rights Reserved.    }
{                                                                          }
{--------------------------------------------------------------------------}
{
 @abstract(Basic (raw) wrapper interface to Flickr's REST API)
 @author(Luis Caballero <luiscamar@users.sourceforge.net>)
 @created(2005-09-16)
 @lastmod(2009-03-31)

 This unit contains a set of wrapper classes to interface with Flickr
 through the REST Flickr API. There is also limited support for interfacing
 with 23*, a european photo sharing site that uses a Flickr-like API; this
 feature, though, is in beta state yet so please, notify me about any bugs
 you may find.

 More information in:
 @unorderedlist(
 @item Flickr API:@br http://www.flickr.com/services/api/
 @item 23 API Implementation notes:@br http://www.23hq.com/doc/api
 @item Rawflickr support:@br http://rawflickr.webhop.net
 )

 @bold(Maintainers:)
 @unorderedlist(
 @item LCM : Luis Caballero <rawflickr@lycos.es>
 )
 @bold(Credits:)
 @unorderedlist(
 @item MD5.pas, by Matthias Fichtner: http://www.fichtner.net/delphi/md5/
 @item LibXMLParser, by Stefan Heymann: http://www.destructor.de/
 @item Internet Direct (Indy) version 9.0: http://www.indyproject.org
 )
}

unit Rawflickr; {@LIB -nRawflickr -v121 -oLCM -pD5E.XP2}

{ TODO -oLCM : See rawflickr.todo.txt }
{$DEFINE DELPHI}

interface

uses
  windows, classes, sysutils, syncobjs, dialogs,{ Standard Units }
  DateTimeExt, StringsExt,                      { LCM Extensions }
  MD5, LibXMLParser;                            { Third-party    }

type

  {@abstract(Type of @link(TWebService.ServiceType))
   @seealso(TWebService)}
  TServiceType = (stNone, stFlickr, st23, stOther);

  {LCM: 2007-01-07}
  {@abstract(Type used to index the array of endpoint's URLs.)
   @seealso(TWebService.Endpoint)}
  TEndpoints = (epBaseRPC, epBaseSOAP, epBaseREST,
                epUpload, epReplace, epAuth, epLogout, epMethod);

  {@abstract(Part of the "multi-services" feature.)
   This class should be considered magic. Don't mess with it.}
  TWebService = class  {!LCM: 2007-01-07}
  private
    FServiceType: TServiceType;
    FBaseURI: String;
    procedure SetServiceType(const Value: TServiceType);
    procedure SetBaseURI(const Value: String);
    function GetEndpoint(Index: TEndpoints): String;
  public
    {@abstract(Type of service)}
    property ServiceType: TServiceType read FServiceType write SetServiceType;
    {@abstract(Base URI for endpoints)}
    property BaseURI: String read FBaseURI write SetBaseURI;
    {@abstract(Array of endpoint URIs relative to @link(BaseURI))}
    property Endpoint[Index: TEndpoints]: String read GetEndpoint;
    {@abstract(Class constructor)}
    constructor Create(Service: TServiceType = stFlickr);
  end;

  { Basic User Info}
  TBasicUser = class
  private
    FNSID,
    FUserName,
    FFullName: String;
  public
    {User ID on the web service}
    property NSID: String read FNSID write FNSID;
    {User's nickname}
    property UserName: String read FUserName write FUserName;
    {User's "real" name (as set in the profile)}
    property FullName: String read FFullName write FFullName;
  end;

  {LCM: 2007-01-09 - New base "Flickr" class.}
  {@abstract(Base service class)
   This class is the basic "service info" wrapper used as @code(Owner) in
   @link(TRESTApi) and descendants.

   Use this class only if you need single, manual instances of
   @link(TRESTApi) descendants; otherwise it'll we easier for you to instantiate
   a @link(TFlickrEx) object and access the API through its properties.}
  TFlickr = class
  private
    FApiKey, FSecret: String;
    FService: TWebService; {!LCM: 2007-01-07 - Changed from TServiceType}{}
    FToken,  FLevel: String;
    FUser      : TBasicUser;
    procedure SetApiKey(AKey: String);
    procedure SetSecret(ASecret: String);
    function GetService: TWebService;
    function GetUser: TBasicUser;
  public
    {@abstract(API key associated to the application.)
     Actually, setting it does no more than setting a private field used
     by @link(TRESTApi.SimpleCall) and @link(TRESTApi.SignedCall), but
     as it has other implications this will probably change in the future.

     To access Flickr you must use a valid key issued by them (along with the
     associated shared secret, see @link(Secret)). For 23, though, you can use
     any random string (they suggest your application name) or the same key
     as for Flickr (which I don't recommend).}
    property ApiKey: String read FApiKey write SetApiKey;
    {
     @abstract(The shared secret associated with your API key.)
     Actually, setting it does no more than setting a private field used
     by @link(TRESTApi.SignedCall) to build the request's signature, but
     as it has other implications this will probably change in the future.

     Note that 23 doesn't issues API keys and thus they neither need or use
     a shared secret to sign calls.}
    property Secret: String read FSecret write SetSecret;
    {
     @abstract(Type of service we'are going to use.)
     This property determines the URI of the API endpoint and how signed
     calls (see @link(TRESTApi.SignedCall)) are signed.

     Setting @link(Service.ServiceType) will also change @link(Service.BaseURI)
     to the corresponding @link(KnownBaseURI); if needed, you can later set a
     different @link(Service.BaseURI) p.e. if you set:
     @code(Service.ServiceType := stOther).

     By itself, @link(Service.ServiceType) determines how calls are signed.
     Services other than Flickr ---p.e. 23--- issue neither API keys or secrets
     and, thus, don't need the MD5 signatures. Since sending a signature when
     it's not needed represents a security risk, we don't do it.

     @bold(2007-01-07): This property has been completely reimplemented; if you
     have code like the old recommended:
     @longcode(%
     flickr.Service := st23;
     UseEndPoint(ep23);
     flickr.ApiKey := 'My23ApiKey';
     %) you should change it to something like:
     @longcode(%
     flickr.Service.ServiceType := st23;
     flickr.ApiKey := 'My23ApiKey';
     %)
     @seealso(TWebService)}
    property Service: TWebService read GetService;
    {@abstract(Authentication token.)
     The value of this property is updated every time you call
     @link(TAuth.checkToken), @link(TAuth.getToken) or
     @link(TAuth.getFullToken).
     You can set it directly if you have a valid token from a previous
     authentication but in that case you may better use @link(TAuth.checkToken);
     that way you won't only ensure that the token is still valid, but also
     update @link(TFlickr.User) with the correct user's info.}
    property Token: String read FToken write FToken;
    {@abstract(Permissions level for which the token--if any--is valid.)
     It will be updated by a successful call to any of the @link(TAuth)
     methods that either use it or get it from its response (Note
     that @link(TAuth) methods always parse its responses.)}
    property Level: String read FLevel write FLevel;
    {@abstract(Basic user info)}
    property User: TBasicUser read GetUser;
    {@abstract(Class constructor.)
     @seealso(ApiKey)
     @seealso(Secret)
     @seealso(Service)}
    constructor Create(AKey, ASecret: String;
                       AService: TServiceType = stFlickr);
  end;

  {Enumeration used in TRESTApi constructor.}
  TSignOption = (sgnRequired, sgnAlways);

  {@abstract(Class reference to @link(EFlickrError) and descendants.)}
  EFlickrErrorClass = class of EFlickrError;

  {@abstract(Base exception class for errors returned from the backend.)
   This exception should only be raised if the REST payload is invalid or
   contains a 'fail' response. You can find a example of use in the
   implementation of @link(TRESTApi.ParseResponse).}
  EFlickrError = class(Exception)
  private
    FCode: Integer;
  public
    {Numeric code parsed from a fail response. }
    property Code: Integer read FCode write FCode;
  end;

  {@abstract(Exception class for invalid response or unrecognised RSP status.)}
  EFlickrBadResponse = class(EFlickrError);

  {@abstract(Base REST API Implementation.)
   This generic, base class implements most of the behaviour needed to access
   a web service. It was built specifically to access Flickr(tm) but you may
   probably descend from it the classes needed for services using a like API
   paradigm.

   Even though it isn't an abstract one, you shouldn't need to make instances
   of this class; rather, derive a child class implementing the specific
   behaviour you need, like this library does.}
  TRESTApi = class
  private
    FSignAll: Boolean;    {! SignAll property storage }
    FRequest: TWebParams; {! Request property storage }
    FOwner: TFlickr;      {! Owner property storage   }
    FThrottle: Cardinal;  {! Throttle property storage }
    FRandomWait: Boolean; {! RandomWait property storage}
    FErrorClass: EFlickrErrorClass; {! Exception to raise on RSP fail}
    FResponse: String;    {! Latest response property storage}
    FLockCount: Integer; {! Multithreading. Not yet documented. }
    FCriticalSection: TCriticalSection;{! Multithreading. Not yet documented. }
  protected
    { Multithreading. Not yet documented. }
    procedure Lock;
    { Multithreading. Not yet documented. }
    procedure UnLock;
    {Prepares and issues a signed call to the endpoint }
    function SignedCall(const method: String): String; dynamic;
    {Prepares and issues an unsigned call to the endpoint unless
    @link(SignAll) = @True, in which case control will be transferred to
    @link(SignedCall).}
    function SimpleCall(const method: String): String; dynamic;
    {Default response parser. All it does is to build a INI-like structure
      using a simple @code(XMLToStrings) function }
    procedure ParseResponse(resp: String); dynamic;
    {@abstract(Tells @classname when to issue signed call)
     When set to @true @classname will issue @bold(all) calls as signed,
     even if made through @link(SimpleCall).}
    property SignAll: Boolean read FSignAll write FSignAll default False;
  public
    {@abstract(REST response checking.)
     This method checks whether a REST response status is "fail", "ok" or
     isn't valid---i.e. the status is neither of those two or it isn't even
     a valid XML REST payload.
     @raises(EFlickrError descendant if the status is "fail".)
     @raises(EFlickrBadResponse if the status is neither "fail" or "ok",
             case that includes invalid REST payloads.)}
    procedure CheckError(XMLResp: String);
    {@abstract(Saves a response into a stream.)
     Since the response is saved after checking it with @link(CheckError) and
     @link(CheckError) raises an exception on error conditions, you can only
     save valid, non-fail responses with this procedure.}
    procedure CheckAndSave(XMLResp: String; Stream: TStream); overload;
    {@abstract(Saves a response into a file.)
     All this method does is to create a file stream and then call the
     "stream" variant. See its notes}
    procedure CheckAndSave(XMLResp, FileName: String); overload;
    {@abstract(Generic Flickr method call)
     All it does is select and call either SimpleCall or SignedCall, depending
     of the value of the parameter @code(Signed)}
    function FlickrCall(const method: String; Signed: Boolean = False): String;
                                                                        virtual;
    {@abstract(Request parameters for a call to flickr.)
     Use this property to set the parameters of the request if you're
     implementing a flickr method in a @link(TRESTApi) descendant.
     Other users of the library should consider this value as read-only; after
     a flickr method call you'll find here all the parameters as passed to the
     HTTP client.}
    property Request: TWebParams read FRequest write FRequest;
    {@abstract(Latest RSP received from the web service. Read-only.)}
    property LastResponse: String read FResponse;
    {@abstract(@link(TFlickr) or descendant "owning" this class' instance.)
     Though this "ownership" is a somewhat difussed concept, all descendants
     of this class get fields from its @code(Owner), so you need to provide
     them a valid instance of @link(TFlickr)--of course, unless the object
     is indeed a @code(TFlickr) instance's property.}
    property Owner: TFlickr read FOwner;
    {@abstract(Controls a delay between calls.)
     If non-zero, any call to ??? will wait for 'value' 100th of seconds
     before returning, thus implementing a crude "bandwidth" control.}
    property Throttle: Cardinal read FThrottle write FThrottle default 10;
    {@abstract(Controls how @link(Throttle) will be interpreted.)
     If set, @link(Throttle) will be interpreted as the maximum wait value,
     rather than as an uniform wait value.}
    property RandomWait: Boolean read FRandomWait write FRandomWait;
    {Class reference for exceptions raised for invalid or "fail" responses }
    property  ErrorClass: EFlickrErrorClass read FErrorClass
                                            write FErrorClass;
    {@abstract(Default class constructor.)
    @param(AOwner TFlickr instance that "owns" the object.)
    @param(Sign  @code(sgnAlways): Issue always signed calls@br
                 @code(sgnRequired): Sign call only when required (default)) }
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
    destructor Destroy; override;
  end;

  {@abstract(Implements flickr.activity.* methods)}
  TActivity = class(TRESTApi)
  public
    {@abstract(Implements flickr.activity.userComments)}
    function userComments(perPage: Integer = 0; page : Integer = 0): String;
    {@abstract(Implements flickr.activity.userPhotos)}
    function userPhotos(timeframe: String = '';
                        perPage: Integer = 0; page : Integer = 0): String;
    {Class constructor; see @link(TRESTApi.Create)}
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {@abstract(Descendant of @link(EFlickrError) used in @code(TAuth).)}
  EFlickrAuthError = class(EFlickrError);

  {@abstract(Implements flickr.auth.* methods.)
   The authentication process for Flickr is explained in the document
   "Authentication API" <http://www.flickr.com/services/api/auth.spec.html>.
   For 23, consult "User authentication" at <http://www.23hq.com/doc/api/auth> }
  TAuth = class(TRESTApi)
  private
    FFrob: String;
  protected
    {Parses checkToken / getToken RSP and (if sucessful) updates
     TFlickr(Owner).UserInfo, Token and Level (i.e. the account info).}
    procedure ParseResponse(resp: String); override;
    {Parses a getFrob response and returns (if sucessful) a frob.}
    function ParseFrobResp(resp: String): String;
  public
    {Read Only. Write access is banned because all auth calls are signed }
    property SignAll: Boolean read FSignAll;
    {Implements flickr.auth.checkToken
     As a collateral effect it updates the Owner's account info i.e.
     @code(UserInfo), @code(Token) and @code(Level) (see @link(TFlickr))}
    function checkToken(Token: String): String;
    {Implements flickr.auth.getFrob.
     @bold(NOTE) that this call doesn't return any XML payload. It will
     instead try to parse the response and return the frob; If it doesn't
     succeeds you'll receive an exception raised from the default parser.}
    function getFrob: String;
    {Implements flickr.auth.getFullToken.
     Same collateral effects that @link(checkToken)}
    function getFullToken(miniToken: String): String;
    {Implements flickr.auth.getToken.
    Same collateral effects that @link(checkToken)}
    function getToken(frob: String): String;
    {Returns an AnsiString containing the unencoded URI to which the user
      must navigate in order to authenticate the application.}
    function GetLoginLink(perms: String; frob: String): String;
    {Returns a WideString containing the unencoded URI to which the user
      must navigate in order to authenticate the application.}
    function GetLoginLinkW(perms: String; frob: String): WideString;
    {Class constructor.
     Unlike the inherited one, it doesn't accept a @link(TSignOption)
     parameter. Since all flickr.auth.* methods must be signed, I
     introduced this constraint to circumvent an already corrected
     bug in Flickr and prevent a common error.}
    constructor Create(Owner: TFlickr);{SignAll isn't needed, since all auth
                                        calls have to be signed. }
  end;

  {@abstract(Record used for @link(TBlogs.postPhoto))}
  TBlogPhoto = record
    blogId,
    photoId,
    title,
    description,
    blogPassword: String;
  end;

  {Implements flickr.blogs.*}
  TBlogs = class(TRESTApi)
  public
    {Implements flickr.blogs.getList}
    function getList: String;
    {Implements flickr.blogs.postPhoto ('record' variant)}
    function postPhoto(Photo: TBlogPhoto): String; overload;
    {Implements flickr.blogs.postPhoto (API variant)}
    function postPhoto(blogId, photoId, title, description,
                       blogPassword: String): String; overload;
    {Class constructor; see @link(TRESTApi.Create)}
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {@abstract(Implements flickr.commons.*)}
  TCommons = class(TRESTApi)
  public
    {Implements flickr.commons.getInstitutions}
    function getInstitutions: String;
    {Class constructor; see @link(TRESTApi.Create)}
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;


  {Implements flickr.contacts.*}
  TContacts = class(TRESTApi)
  public
    {Implements flickr.contacts.getList}
    function getList(filter: String = '';
                     Page: Integer = 0; perPage: Integer = 0): String;
    {Implements flickr.contacts.getPublicList}
    function getPublicList(UserId: String;
                           Page: Integer = 0; perPage: Integer = 0): String;
    {Class constructor; see @link(TRESTApi.Create)}
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Combines Flickr lists parameters @code(page) and @code(per_page)}
  TPageSet = record
    perpage: Integer; //<[1..MaxInt], else omitted (use flickr's default)
    page: Integer;    //<{No. of the page to get; if 0, use flickr's default
  end;

  {@abstract(Extra params used in photo-list's calls.)
    Flickr methods that return a list of photos take these optional
    arguments to refine the response. Using a record allows you
    to set them once for all with @link(BuildXtraParams) or use the
    predefined constants @link(EmptyXtra) and @link(FullXtras).}
  TXtraParams = record
    {@abstract(extra info to retrieve)
     See @link(AllXtras) for a list of values available} 
    extras: String; 
    perpage: Integer; {<[1..500], else omitted (which usually means 100)}
    page: Integer;    {<For multipage lists, no. of the page to get.}
  end;

  {Implements flickr.favorites.*}
  TFavorites = class(TRESTApi)
  public
    {Implements flickr.favorites.getList (record variant)}
    function getList(userId: String; extra: TXtraParams): String; overload;
    {Implements flickr.favorites.getList (API-like variant)}
    function getList(userId: String; extras: String=''; perPage: Integer = 0;
                     Page: Integer = 0): String; overload;
    {Implements flickr.favorites.getPublicList}
    function getPublicList(userId: String; extra: TXtraParams): String;
    {Implements flickr.favorites.Add}
    function Add(PhotoId: String): String;
    {Implements flickr.favorites.Remove}
    function Remove(PhotoId: String): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  TPools = class; {! forward }

  {Implements flickr.groups.*}
  TGroups = class(TRESTApi)
  private
    FPools: TPools;
    function GetPools: TPools;
  public
    {Provides access to a @link(TPools) instance}
    property Pools: TPools read GetPools;
    {Implements flickr.groups.browse}
    function browse(catId: Integer = 0): String;
    {Implements flickr.groups.getInfo}
    function getInfo(groupId: String; lang: String=''): String;
    {Implements flickr.groups.search}
    function search(text: String;
                    perpage: Integer = 0; page: Integer = 0;
                    Plus18: Boolean = True): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
    destructor Destroy; override;
  end;

  {Implements flickr.groups.pools.*}
  TPools = class(TRESTApi)
  public
    {Implements flickr.groups.pools.getGroups}
    function getGroups(Page: Integer = 0; perPage: Integer = 0): String;
    {Implements flickr.groups.pools.getPhotos}
    function getPhotos(groupId: String; Tags: String; userId: String;
                       extra: TXtraParams): String;
    {Implements flickr.groups.pools.getContext}
    function getContext(photoId, groupId: String): String;
    {Implements flickr.groups.pools.add}
    function Add(photoId, groupId: String): String;
    {Implements flickr.groups.pools.remove}
    function Remove(photoId, groupId: String): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.interestingness.*}
  TInterestingness = class(TRESTApi)
  public
    {Implements flickr.interestingness.gtList}
    function getList(ADate: TDateTime; extra: TXtraParams): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.people.*}
  TPeople = class(TRESTApi)
  public
    {Implements flickr.people.findByEmail}
    function findByEmail(email: String): String;
    {Implements flickr.people.findByUsername}
    function findByUsername(username: String): String;
    {Implements flickr.people.getInfo}
    function getInfo(userId: String): String;
    {Implements flickr.people.getPublicGroups}
    function getPublicGroups(userId: String): String;
    {Implements flickr.people.getPublicPhotos}
    function getPublicPhotos(userId: String; extra: TXtraParams): String;
    {Implements flickr.people.getUploadStatus}
    function getUploadStatus: String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  TComments = class;  {!forward;}
  TGeoData = class;   {!forward;}
  TLicenses = class;  {!forward;}
  TNotes = class;     {!forward;}
  TTransform = class; {!forward;}
  TUploader = class;  {!forward;}

  {}
  TPrivacyFilter = (pfNone, pfPublic, pfFriends, pfFamily, pfFriendsFamily,
                    pfPrivate); {!@LCM 2006-07-04; corrected 2006-10-30}

  (*!@LCM 2008-04-27 - NEW SEARCH PARAMETERS TYPES***)
  {@abstract(Tags and machine tags search modes.)
   @seealso(TagModes)}
  TTagSearchMode = (tmAny, tmAll, tmOther);
  {Text, tags and machine tags record, for flickr.photos.search  }
  TSearchTerms = record
    tags, machineTags: String;
    tagMode, machineTagMode: TTagSearchMode;
    text: String;
  end;

  {@abstract(Set of coordinates pairs that determine a geo bounding box)
   Make sure to pass values in the intervals [-180..180] for longitud and
   [-90..90] for latitude, or the whole box will be discarded.}
  TBoundBox = record
    MinLongitude,MinLatitude,
    MaxLongitude, MaxLatitude: Double;
  end;

  {@abstract(Accuracy level of location information)
   The range 1..16 is Flickr's current range, meaning:
   @unorderedlist(
    @item World level is 1
    @item Country is ~3
    @item Region is ~6
    @item City is ~11
    @item Street is ~16
    )
    while "0" (zero) represents an "unspecified" value}
  TGeoAccuracy = 0..16;

  {@abstract(Values used in @link(TGeoTerms.validFields))}
  TValidGeoFields = (gfBbox, gfPlaces, gfHasGeo, gfRadial);

  {Record used for "radial" geo-searches}
  TRadialQuery = record
    lat, lon: Double;
    radius: ShortInt;
    radiusUnits: String;
  end;

  {@abstract(Geo related search terms)
   This record all geo-location related search terms. To select which fields
   are used, set @link(validFields) acordingly.}
  TGeoTerms = record
    validFields: set of TValidGeoFields;
    hasGeo: Boolean;            {LCM: 2008-06-29}{}
    bbox: TBoundBox;
    RadialQuery: TRadialQuery;  {LCM: 2008-06-29}{}
    woeId,
    placeId: String;
    accuracy: TGeoAccuracy;
  end;

  {@abstract(Content types)}
  TContentType = (ctNone, ctPhoto, ctScreen, ctOther,
                  ctPhotoScreen, ctScreenOther, ctPhotoOther, ctAll);

  {@abstract(Media types)
  @unorderedlist(
  @item mediaDefault, use Flickr's default.
  @item mediaStill, for the traditional media: photos, drawings, etc.
  @item mediaMotion, for the "video" media.
  @item mediaAll, for both.
  )}
  TMediaType = (mediaDefault, mediaStill, mediaMotion, mediaAll);

  {Safety level for any type of content}
  TSafetyLevel = (slIgnore, slSafe, slModerate, slRestricted);

  {@abstract(Content related search terms)
   Includes content type, safety level, privacy, license, etc. filters }
  TContentFilter = record
    contentType: TContentType;
    media: TMediaType;
    license: ShortInt;
    privacy: TPrivacyFilter;
    safety: TSafetyLevel;
  end;
  (*********************************************)

  {Old-style TPhotos.search parameters record}
  TPhotoSearchParams = record
    tags, tagMode: String;
    text: String;
    Uploaded,
    Taken    : TDateRange;
    license: ShortInt; {< if -1, don't use; NOTE! that 0 is a valid code }{}
    privacy: TPrivacyFilter;  {!@LCM 2006-07-04}{}
    media: String; {!@LCM 2008-04-09 - 'all', 'photo' or 'video'}{}
  end;

  {Type of the "sort" parameter passed to methods that return a list.
  @Seealso(SortOrderStr)}
  TSortOrder = (soDefault, soPostedAsc, soPostedDesc,
                           soTakenAsc, soTakenDesc,
                           soInterestAsc, soInterestDesc,
                           soRelevance);
  {Kind of date/time requested or returned.}
  TDateKind = (dkTaken, dkPosted, dkUpdated);
  {Accuracy level of a date/time.
   At the date of this writing there are only three valid values, (see the
   constants dgExact, dgMonth and dgYear); but according to Flickr docs (see
   http://www.flickr.com/services/api/misc.dates.html
   @html(<blockquote><em>In the future, additional granularities may be added,
   so for future compatability you might want to build you application to
   accept any number between 0 and 10 for the granularity.</em><br></blockquote>)

   }
  TDateGranularity = 0..10;

  {! Was TPrivacy; TVisible seems a better name.
   toPrivate is used only in uploads, because an empty set means 'default' }{}
  TVisible = (toPublic, toFriends, toFamily, toPrivate);
  TVisibility = set of TVisible;
  TPermission = (permOwner, permFriendsFamily, permContacts, permPublic);
  TPermissions = set of TPermission;

  {Implements flickr.photos.*}
  TPhotos = class(TRESTApi)
  //private
  public
    {Provides access to a @link(TComments) instance}
    Comments: TComments;
    {Provides access to a @link(TGeoData) instance}
    Geo: TGeoData;
    {Provides access to a @link(TLicenses) instance}
    Licenses: TLicenses;
    {Provides access to a @link(TNotes) instance}
    Notes: TNotes;
    {Provides access to a @link(TTransform) instance}
    Transform: TTransform;
    {Provides access to a @link(TUploader) instance.
     To avoid a name clash (and repetition), this property isn't named as
     its Flickr counterpart flickr.photos.upload}
    Uploader: TUploader; {@WARNING: Doesn't follow naming convention}
    // methods related to general photo lists
    {@abstract(Implements flickr.photos.search)
     You can use this old, limited variant for simple searches, more or less
     like the normal search in the site.}
    function search(userId: String; searchParams: TPhotoSearchParams;
                    extra: TXtraParams;
                    sort: TSortOrder = soDefault): String; overload;
    {@abstract(Implements flickr.photos.search)
     This is the new, fully updated variant using a new set of logically
     arranged parameters.}
    function search(userId, groupId: String;
                    SearchTerms: TSearchTerms;
                    Uploaded, Taken: TDateRange;
                    GeoTerms: TGeoTerms;
                    ContentTerms: TContentFilter;
                    extra: TXtraParams;
                    sort: TSortOrder = soDefault): String; overload;
    {Implements (flickr.photos.)getContactsPhotos and getContactsPublicPhotos.
     getContactsPublicPhotos is called if a non-empty userId is passed to the
     function; otherwise it calls getContactsPhotos, as expected.}
    function getContactsPhotos(userId: String= ''; {see below}
                               count: Integer=0;
                               justFriends: Boolean = False;
                               singlePhoto: Boolean = False;
                               includeSelf: Boolean = False;
                               extras: String = ''): String; {cf. TXtraParams}
    {function getContactsPublicPhotos is embedded in getContactsPhoto;
      If a userId is passed to getContactsPhotos, the call will be
      made instead to flickr.contacs.getContactsPublicPhotos
      Whether the later will be signed or not depends on SignAll {}
    // Related to lists of user's photos
    {Implements flickr.photos.getCounts}
    function getCounts(Uploaded, Taken: array of TDateTime): String;
    {Implements flickr.photos.getNotInSet}
    function getNotInSet(sort: TSortOrder; extra: TXtraParams): String;
    {Implements flickr.photos.getRecent}
    function getRecent(extra: TXtraParams): String;
    {Implements flickr.photos.getUntagged}
    function getUntagged(extra: TXtraParams): String;
    {Implements flickr.photos.recentlyUpdated}
    function recentlyUpdated(minDate: TDateTime; extra: TXtraParams): String;
    {Implements flickr.photos.getWithGeoData}
    function getWithGeoData(Uploaded, Taken: TDateRange;
                            Privacy: TPrivacyFilter;
                            extra: TXtraParams;
                            Sort: TSortOrder = soDefault): String;
    {Implements flickr.photos.getWithoutGeoData}
    function getWithoutGeoData(Uploaded, Taken: TDateRange;
                            Privacy: TPrivacyFilter;
                            extra: TXtraParams;
                            Sort: TSortOrder = soDefault): String;
    // Related to single photos
    {Implements flickr.photos.getContext}
    function getContext(photoId: String): String;
    {Implements flickr.photos.getAllContexts}
    function getAllContexts(photoId: String): String;
    {Implements flickr.photos.getExif}
    function getExif(photoId: String; secret: string = ''): String;
    {Implements flickr.photos.getInfo}
    function getInfo(photoId: String; secret: string = ''): String;
    {Implements flickr.photos.getPerms}
    function getPerms(photoId: String): String;
    {Implements flickr.photos.getSizes}
    function getSizes(photoId: String): String;
    {Implements flickr.photos.getFavorites}
    function getFavorites(photoId: String; perPage: Integer = 0;
                          page : Integer = 0): String; {LCM: 2008/03/31}
    {Implements flickr.photos.setDates}
    function setDates(photoId: String;
                      Posted: TDateTime = 0.0; Taken: TDateTime = 0.0;
                      takenAprox: TDateGranularity = 0{dgExact}): String;
    {Implements flickr.photos.setMeta}
    function setMeta(photoId, Title, Description: String) : String;
    {Implements flickr.photos.setPerms}
    function setPerms(photoId: String; Visibility: TVisibility;
                      PermitComments, PermitMeta: TPermission) : String;
    {Implements flickr.photos.setContentType (2008-04-02)}
    function setContentType(photoId: String;
                            ContentType: TContentType): String;
    {Implements flickr.photos.setSafetyLevel (2008-04-02)}
    function setSafetyLevel(photoId: String; Level: TSafetyLevel;
                            Hide: Boolean): String; overload;
    {Implements flickr.photos.setSafetyLevel (2008-04-02)
     Use this variant to change the safety level w/out affecting 'hide'}
    function setSafetyLevel(photoId: String;
                            Level: TSafetyLevel): String; overload;
    {Implements flickr.photos.setTags}
    function setTags(photoId, tags: String): String;
    {Implements flickr.photos.addTags}
    function addTags(photoId, tags: String): String;
    {Implements flickr.photos.removeTag}
    function removeTag(tagId: String): String;
    {Implements flickr.photos.delete}
    function delete(photoId: String): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
    destructor Destroy; override;
  end;

  {@abstract(Implements flickr.photos.comments.* and
   flickr.photosets.comments.*)
   TComments is polimorphic and depends of BaseGroup and BaseIdName to know
   which group and Id names to use on calls to the Flickr API}
  TComments = class(TRESTApi)
  private
    FBaseGroup,
    FBaseIdName: String;
  public
    {Name of the base group of calls.
     @bold(BaseGroup) is used to build the 'method' parameter in the call to
     the web service; p.e. for flickr.@bold(photosets).comments.* you would
     make:

     @code(BaseGroup := 'photosets';)

     Both @link(TPhotos) and @link(TPhotosets) do this themselves when they
     create their @code(Comments) property; you don't need to do it yourself.}
    property BaseGroup: String read FBaseGroup;  {Group, p.e. 'photosets'}
    {Name of the base ID to use in the call to the web service.
     @bold(BaseIdName) is used to build the 'xxx_id' parameter for the web
     service call; p.e. flickr.photos.comments.* uses a parameter called
     @code(photo_id), so you would do:

     @code(Comments.BaseIdName := 'photo';).

     @bold(Note): Both @link(TPhotos) and @link(TPhotosets) do this themselves
     when they create their @code(Comments) property; you don't need to do it
     yourself.}
    property BaseIdName: String read FBaseIdName;
    {Implements flickr.*.comments.getList
    @param(entityId corresponds to either photo_id or photoset_id, depending
             of @link(BaseIdName))}
    function getList(entityId: String): String;
    {Implements flickr.*.comments.addComment}
    function addComment(entityId, text: String): String;
    {Implements flickr.*.comments.deleteComment}
    function deleteComment(commentId: String): String;
    {Implements flickr.*.comments.editComment}
    function editComment(commentId, text: String): String;
    constructor Create(AOwner: TFlickr; ABaseGroup, ABaseIdName: String;
                       Sign: TSignOption = sgnRequired);
  end;

  TLocPrivacy = (lpPublic, lpContacts, lpFriends, lpFamily, lpPrivate);
  TViewPerm = set of TLocPrivacy;

  {Yeah, I know; this next class should have been called TGeo but I thought
   that the name was too short and prone to namespace collisions.}
  {@abstract(Implements flickr.photos.geo.*)}
  TGeoData = class(TRESTApi)
    {Implements flickr.photos.geo.getPerms}
    function getPerms(photoId: String): String;
    {Implements flickr.photos.geo.setPerms}
    function setPerms(photoId: String; ViewPerm: TViewPerm): String;
    {Implements flickr.photos.geo.getLocation}
    function getLocation(photoId: String): String;
    {Implements flickr.photos.geo.setLocation}
    function setLocation(photoId: String;
                         Latitude, Longitude: Double;
                         Accuracy: TGeoAccuracy): String;
    {Implements flickr.photos.geo.removeLocation}
    function removeLocation(photoId: String): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.photos.licenses.*}
  TLicenses = class(TRESTApi)
  //private
  public
    {Implements flickr.photos.licenses.getInfo
     Since this method returns a static list (or at least one that hasn't
     changed in years), consider calling it just once and store the data
     locally; then call it again either once every X months or when you know
     it has changed.}
    function getInfo: String;
    {Implements flickr.photos.licenses.setLicense}
    function setLicense(photoId: String; licenseId: ShortInt): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Used to pass note info to methods of @link(TNotes)}
  TNoteRecord = record
    Id: String; {< Note's Flickr Id}
    Left, Top, Width, Height: Word; {< Note's bounding rectangle }
    Text: String;{< Note's content}
  end;

  {Implements flickr.photos.notes.*}
  TNotes = class(TRESTApi)
  //private
  public
    {Implements flickr.photos.notes.add}
    function Add(photoId: String; note: TNoteRecord): String;
    {Implements flickr.photos.notes.delete}
    function Delete(noteId: String): String;
    {Implements flickr.photos.notes.edit}
    function Edit(note: TNoteRecord): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.photos.transform.*}
  TTransform = class(TRESTApi)
  //private
  public
    {Implements flickr.photos.transform.rotate}
    function Rotate(photoId: String; degrees: Integer): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {@inherited descendant for upload errors}
  EFlickrUploadError = class(EFlickrError);

  {Use to bypass the default 'searchability' on uploads}
  TSearchStatus = (ssIgnore, ssSearchable, ssHidden);

  {Implements flickr.photos.upload.* and the Photo Upload/Replace API }
  TUploader = class(TRESTApi)
  //private
  protected
    {!Builds a proper FRequest to be used with the Upload API.}
    procedure GetUploadRequest(Title: String; Description: String;
                               Tags: String; Visibility: TVisibility;
                               Safety: TSafetyLevel; Content: TContentType;
                               hideIt: TSearchStatus; Asynchronous: Boolean);
    {!Builds a proper FRequest to be used with the Replace API.}
    procedure GetReplaceRequest(photoId: String; Asynchronous: Boolean);
  public
    {Implements flickr.photos.upload.checkTickets.
     This variant takes a comma-delimited list of ticket ids.}
    function checkTickets(tickets: String): String; overload;
    {Implements flickr.photos.upload.checkTickets.
     This variant takes an array of single ticket ids.}
    function checkTickets(tickets: array of String): String; overload;
    {@abstract(Uploads a photo (u other media) to the web service.)
     The @code(Stream) parameter of this function has preference over
     @code(Filename), meaning that if you pass a valid stream to the
     function, @code(Filename) won't be validated and will be passed as such.
     If @code(Stream) is @nil, however, the local file pointed to by
     @code(Filename) must exist and be readable, since it will be opened
     as a @code(TFileStream) and sent; i.e. this two code snippets are
     equivalent:
     @longcode(%
     // using Stream:
     AFileName := '\My Pictures\incredible.jpg';
     fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
     AFileName := 'whatever you want'; // @italic(it doesn't matter at all...)
     response := Flickr.Photos.Uploader.Upload(fs, AFileName, 'nice photo');

     // using just filename
     AFileName := '\My Pictures\incredible.jpg';
     response := Flickr.Photos.Uploader.Upload(nil, AFileName, 'nice photo');
     %)
     @param(Stream TStream which contains the graphic data to upload; if
            this parameter is @nil, @code(Filename) will be
            interpreted as the name of a local file to upload.)
     @param(Filename Name of the file to send on the request;
            if @code(Stream) is @nil, the file pointed to by @code(Filename)
            will be opened as a @code(TFileStream) and its content sent on
            the request as the photograph data; otherwise the name will be
            sent as the filename corresponding to @link(Stream). )}
    function Upload(Stream: TStream; Filename: String;
                    Title: String = '';
                    Description: String = '';
                    Tags: String = '';
                    Visibility: TVisibility = [];
                    Safety: TSafetyLevel = slIgnore;
                    Content: TContentType = ctNone;
                    hideIt: TSearchStatus = ssIgnore;
                    Asynchronous: Boolean = False): String;
    {Replaces an already uploaded photo for a new one.
     @Seealso(TUploader.Upload to know how @code(Stream) and
              @code(Filename) are interpreted)}
    function Replace(Stream: TStream; Filename: String;
                     photoId: String;
                     Asynchronous: Boolean = False): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.photosets.*}
  TPhotosets = class(TRESTApi)
  private
    FComments: TComments;
    function GetComments: TComments;
  public
    property Comments: TComments read GetComments;
    // These treats the whole bunch of sets
    {Implements flickr.photosets.*}
    function getList(userId: String = ''): String;
    {Implements flickr.photosets.*}
    function orderSets(setIds: array of String): String;
    // These, for rummaging through individual sets
    { I renamed photosets.create and photosets.delete; the former because
      its name clashed with the constructor and the later for consistency }
    {Implements flickr.photosets.create.
    Renamed to @name to avoid a name clash with the constructor}
    function createSet(title, primaryId: String;
                       description: String = ''): String;
    {Implements flickr.photosets.delete.
     Renamed to @name for consistency}
    function deleteSet(setId: String): String;
    {Implements flickr.photosets.getInfo}
    function getInfo(setId: String): String;
    {Implements flickr.photosets.editMeta}
    function editMeta(setId, title: String; description: String = ''): String;
    {Implements flickr.photosets.getPhotos}
    function getPhotos(setId: String; privacy: TPrivacyFilter;
                       extra: TXtraParams): String;
    {Implements flickr.photosets.editPhotos}
    function editPhotos(setId, primaryId: String;
                        photoIds: array of String): String;
    // And these deal with a photo inside a set
    {Implements flickr.photosets.addPhoto}
    function addPhoto(setId, photoId: String): String;
    {Implements flickr.photosets.removePhoto}
    function removePhoto(setId, photoId: String): String;
    {Implements flickr.photosets.getContext}
    function getContext(setId, photoId: String): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;
{ DONE 5 -oLCM -cBASE : New places & prefs classes }
  {Implements flickr.places.*}
  TPlaces = class(TRESTApi) {LCM 2008-04-08}
  public
    {Implements flickr.places.find}
    function find(query: String): String;
    {Implements flickr.places.findByLatLon}
    function findByLatLon(Latitude, Longitude: Double;
                          Accuracy: TGeoAccuracy = 0): String;
    {Implements flickr.places.resolvePlaceId}
    function resolvePlaceId(placeId: String): String;
    {Implements flickr.places.resolvePlaceURL}
    function resolvePlaceURL(placeURL: String): String;
    {Class constructor, for completeness sake}
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.prefs}
  TPrefs = class(TRESTApi)
    {Implements flickr.prefs.getContentType *}
    function getContentType: String;
    {Implements flickr.prefs.getGeoPerms *}
    function getGeoPerms: String;
    {Implements flickr.prefs.getHidden *}
    function getHidden: String;
    {Implements flickr.prefs.getPrivacy *}
    function getPrivacy: String;
    {Implements flickr.prefs.getSafetyLevel *}
    function getSafetyLevel: String;
    {Class constructor, for completeness sake}
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.reflection.*}
  TReflection = class(TRESTApi)
  //private
  public
    {Implements flickr.reflection.getMethodInfo.
     @param(Name should be called @code(methodName) but I renamed it to avoid
            a clash with TObjects.methodName)}
    function getMethodInfo(Name: string): String;{param should be 'methodName'
                                                  but that's a TObject's member}
    {Implements flickr.reflection.getMethods}
    function getMethods: String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

{ TODO 5 -oLCM -cBase design : 
       It's not clear when the implementation should issue a signed call
       neither whether the method of making it signed when user_id = ''
       is correct or not. I'll have to re-think this}
  {Implements flickr.tags.*}
  TTags = class(TRESTApi)
  //private
  public
    {Implements flickr.tags.getHotList}
    function getHotList(period: String=''; count: Integer = 0): String;
    {Implements flickr.tags.getListPhoto}
    function getListPhoto(photoId: String): String;
    {Implements flickr.tags.getListUser}
    function getListUser(userId: String = ''): String;
    {Implements flickr.tags.getListUserPopular}
    function getListUserPopular(userId: String = '';
                                count: Integer = 0): String;
    {Implements flickr.tags.getListUserRaw (2008/03/31)}
    function getListUserRaw(userId: String = ''; tag: String = ''): String;
    {Implements flickr.tags.getRelated}
    function getRelated(tag: String): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Implements flickr.test.*}
  TTest = class(TRESTApi)
  //private
  public
    {Implements flickr.test.echo.
     This variant takes an array of INI strings ("name=value" pairs)}
    function echo(source: array of String): String; overload;
    {Implements flickr.test.echo.
     This variant takes a TStrings object; it should contain INI strings
     (i.e. "name=value" pairs)}
    function echo(source: TStrings): String; overload;
    {Implements flickr.test.login}
    function login: String;
    {Implements flickr.test.null}
    function null: String;
    {Generic call for methods testing.
    While it isn't part of the Flickr API, in can be useful as a debugging
    help; to bypass, if wanted, all the other classes or to call a web API
    method that is yet unimplemented.}
    function GenericCall(Method: String; Params: TStrings;
                         Signed: Boolean): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {@abstractImplements flickr.urls.*)
   All the calls in this class return static info, so they are good candidates
   for caching; you should cache, at least, the more frequently used info p.e.
   id - URI pairs of the user's groups, user pages URLs, etc.}
  TUrls = class(TRESTApi)
  //private
  public
    {Implements flickr.urls.getGroup}
    function getGroup(groupId: String): String;
    {Implements flickr.urls.getUserPhotos}
    function getUserPhotos(userId: String = ''): String;
    {Implements flickr.urls.getUserProfile}
    function getUserProfile(userId: String = ''): String;
    {Implements flickr.urls.lookupGroup}
    function lookupGroup(groupUrl: String): String;
    {Implements flickr.urls.lookupUser}
    function lookupUser(userUrl: String): String;
    constructor Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
  end;

  {Reason why a new authentication is needed}
  TAuthReason = (arNoToken, arLevelPromotion, arInvalidLoginOrToken,
                 arOther);
  {Type of the @link(TFlickrEx.OnAuthorize) event.}
  TAuthorizeEvent = procedure(Sender: TFlickr; LoginURL: String;
                              CancelReason: TAuthReason; var Cancel: Boolean);

  {@abstract(Extended web service class)
   This descendant of @link(TFlickr) introduces properties designed to
   provide access to Flickr API methods from a single object, as well
   as a single-call authorization process.
   }
  TFlickrEx = class(TFlickr)
  private
    FSignOption: TSignOption;
    FOnAuthorize: TAuthorizeEvent;
    FFrobRetries: ShortInt;
    FSignAll: Boolean;
    FAuth      : TAuth;
    FActivity  : TActivity;
    FBlogs     : TBlogs;
    FCommons   : TCommons;
    FContacts  : TContacts;
    FFavorites : TFavorites;
    FGroups    : TGroups;
    FInteresting: TInterestingness;
    FPeople    : TPeople;
    FPhotos    : TPhotos;
    FPhotosets : TPhotosets;
    FPlaces    : TPlaces;
    FPrefs     : TPrefs;
    FReflection: TReflection;
    FTags      : TTags;
    FTest      : TTest;
    FUrls      : TUrls;
    function GetAuth: TAuth;
    function GetActivity: TActivity;
    function GetBlogs: TBlogs;
    function GetCommons: TCommons;
    function GetContacts: TContacts;
    function GetFavorites: TFavorites;
    function GetGroups: TGroups;
    function GetInterestingness: TInterestingness;
    function GetPeople: TPeople;
    function GetPhotos: TPhotos;
    function GetPhotosets: TPhotosets;
    function GetPlaces: TPlaces;
    function GetPrefs: TPrefs;
    function GetReflection: TReflection;
    function GetTags: TTags;
    function GetTest: TTest;
    function GetUrls: TUrls;
    procedure SetSignAll(Value: Boolean);
  public
    {@abstract(Provides access to a @link(TAuth) instance.)}
    property Auth      : TAuth read GetAuth;
    {@abstract(Provides access to a @link(TActivity) instance.)}
    property Activity  : TActivity read GetActivity;
    {@abstract(Provides access to a @link(TBlogs) instance.)}
    property Blogs     : TBlogs read GetBlogs;
    {@abstract(Provides access to a @link(TCommons) instance.)}
    property Commons   : TCommons read GetCommons;
    {@abstract(Provides access to a @link(TContacts) instance.)}
    property Contacts  : TContacts read GetContacts;
    {@abstract(Provides access to a @link(TFavorites) instance.)}
    property Favorites : TFavorites read GetFavorites;
    {@abstract(Provides access to a @link(TGroups) instance...)
     and, through it, to a @link(TPools) instance.}
    property Groups    : TGroups read GetGroups;
    {@abstract(Provides access to a @link(TInterestingness) instance.)}
    property Interestingness: TInterestingness read GetInterestingness;
    {@abstract(Provides access to a @link(TPeople) instance.)}
    property People    : TPeople read GetPeople;
    {@abstract(Provides access to a @link(TPhotos) instance...)
     and, through it, to @link(TComments), @link(TGeoData), @link(TLicenses),
     @link(TNotes), @link(TTransform) and @link(TUploader) instances.}
    property Photos    : TPhotos read GetPhotos;
    {@abstract(Provides access to a @link(TPhotosets) instance...)
     and, through it, to a @link(TComments) instance.}
    property Photosets : TPhotosets read GetPhotosets;
    {@abstract(Provides access to a @link(TPlaces) instance.)}
    property Places : TPlaces read GetPlaces;
    {@abstract(Provides access to a @link(TPrefs) instance.)}
    property Prefs : TPrefs read GetPrefs;
    {@abstract(Provides access to a @link(TReflection) instance.)}
    property Reflection: TReflection read GetReflection;
    {@abstract(Provides access to a  @link(TTags) instance.)}
    property Tags      : TTags read GetTags;
    {@abstract(Provides access to a @link(TTest) instance.)}
    property Test      : TTest read GetTest;
    {@abstract(Provides access to a @link(TUrls) instance.)}
    property Urls      : TUrls read GetUrls;
    {@abstract(Performs a desktop authorization process.)}
    function Authorize(Perms: String = ''; Token: String = ''): Boolean;
    {@abstract(Class constructor.)
     For Flickr, you must have a valid API key and secret. For 23 you can use
     any arbitrary key (though they recommend it to be the application name)
     and AFAIK you don't need any "Secret", given that their authenticated
     calls are different.}
    constructor Create(AKey, ASecret: String;
                       AService: TServiceType = stFlickr);
    destructor Destroy; override;
    {Sets @code(SignAll) to @true or @false coordinately for all
     @link(TRESTApi) descendant members of TFlickr.}
    property SignAll: Boolean read FSignAll write SetSignAll default False;
    {@abstract(End user participation needed.)
     This event is called from @link(Authorize) if the authentication process
     reachs the point in which it needs the participation of the user i.e.
     when we need to navigate to Flickr (or 23) prior to request a token.
     For details see http://www.flickr.com/services/api/misc.userauth.html
     Though the library offers a default event handler for this task, don't
     rely on it; being non-portable in nature, it'll probably dissapear in
     one of the next releases.}
    property OnAuthorize: TAuthorizeEvent read FOnAuthorize
                                          write FOnAuthorize;
  end;

(*
  {@abstract(Set of services whose API endpoints are known.)
   @seealso(@link(EndPoints) constant array contains the endpoints URIs }
  TApiEndPoint = (epFlickr, ep23, epTest); {LCM 20060831: Prog. EndPoints}
*)
{ Helper functions/procedures }

{@abstract(Build a TXtraParams record.)
 Use this function to build a @link(TXtraParams) record
 suitable for most of the API calls that return lists.
 @bold(Note) that @code(foo := BuildXtraParams) will make @code(foo) equal to
 the constant @link(EmptyXtra)}
function BuildXtraParams(extras: String=''; perPage: Integer = 0;
                         Page: Integer = 0): TXtraParams;

{@abstract(Builds a TPhotoSearchParams record.)
  Use this function to build a @link(TPhotoSearchParams) record.}
function BuildSearchParams(tags: String=''; tagMode: String=''; text: String='';
                           Uploaded: TDateRange = nil; Taken: TDateRange = nil;
                           license: ShortInt = -1;
                           privacy: TPrivacyFilter = pfNone): TPhotoSearchParams;

{@abstract(Simple XML reponse parser.)
 Converts the XML response to a kind of INI format. Note that this function
 returns an object that you must free once you're done with it. For an
 example of how this can be done see the implementation of
 @link(TRESTApi.ParseResponse).}
function XMLToStrings(const xml: String): TStrings;

const
  {@abstract(Version of the library)
   Contrary to what is considered "standard", version "100" (1.0.0) is both
   "development" and "stable" (and beta, gamma, etc. ;-)) Should you need it,
   compare the lastmod date to know if you have the latest. }
  Version = $100;

  {@abstract(Services' names referred to by @link(TFlickr.Service))
   Do note that due to the change of the type of @link(TFlickr.Service), you
   must now index this array with a @link(TServiceType) variable.}
  ServiceNames: Array [stFlickr..stOther] of String = ('flickr', '23', 'other');

  {@abstract(Base URI of the known services API endpoints.)
   These URIs are used to set the default @link(TWebService.BaseURI) after
   changing @link(TWebService.ServiceType).}
  KnownBaseURI: array [stFlickr..stOther] of string =
  ('http://api.flickr.com/', 'http://www.23hq.com/', '');

  {! Common parameters }{}
  EmptyID = '';    {<Semantic 'no id'}
  AnyId = EmptyID; {<Semantic 'anyone' id}
  SelfId = EmptyID;{<Semantic 'owner' id}

  {@abstract(Default @link(TPageSet).)
   Means "let Flickr decide how many items to return."
   For 'normal' photolists it'll be 100, but other lists return by default
   as many as 500 (p.e. flickr.photosets.getPhotos) }
  DefPageSet: TPageSet = (perpage: 0; page: 0);

  {@abstract(Default @link(TXtraParams))
   No extra options passed; default pagination.}
  EmptyXtra: TXtraParams = (extras: ''; perpage: 0; page: 0);

  {@abstract(All known 'extras' values.)
   Up to date as of 2008-04-09}
  AllXtras = 'license,date_upload,date_taken,owner_name,'+
             'icon_server,original_format,last_update,geo,'+
             'tags,machine_tags,o_dims,views,media';

  { @link(TXtraParams) set to retrieve the richest response available}
  FullXtras: TXtraParams = (extras: AllXtras; perpage: 500; page: 0);

  {@link(TTagSearchMode) lookup strings}
  TagModes: array[tmAny..tmOther] of String = ('any', 'all', '');

  {@link(TMediaType) lookup strings}
  MediaTypes: array[mediaDefault..mediaAll] of String = ('', 'photos',
                                                         'videos', 'all');

  { @link(TSortOrder) lookup strings}
  SortOrderStr: array[soPostedAsc..soRelevance] of String =
    ('date-posted-asc', 'date-posted-desc',
     'date-taken-asc', 'date-taken-desc',
     'interestingness-asc', 'interestingness-desc',
     'relevance');

  { @link(TDateGranularity) valid values }{}
  dgExact = 0; {!<@link(TDateGranularity): Exact date}
  dgMonth = 4; {!<@link(TDateGranularity): Known month/year, e.g. "August, 1997"}
  dgYear  = 6; {!<@link(TDateGranularity): Known year; e.g. "sometime in 2004"}

resourcestring

  sFBadResponse = 'Unrecognised REST response status'#13#10'%s';

implementation (***********************************************************)

uses rfNetHlp, IdMultipartFormData;

{ ***** Global helper functions *****}

function BuildSearchParams(tags: String=''; tagMode: String=''; text: String='';
                           Uploaded: TDateRange = nil; Taken: TDateRange = nil;
                           license: ShortInt = -1;
                           privacy: TPrivacyFilter = pfNone): TPhotoSearchParams;
begin
    Result.tags := tags;
    Result.tagMode := tagMode;
    Result.text := text;
    Result.Uploaded := Uploaded;
    Result.Taken := Taken;
    Result.license := license;
    Result.privacy := privacy;
end;

{ TXtraParams Encoder }
function BuildXtraParams(extras: String=''; perPage: Integer = 0;
                         Page: Integer = 0): TXtraParams;
begin
  Result.extras := extras;
  Result.perpage := perPage;
  Result.page := Page;
end;

{ Silly parser for testing. Beware, though, that TAuth depends on it. }
function XMLToStrings(const xml: String): TStrings;
var Parser: TXmlParser;
    i: Integer;
begin
  Result := TStringList.Create;
  try
    Parser := TXmlParser.Create;
    with Parser do try
      Normalize := True;
      LoadFromBuffer(PChar(xml));
      StartScan;
      while scan do
        case CurPartType of
        ptStartTag,
        ptEmptyTag: begin
                      Result.Add('');
                      Result.Add(Format('[%s]',[CurName]));
                      for i := 0 to CurAttr.Count - 1 do
                        {Bad enough ad-hockery to cope with TRESTApi default
                         parser testing for 'rsp.stat', 'err.code', etc.}
                        if (CurName = 'rsp') or (CurName = 'err') then
                          Result.Add(Format('%s.%s=%s', [CurName,
                                                          CurAttr.Name(i),
                                                          CurAttr.Value(i)]))
                        else
                          Result.Add(Format('%s=%s', [CurAttr.Name(i),
                                                      CurAttr.Value(i)]));
                    end;
        ptContent:  Result.Add(CurName+'='+CurContent);
        end;
    finally
      Free;
    end;
  except
    Result.Free;
    raise
  end;
end;

{ Builds a Flickr signature string }
function GetSignature(Request: TWebParams; Secret: String): String;
var sigStr: String;
begin
  sigStr := '';
  with TStringList.Create do try
    Duplicates := dupAccept;
    Text := Request.Text;
    Sort;
    sigStr := Secret;
    sigStr := sigStr + StringReplace(Text, #13#10, '', [rfReplaceAll]);
    sigStr := StringReplace(sigStr, '=', '', [rfReplaceAll]);
    sigStr := MD5Print(MD5String(sigStr));
  finally
   Free;
  end;
  Result := sigStr;
end;

{ Adds common 'extra' parameters to a request }
procedure AddXtraPars(params: TWebParams; xtra: TXtraParams);
begin
  with params, xtra do begin
    Optional['extras'] := extras;
    if perpage > 0 then Optional['per_page'] := IntToStr(perpage);
    if page > 1    then Optional['page']     := IntToStr(page);
  end;
end;

{ Checks if a DateRange has useful values }
(* LCM 20060628 - Not used any more
function EmptyRange(DateRange: TDateRange): Boolean;
procedure AddDateMinMax(Params: TWebParams; Dates: TDateRange;
                        DateKind: TDateKind);
*)

{ Converts and adds a Date range to a request in MySQL or unix formats }
procedure AddDateMinMax(Params: TWebParams; Dates: TDateRange;
                        DateKind: TDateKind);
var kindStr, minStr, maxStr: String;
begin
  if Assigned(Dates) then begin
    minStr := '';
    maxStr := '';
    case DateKind of
    dkTaken:  begin
                kindStr := 'taken';
                with Dates do begin
                  if MinDate <> 0.0 then minStr := DateTimeToMySQL(MinDate);
                  if MaxDate <> 0.0 then maxStr := DateTimeToMySQL(MaxDate);
                end;
              end;
    dkPosted: begin
                kindStr := 'upload';
                with Dates do begin
                  if MinDate <> 0.0 then minStr := IntToStr(
                                                     DateTimeToUnix(MinDate));
                  if MaxDate <> 0.0 then maxStr := IntToStr(
                                                     DateTimeToUnix(MaxDate));
                end;
              end;
    end;
    Params.Optional[Format('min_%s_date',[kindStr])] := minStr;
    Params.Optional[Format('max_%s_date',[kindStr])] := maxStr;
  end;
end;

{ Converts a Boolean to a String; if it's a required param, false := '0'}
function BoolStr(b: Boolean; Required: Boolean = False): String;
begin
  if b then Result := '1'
  else if Required then Result := '0'
                   else Result := '';
end;

{ Converts and array of String in a comma delimited string}
function CommaString(StrArr: array of String): String;
var i, first, last: Integer;
begin
  first := Low(StrArr);
  last  := High(StrArr);
  Result := '';
  for i := first to last do
    if i < last then Result := Result + StrArr[i] + ','
                else Result := Result + StrArr[i];
end;

{LCM 2008-04-08}
{@abstract(Converts Lat/Lon coordinates to a string w/ the specified precision)
 Needed to correct localized decimal points, like the Spanish "," }
function CoordToStr(LatLon: Double; Precision: Integer = 6): String;
var s: String;
begin
  s := Format('%.*f',[Precision, LatLon]);
  if DecimalSeparator <> '.' then
    Result := StringReplace(s, DecimalSeparator, '.', [rfReplaceAll])
  else
    Result := s;
end;

function CheckBBox(bbox: TBoundBox): boolean;
begin
  result := ((abs(bbox.MinLatitude) <= 90.0) and
             (abs(bbox.MaxLatitude) <= 90.0)) and
            ((abs(bbox.MinLongitude) <= 180.0) and
             (abs(bbox.MaxLongitude) <= 180.0));
end;

{**************************************}
{*    TRESTApi = class                *}
{**************************************}

procedure TRESTApi.Lock;
begin
  FCriticalSection.Enter;
  Inc(FLockCount)
end;

procedure TRESTApi.UnLock;
begin
  Dec(FLockCount);
  FCriticalSection.Leave;
end;

{ SimpleCall executes un-authenticated calls to flickr unless SignAll
  is set to true, in which case the call is passed over to SignedCall.
  BUG?: Depends of a valid TFlickr instance owning. }
function TRESTApi.SimpleCall(const method: String): String;
var url: String;
begin
  if SignAll then Result := SignedCall(method)
  else begin
    with FRequest do begin
      if Count > 0 then begin
        InsertValue(0, 'method', Method);
        InsertValue(1, 'api_key', Owner.ApiKey);
        { Same as:
        Insert(0, 'method=' + Method);
        Insert(1, 'api_key=' + Owner.ApiKey);}
      end else begin
        Required['method'] := Method;
        Required['api_key'] := Owner.ApiKey;
      end;
    end;
    //url := FLICKR_BASE_REST + FRequest.URLEncoded;
    url := Owner.FService.GetEndpoint(epBaseREST) +
           '?' + FRequest.URLEncoded; {LCM: 2007-01-07}
    FResponse := WebMethodCall(url);
    Result := FResponse;
    if FThrottle > 0 then begin
      if FRandomWait then
        Sleep(Random(FThrottle) * 100) {*DEPENDS: windows.pas}
      else
        Sleep(FThrottle * 100); {*DEPENDS: windows.pas}
    end;
  end;
end;

{ SignedCall executes signed authenticated calls to flickr
  BUG?: Depends of a valid TFlickr instance owning. }
function TRESTApi.SignedCall(const method: String):String;
var url: String;
begin
  with FRequest do begin
    if Count > 0 then begin
      InsertValue(0, 'method', Method);
      InsertValue(1, 'api_key', Owner.ApiKey);
    end else begin
      Required['method'] := Method;
      Required['api_key'] := Owner.ApiKey;
    end;
  end;
  {---- This is what differs from SimpleCall ----}
  if not Self.InheritsFrom(TAuth) then // TAuth is just FOR getting the Token
    FRequest.Required['auth_token'] := Owner.Token;
  {Next "if" added by LCM in 2006-12-05 to adapt for 23;
   since 23 doesn't use signatures, sending it opens a security hole}
  //if Owner.Service = stFlickr then {LCM 2006-12-05}
  if Owner.Service.ServiceType = stFlickr then {LCM: 2007-01-07}
    FRequest.Required['api_sig'] := GetSignature(FRequest, Owner.Secret);
  {----------------------------------------------}
  //url := FLICKR_BASE_REST + FRequest.URLEncoded;
  url := Owner.FService.GetEndpoint(epBaseREST) +
         '?' + FRequest.URLEncoded; {LCM: 2007-01-07}
  FResponse := WebMethodCall(url);
  Result := FResponse;
  if FThrottle > 0 then begin
    if FRandomWait then
      Sleep(Random(FThrottle) * 100) {*DEPENDS: windows.pas}
    else
      Sleep(FThrottle * 100); {*DEPENDS: windows.pas}
  end;
end;

procedure TRESTApi.ParseResponse(resp: String);
var e: EFlickrError;
    Parsed: TStrings; {Since I won't create an instance, it's OK. }
begin
  Parsed := XMLToStrings(resp);
  with Parsed do try
    if Values['rsp.stat'] = 'fail' then begin
      e := FErrorClass.CreateFmt('Flickr call error in %s:'#10'%s - %s',
                                  [Self.ClassName,
                                   Values['err.code'],
                                   Values['err.msg']]);
      e.Code := StrToInt(Values['err.code']);
      raise(e);
    end else if Values['rsp.stat'] <> 'ok' then {weird response or resp' status}
      raise(EFlickrBadResponse.CreateFmt(sFBadResponse,[resp]));
  finally
    Free
  end;
end;

procedure TRESTApi.CheckError(XMLResp: String);
begin
  ParseResponse(XMLResp);
end;

procedure TRESTApi.CheckAndSave(XMLResp: String; Stream: TStream);
var XMLString: TStringStream;
begin
  CheckError(XMLResp);
  XMLString := TStringStream.Create(XMLResp);
  try
    XMLString.Seek(0, soFromBeginning);
    Stream.CopyFrom(XMLString, XMLString.Size);
  finally
    XMLString.Free
  end;
end;

procedure TRESTApi.CheckAndSave(XMLResp, FileName: String);
var XMLFile: TFileStream;
begin
  XMLFile := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
  try
    CheckAndSave(XMLResp, XMLFile);
  finally
    XMLFile.Free
  end;
end;

function TRESTApi.FlickrCall(const method: String;
                             Signed: Boolean = False):String;
begin
  if Signed then Result := SimpleCall(method)
            else Result := SignedCall(method);
end;

constructor TRESTApi.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited Create;
  FRequest := TWebParams.Create;
  FOwner := AOwner;
  FSignAll := (Sign = sgnAlways);
  FThrottle := 10;
  FRandomWait := True;
  FErrorClass := EFlickrError;
  FResponse := '';
  FLockCount := 0;
  FCriticalSection := TCriticalSection.Create;
end;

destructor TRESTApi.Destroy;
begin
  FCriticalSection.Free;
  FreeAndNil(FRequest);
  inherited;
end;


{**************************************}
{*    TActivity = class(TRESTApi)     *}
{**************************************}

function TActivity.userComments(perPage: Integer = 0;
                                page : Integer = 0): String;
begin
  with FRequest do begin
    Initialize;
    if perPage > 0 then
      Optional['per_page'] := IntToStr(perPage);
    if page > 1 then
      Optional['page'] := IntToStr(page);
  end;
  Result := SignedCall('flickr.activity.userComments');
end;

function TActivity.userPhotos(timeframe: String = '';
                              perPage: Integer = 0;
                              page : Integer = 0): String;
begin
  with FRequest do begin
    Initialize;
    Optional['timeframe'] := timeframe;
    if perPage > 0 then
      Optional['per_page'] := IntToStr(perPage);
    if page > 1 then
      Optional['page'] := IntToStr(Page);
  end;
  Result := SignedCall('flickr.activity.userPhotos');
end;

constructor TActivity.Create(AOwner: TFlickr; Sign: TSignOption);
begin
  inherited;
end;


{**************************************}
{*    TAuth = class(TRESTApi)         *}
{**************************************}

{ BUG?: Depends of a valid TFlickr instance owning. }
procedure TAuth.ParseResponse(resp: String);
var Parsed: TStrings;
begin
  inherited;
  Parsed := XMLToStrings(resp);
  with Parsed do try
    Owner.Token := Values['token'];
    Owner.Level := Values['perms'];
    with Owner.User do begin
      (**
      NSID := Values['user.nsid'];
      username := Values['user.username'];
      fullname := Values['user.fullname'];
      (**)
      NSID := Values['nsid'];
      username := Values['username'];
      fullname := Values['fullname'];
    end;
  finally
    Free;
  end;
end;

function TAuth.ParseFrobResp(resp: String): String;
begin
  inherited ParseResponse(resp);
  with XMLToStrings(resp) do try
    FFrob := Values['frob'];
    Result := FFrob;
  finally
    Free;
  end;
end;

function TAuth.checkToken(Token: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['auth_token'] := Token;
  end;
  Result := SignedCall('flickr.auth.checkToken');
  ParseResponse(Result);
end;

function TAuth.getFrob: String;
begin
  FRequest.Initialize;
  Result := ParseFrobResp(SignedCall('flickr.auth.getFrob'));
end;

function TAuth.getFullToken(miniToken: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['mini_token'] := miniToken;
  end;
  Result := SignedCall('flickr.auth.getFullToken');
  ParseResponse(Result);
end;

function TAuth.getToken(frob: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['frob'] := frob;
  end;
  Result := SignedCall('flickr.auth.getToken');
  ParseResponse(Result);
end;

{ BUG?: Depends of a valid TFlickr instance owning. }
function TAuth.GetLoginLink(perms: String; frob: String): String;
var params: TWebParams;
begin
  params := TWebParams.Create;
  with params do try
    Required['api_key'] := Owner.ApiKey;
    Required['frob'] := frob;
    if Owner.Service.ServiceType = stFlickr then begin
      Required['perms'] := perms;
      Required['api_sig'] := GetSignature(params, Owner.Secret);
    end;
    //Result := FLICKR_AUTH_URL + URLEncoded;
    Result := Owner.Service.GetEndpoint(epAuth) + '?' + URLEncoded;
  finally
    params.Free;
  end;
end;

function TAuth.GetLoginLinkW(perms: String; frob: String): WideString;
begin
  Result := GetLoginLink(perms, frob); { automatic conversion (Delphi) }
end;

constructor TAuth.Create(Owner: TFlickr);
begin
  inherited Create(Owner);
  FSignAll := True;
  FErrorClass := EFlickrAuthError;
end;


{**************************************}
{*    TBlogs = class(TRESTApi)        *}
{**************************************}

function TBlogs.getList: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.blogs.getList');
end;

function TBlogs.postPhoto(Photo: TBlogPhoto): String;
begin
  FRequest.Initialize;
  with Photo, FRequest do begin
    Required['blog_id'] := blogId;
    Required['photo_id'] := photoId;
    Required['title'] := title;
    Required['description'] := description;
    Optional['blog_password'] := blogPassword;
  end;
  Result := SignedCall('flickr.blogs.postPhoto');
end;

function TBlogs.postPhoto(blogId, photoId, title, description,
                          blogPassword: String): String;
begin
  FRequest.Initialize;
  with FRequest do begin
    Required['blog_id'] := blogId;
    Required['photo_id'] := photoId;
    Required['title'] := title;
    Required['description'] := description;
    Optional['blog_password'] := blogPassword;
  end;
  Result := SignedCall('flickr.blogs.postPhoto');
end;

constructor TBlogs.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TCommons = class(TRESTApi)      *}
{**************************************}

function TCommons.getInstitutions: String;
begin
  FRequest.Initialize;
  Result := SimpleCall('flickr.commons.getInstitutions');
end;

constructor TCommons.Create(AOwner: TFlickr; Sign: TSignOption);
begin
  inherited;
end;


{**************************************}
{*    TContacts = class(TRESTApi)     *}
{**************************************}

function TContacts.getList(filter: String = ''; Page: Integer = 0;
                           perPage: Integer = 0): String;
begin
  with FRequest do begin
    Initialize;
    Optional['filter'] := filter;
    if Page > 0 then
      Optional['page'] := IntToStr(Page);
    if perPage > 0 then
      Optional['per_page'] := IntToStr(perPage);
  end;
  Result := SignedCall('flickr.contacts.getList');
end;

function TContacts.getPublicList(UserId: String; Page: Integer = 0;
                                 perPage: Integer = 0): String;
begin
  with FRequest do begin
    Initialize;
    if UserId = SelfId then UserId := Owner.User.NSID;
    Required['user_id'] := UserId;
    if Page > 0 then
      Optional['page'] := IntToStr(Page);
    if perPage > 0 then
    Optional['per_page'] := IntToStr(perPage);
  end;
  Result := SimpleCall('flickr.contacts.getPublicList');
end;

constructor TContacts.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TFavorites = class(TRESTApi)    *}
{**************************************}

function TFavorites.getList(userId: String; extra: TXtraParams): String;
begin
  FRequest.Initialize;
  FRequest.Optional['user_id'] := userId;
  AddXtraPars(FRequest, extra);
  Result := SignedCall('flickr.favorites.getList')
end;

function TFavorites.getList(userId: String; extras: String='';
                            perPage: Integer = 0; Page: Integer = 0): String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
    Optional['extras'] := extras;
    if perpage > 0 then
      Optional['per_page'] := IntToStr(perpage);
    if page > 1 then
      Optional['page']     := IntToStr(page);
  end;
  Result := SignedCall('flickr.favorites.getList')
end;

function TFavorites.getPublicList(userId: String; extra: TXtraParams): String;
begin
  if userId = SelfId then
    userId := Owner.User.NSID;
  FRequest.Initialize;
  FRequest.Required['user_id'] := userId; // user_id is REQUIRED for this call
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.favorites.getPublicList');
end;

function TFavorites.Add(PhotoId: String): String;
begin
  FRequest.Initialize;
  FRequest.Required['photo_id'] := PhotoId;
  Result := SignedCall('flickr.favorites.getPublicList');
end;

function TFavorites.Remove(PhotoId: String): String;
begin
  FRequest.Initialize;
  FRequest.Required['photo_id'] := PhotoId;
  Result := SignedCall('flickr.favorites.Remove');
end;

constructor TFavorites.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TGroups = class(TRESTApi)       *}
{**************************************}

function TGroups.GetPools: TPools;
var Sign: TSignOption;
begin
  if not Assigned(FPools) then begin
    if FSignAll then Sign := sgnAlways
                else Sign := sgnRequired;
    FPools := TPools.Create(FOwner, Sign);
  end;
  Result := FPools;
end;

function TGroups.browse(catId: Integer = 0): String;
begin
  FRequest.Initialize;
  FRequest.Required['cat_id'] := IntToStr(catId);
  Result := SignedCall('flickr.groups.browse');
end;

{Parameter lang added 2008-04-04}
function TGroups.getInfo(groupId: String; lang: String=''): String;
begin
  FRequest.Initialize;
  FRequest.Required['group_id'] := groupId;
  FRequest.Optional['lang'] := lang;
  Result := SimpleCall('flickr.groups.getInfo');
end;

function TGroups.search(text: String; perpage: Integer=0; page: Integer=0;
                        Plus18: Boolean = True): String;
begin
  with FRequest do begin
    Initialize;
    Required['text'] := text;
    if perpage > 0 then
      Optional['per_page'] := IntToStr(perpage);
    if page > 0 then
      Optional['page'] := IntToStr(page);
  end;
  if Plus18 then
    Result := SignedCall('flickr.groups.search')
  else
    Result := SimpleCall('flickr.groups.search');
end;

constructor TGroups.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
  FPools := nil;
end;

destructor TGroups.Destroy;
begin
  Pools.Free;
  inherited Destroy;
end;


{**************************************}
{*    TPools = class(TRESTApi)        *}
{**************************************}

function TPools.getGroups(Page: Integer = 0; perPage: Integer = 0): String;
begin
  with FRequest do begin
    Initialize;
    if Page > 1    then Optional['page']     := IntToStr(Page);
    if perPage > 0 then Optional['per_page'] := IntToStr(perPage);
  end;
  Result := SignedCall('flickr.groups.pools.getGroups');
end;

function TPools.getPhotos(groupId: String; Tags: String; userId: String;
                          extra: TXtraParams): String;
begin
  with FRequest do begin
    Initialize;
    Required['group_id'] := groupId;
    Optional['tags'] := Tags;
    Optional['user_id'] := userId;
  end;
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.groups.pools.getPhotos');
end;

function TPools.getContext(photoId, groupId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['group_id'] := groupId;
  end;
  Result := SimpleCall('flickr.groups.pools.getContext');
end;

function TPools.Add(photoId, groupId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['group_id'] := groupId;
  end;
  Result := SignedCall('flickr.groups.pools.add');
end;

function TPools.Remove(photoId, groupId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['group_id'] := groupId;
  end;
  Result := SignedCall('flickr.groups.pools.remove');
end;

constructor TPools.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{* TInterestingness = class(TRESTApi) *}
{**************************************}

function TInterestingness.getList(ADate: TDateTime;
  extra: TXtraParams): String;
begin
  FRequest.Initialize;
  if ADate >= 1.0 then
    FRequest.Optional['date'] := FormatDateTime('yyyy-mm-dd', ADate);
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.interestingness.getList');
end;

constructor TInterestingness.Create(AOwner: TFlickr;
                                    Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TPeople = class(TRESTApi)       *}
{**************************************}

function TPeople.findByEmail(email: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['find_email'] := email;
  end;
  Result := SimpleCall('flickr.people.findByEmail');
end;

function TPeople.findByUsername(username: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['username'] := username;
  end;
  Result := SimpleCall('flickr.people.findByUsername');
end;

function TPeople.getInfo(userId: String): String;
begin
  with FRequest do begin
    Initialize;
    if userId = SelfID then userId := Owner.User.NSID;
    Required['user_id'] := userId;
  end;
  Result := SimpleCall('flickr.people.getInfo');
end;

{Probably can be signed }
function TPeople.getPublicGroups(userId: String): String;
begin
  with FRequest do begin
    Initialize;
    if userId = SelfID then userId := Owner.User.NSID;
    Required['user_id'] := userId;
  end;
  Result := SimpleCall('flickr.people.getPublicGroups');
end;

{Probably can be signed }
function TPeople.getPublicPhotos(userId: String; extra: TXtraParams): String;
begin
  with FRequest do begin
    Initialize;
    if userId = SelfID then userId := Owner.User.NSID;
    Required['user_id'] := userId;
  end;
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.people.getPublicPhotos');
end;

function TPeople.getUploadStatus: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.people.getUploadStatus');
end;


constructor TPeople.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TPhotos = class(TRESTApi)       *}
{**************************************}

{ This call CAN be authenticated (signed), in which case it'll return
  not only public but also private and semi-private photos. To do so,
  set Photos.SignAll = True before calling Photos.search }
function TPhotos.search(userId: String; searchParams: TPhotoSearchParams;
                extra: TXtraParams; sort: TSortOrder = soDefault): String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
    with searchParams do begin
      Optional['tags'] := tags;
      Optional['tag_mode'] := tagMode;
      Optional['text'] := text;
      AddDateMinMax(FRequest, Uploaded, dkPosted);
      AddDateMinMax(FRequest, Taken, dkTaken);
      if license >= 0 then
        Optional['license'] := IntToStr(license);
      if privacy <> pfNone then  {@LCM 2006-07-04}
        Optional['privacy_filter'] := IntToStr(Ord(privacy));
    end;
    {if not (sort in [soNone,soPostedDesc]) then{ In case the default changes }
    if sort <> soDefault then
      Optional['sort'] := SortOrderStr[sort];
  end;
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.photos.search');
end;

{New flanged, full implementation of flickr.photos.search}
function TPhotos.search(userId, groupId: String; SearchTerms: TSearchTerms;
  Uploaded, Taken: TDateRange; GeoTerms: TGeoTerms;
  ContentTerms: TContentFilter; extra: TXtraParams;
  sort: TSortOrder): String;
var box: String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
    Optional['group_id'] := groupId;
    // Tags/text terms
    with SearchTerms do begin
      if tags <> '' then begin
        Optional['tags'] := tags;
        Optional['tag_mode'] := Tagmodes[tagMode];
      end;
      if machineTags <> '' then begin
        Optional['machine_tags'] := machineTags;
        Optional['machine_tag_mode'] := Tagmodes[machineTagMode];
      end;
      Optional['text'] := text;
    end;
    // Date terms
    AddDateMinMax(FRequest, Uploaded, dkPosted);
    AddDateMinMax(FRequest, Taken, dkTaken);
    // Geo-location terms
    {LCM: 2008-06-29 - Mod bc the change of type of validFields and
                       additions in TGeoTerms}
    with GeoTerms do begin
      if gfHasGeo in validFields then begin
        Optional['has_geo'] := BoolStr(hasGeo, True);
      end;
      if (gfBbox in validFields) and CheckBBox(BBox) then begin
          box := Format('%s,%s,%s,%s',
                        [CoordToStr(BBox.MinLongitude),
                         CoordToStr(BBox.MinLatitude),
                         CoordToStr(BBox.MaxLongitude),
                         CoordToStr(BBox.MaxLatitude)]);
          Optional['bbox'] := box;
      end;
      {NOTE: No check is made on the coordinates??}
      if gfRadial in GeoTerms.validFields then begin
        Optional['lat'] := CoordToStr(RadialQuery.lat);
        Optional['lon'] := CoordToStr(RadialQuery.lon);
        Optional['radius'] := IntToStr(RadialQuery.radius);
        Optional['radius_units'] := RadialQuery.radiusUnits
      end;
      if gfPlaces in GeoTerms.validFields then begin
          Optional['woe_id'] := woeId;
          Optional['place_id'] := placeId;
      end;
      if (accuracy > 0) then
        Optional['accuracy'] := IntToStr(accuracy);
   end; {with GeoTerms do ... }
    with ContentTerms do begin
      if contentType <> ctNone then
        Optional['content_type'] := chr($30 + Ord(contentType));
      Optional['media'] := MediaTypes[media];
      if license >= 0 then
        Optional['license'] := IntToStr(license);
      if privacy <> pfNone then
        Optional['privacy_filter'] := IntToStr(Ord(privacy));
      if safety <> slIgnore then
        Optional['safe_search'] := chr($30 + Ord(safety));
    end;
    if sort <> soDefault then
      Optional['sort'] := SortOrderStr[sort];
  end;
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.photos.search');
end;

{ When userId <> '' this function calls getContactsPublicPhotos }
function TPhotos.getContactsPhotos(userId: String= '';
                           count: Integer=0;
                           justFriends: Boolean = False;
                           singlePhoto: Boolean = False;
                           includeSelf: Boolean = False;
                           extras: String = ''): String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
    Optional['just_friends'] := BoolStr(justFriends);
    Optional['single_photo'] := BoolStr(singlePhoto);
    Optional['include_self'] := BoolStr(includeSelf);
    Optional['extras'] := extras;
  end;
  if (not singlePhoto) and (count > 0) then
    {Could use Required[..] but this way it's more clear that it's optional}
    FRequest.Optional['count'] := IntToStr(count);
  if userId = '' then
    Result := SignedCall('flickr.photos.getContactsPhotos')
  else
    Result := SignedCall('flickr.photos.getContactsPublicPhotos');
end;

function TPhotos.getCounts(Uploaded, Taken: array of TDateTime): String;
    function CommaDates(Dates: array of TDateTime; Kind: TDateKind): String;
    var i: Integer; sl: TStringList;
    begin
      sl := TStringList.Create;
      with sl do try
        Sorted := True;
        for i := Low(Dates) to High(Dates) do
          case Kind of
          //dkPosted: Add(Format('%.10d',[DateTimeToUnix(Dates[i])]));
          dkPosted: Add(IntToStr(DateTimeToUnix(Dates[i])));
          dkTaken : Add(StringReplace(DateTimeToMySQL(Dates[i]),
                                      ' ', '_', [rfReplaceAll]));
          end;
        Result := StringReplace(CommaText, '_', ' ', [rfReplaceAll]);
      finally
        Free
      end;
    end;
begin
  with FRequest do begin
    Initialize;
    Optional['dates'] := CommaDates(Uploaded, dkPosted);
    Optional['taken_dates'] := CommaDates(Taken, dkTaken);
  end;
  Result := SignedCall('flickr.photos.getCounts');
end;

function TPhotos.getNotInSet(sort: TSortOrder; extra: TXtraParams): String;
begin
  FRequest.Initialize;
  if sort <> soDefault then
    FRequest.Optional['sort'] := SortOrderStr[sort];
  AddXtraPars(FRequest, extra);
  Result := SignedCall('flickr.photos.getNotInSet');
end;

function TPhotos.getRecent(extra: TXtraParams): String;
begin
  FRequest.Initialize;
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.photos.getRecent');
end;

function TPhotos.getUntagged(extra: TXtraParams): String;
begin
  FRequest.Initialize;
  AddXtraPars(FRequest, extra);
  Result := SignedCall('flickr.photos.getUntagged');
end;

function TPhotos.recentlyUpdated(minDate: TDateTime; extra: TXtraParams): String;
begin
  with FRequest do begin
    Initialize;
    FRequest.Required['min_date'] := IntToStr(DateTimeToUnix(minDate));
  end;
  AddXtraPars(FRequest, extra);
  Result := SignedCall('flickr.photos.recentlyUpdated');
end;

function TPhotos.getWithGeoData(Uploaded, Taken: TDateRange;
                                Privacy: TPrivacyFilter;
                                extra: TXtraParams;
                                Sort: TSortOrder = soDefault): String;
begin
  with FRequest do begin
    Initialize;
    AddDateMinMax(FRequest, Uploaded, dkPosted);
    AddDateMinMax(FRequest, Taken, dkTaken);
    if Privacy <> pfNone then
        Optional['privacy_filter'] := IntToStr(Ord(privacy));
    if sort <> soDefault then
      Optional['sort'] := SortOrderStr[sort];
  end;
  AddXtraPars(FRequest, extra);
  Result := SignedCall('flickr.photos.getWithGeoData');
end;

function TPhotos.getWithoutGeoData(Uploaded, Taken: TDateRange;
                                Privacy: TPrivacyFilter;
                                extra: TXtraParams;
                                Sort: TSortOrder = soDefault): String;
begin
  with FRequest do begin
    Initialize;
    AddDateMinMax(FRequest, Uploaded, dkPosted);
    AddDateMinMax(FRequest, Taken, dkTaken);
    if Privacy <> pfNone then
        Optional['privacy_filter'] := IntToStr(Ord(privacy));
    if sort <> soDefault then
      Optional['sort'] := SortOrderStr[sort];
  end;
  AddXtraPars(FRequest, extra);
  Result := SignedCall('flickr.photos.getWithoutGeoData');
end;

function TPhotos.getContext(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SimpleCall('flickr.photos.getContext');
end;

function TPhotos.getAllContexts(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SimpleCall('flickr.photos.getAllContexts');
end;

function TPhotos.getExif(photoId: String; secret: string = ''): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Optional['secret'] := secret;
  end;
  Result := SimpleCall('flickr.photos.getExif');
end;

function TPhotos.getInfo(photoId: String; secret: string = ''): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Optional['secret'] := secret;
  end;
  Result := SimpleCall('flickr.photos.getInfo');
end;

function TPhotos.getPerms(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SignedCall('flickr.photos.getPerms');
end;

function TPhotos.getSizes(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SimpleCall('flickr.photos.getSizes');
end;

{LCM: 2008/03/31}
function TPhotos.getFavorites(photoId: String; perPage: Integer = 0;
                              page : Integer = 0): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    if perPage > 0 then
      Optional['per_page'] := IntToStr(perPage);
    if page > 1 then
      Optional['page'] := IntToStr(page);
  end;
  Result := SimpleCall('flickr.photos.getFavorites');
end;

function TPhotos.setDates(photoId: String;
                  Posted: TDateTime = 0; Taken: TDateTime = 0;
                  takenAprox: TDateGranularity = 0{dgExact}): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    if Posted >= UnixDateDelta then
      Optional['date_posted'] := IntToStr(DateTimeToUnix(Posted));
    if Taken > 0.0009 then begin
      Optional['date_taken'] := DateTimeToMySQL(Taken);
      Optional['date_taken_granularity'] := IntToStr(takenAprox);{}
    end;
  end;
  Result := SignedCall('flickr.photos.setDates');
end;

function TPhotos.setMeta(photoId, Title, Description: String) : String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['title'] := Title;
    Required['description'] := Description;
  end;
  Result := SignedCall('flickr.photos.setMeta');
end;

function TPhotos.setPerms(photoId: String; Visibility: TVisibility;
                  PermitComments, PermitMeta: TPermission) : String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['is_public'] := BoolStr((toPublic in Visibility), True);
    Required['is_friend'] := BoolStr((toFriends in Visibility), True);
    Required['is_family'] := BoolStr((toFamily in Visibility), True);
    Required['perm_comment'] := IntToStr(Ord(PermitComments));
    Required['perm_meta'] := IntToStr(Ord(PermitMeta));
  end;
  Result := SignedCall('flickr.photos.setPerms');
end;

function TPhotos.setContentType(photoId: String;
                                ContentType: TContentType): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['content_type'] := chr($30 + ord(ContentType));
  end;
  Result := SignedCall('flickr.photos.setContentType');
end;

function TPhotos.setSafetyLevel(photoId: String; Level: TSafetyLevel;
                                Hide: Boolean): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    if Level <> slIgnore then
      Optional['safety_level'] := chr($30 + Ord(Level));
    Optional['hidden'] := chr($30 + Ord(Hide))

  end;
  Result := SignedCall('flickr.photos.setSafetyLevel');
end;

function TPhotos.setSafetyLevel(photoId: String; Level: TSafetyLevel): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    if Level <> slIgnore then
      Optional['safety_level'] := chr($30 + Ord(Level));
  end;
  Result := SignedCall('flickr.photos.setSafetyLevel');
end;

function TPhotos.setTags(photoId, tags: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['tags'] := tags;
  end;
  Result := SignedCall('flickr.photos.setTags');
end;

function TPhotos.addTags(photoId, tags: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['tags'] := tags;
  end;
  Result := SignedCall('flickr.photos.addTags');
end;

function TPhotos.removeTag(tagId: String): String; {doesn't need a photoId?}
begin
  with FRequest do begin
    Initialize;
    // Required['photo_id'] := photoId;
    Required['tagId'] := tagId;
  end;
  Result := SignedCall('flickr.photos.removeTag');
end;

function TPhotos.delete(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SignedCall('flickr.photos.delete');
end;

constructor TPhotos.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
  Licenses  := TLicenses.Create(AOwner, Sign);
  Notes     := TNotes.Create(AOwner, Sign);
  Transform := TTransform.Create(AOwner, Sign);
  Comments  := TComments.Create(AOwner, 'photos', 'photo', Sign);
  Uploader  := TUploader.Create(AOwner, Sign);
end;

destructor TPhotos.Destroy;
begin
  Licenses.Free;
  Notes.Free;
  Transform.Free;
  Uploader.Free;
  inherited Destroy;
end;


{**************************************}
{*    TComments = class(TRESTApi)     *}
{**************************************}

function TComments.getList(entityId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required[FBaseIdName + '_id'] := entityId;
  end;
  Result := SignedCall('flickr.' + FBaseGroup + '.comments.getList')
end;

function TComments.addComment(entityId, text: String): String;
begin
  with FRequest do begin
    Initialize;
    Required[FBaseIdName + '_id'] := entityId;
    Required['comment_text'] := text;
  end;
  Result := SignedCall('flickr.' + FBaseGroup + '.comments.addComment')
end;

function TComments.deleteComment(commentId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['comment_id'] := commentId;
  end;
  Result := SignedCall('flickr.' + FBaseGroup + '.comments.deleteComment')
end;

function TComments.editComment(commentId, text: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['comment_id'] := commentId;
    Required['comment_text'] := commentId;
  end;
  Result := SignedCall('flickr.' + FBaseGroup + '.comments.editComment')
end;

constructor TComments.Create(AOwner: TFlickr; ABaseGroup, ABaseIdName: String;
                             Sign: TSignOption = sgnRequired);
begin
  inherited Create(AOwner, Sign);
  FBaseGroup := ABaseGroup;
  FBaseIdName := ABaseIdName;
end;


{**************************************}
{*    TGeoData = class(TRESTApi)      *}
{**************************************}
function TGeoData.getPerms(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SignedCall('flickr.photos.geo.getPerms')
end;

function TGeoData.setPerms(photoId: String; ViewPerm: TViewPerm): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['is_public']  := BoolStr(lpPublic   in ViewPerm, True);
    Required['is_contact'] := BoolStr(lpContacts in ViewPerm, True);
    Required['is_friend']  := BoolStr(lpFriends  in ViewPerm, True);
    Required['is_family']  := BoolStr(lpPublic   in ViewPerm, True);
  end;
  Result := SignedCall('flickr.photos.geo.setPerms')
end;

function TGeoData.getLocation(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SimpleCall('flickr.photos.geo.getLocation')
end;

function TGeoData.setLocation(photoId: String; Latitude, Longitude: Double;
                              Accuracy: TGeoAccuracy): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    {LCM 2008-04-08 Replaced "Format('%.6f',[Lat/Lon]) by CoordToStr}
    Required['lat'] := CoordToStr(Latitude);
    Required['lon'] := CoordToStr(Longitude);
    Optional['accuracy'] := IntToStr(Accuracy);
  end;
  Result := SignedCall('flickr.photos.geo.setLocation')
end;

function TGeoData.removeLocation(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SignedCall('flickr.photos.geo.removeLocation')
end;


constructor TGeoData.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited Create(AOwner, Sign);
end;

{**************************************}
{*    TLicenses = class(TRESTApi)     *}
{**************************************}

function TLicenses.getInfo: String;
begin
  FRequest.Initialize;
  Result := SimpleCall('flickr.photos.licenses.getInfo');
end;

function TLicenses.setLicense(photoId: String; licenseId: ShortInt): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['license_id'] := IntToStr(licenseId);
  end;
  Result := SignedCall('flickr.photos.licenses.setLicense');
end;

constructor TLicenses.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TNotes = class(TRESTApi)        *}
{**************************************}

function TNotes.Add(photoId: String; note: TNoteRecord): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['note_x'] := IntToStr(note.Left);
    Required['note_y'] := IntToStr(note.Top);
    Required['note_w'] := IntToStr(note.Width);
    Required['note_h'] := IntToStr(note.Height);
    Required['note_text'] := note.Text;
  end;
  Result := SignedCall('flickr.photos.notes.add');
end;

function TNotes.Delete(noteId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['note_id'] := noteId;
  end;
  Result := SignedCall('flickr.photos.notes.delete');
end;


function TNotes.Edit(note: TNoteRecord): String;
begin
  with FRequest do begin
    Initialize;
    Required['note_id'] := note.Id;
    Required['note_x'] := IntToStr(note.Left);
    Required['note_y'] := IntToStr(note.Top);
    Required['note_w'] := IntToStr(note.Width);
    Required['note_h'] := IntToStr(note.Height);
    Required['note_text'] := note.Text;
  end;
  Result := SignedCall('flickr.photos.notes.edit');
end;

constructor TNotes.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TTransform = class(TRESTApi)    *}
{**************************************}

function TTransform.Rotate(photoId: String; degrees: Integer): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['degrees'] := IntToStr(degrees);
  end;
  Result := SimpleCall('flickr.photos.transform.rotate');
end;

constructor TTransform.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TUploader = class(TRESTApi)       *}
{**************************************}

{ Prepare a signed request to transfer as form-data }
procedure TUploader.GetUploadRequest(Title: String; Description: String;
                                 Tags: String; Visibility: TVisibility;
                                 Safety: TSafetyLevel; Content: TContentType;
                                 hideIt: TSearchStatus; Asynchronous: Boolean);
begin
  with FRequest do begin
    Initialize;
    Required['api_key'] := Owner.ApiKey;
    Required['auth_token'] := Owner.Token;
    Optional['title'] := Title;
    Optional['description'] := Description;
    Optional['tags'] := Tags;
    if Visibility <> [] then begin
      Required['is_public'] := BoolStr((toPublic in Visibility), True);
      Required['is_friend'] := BoolStr((toFriends in Visibility), True);
      Required['is_family'] := BoolStr((toFamily in Visibility), True);
    end;
    if Safety <> slIgnore then
      Optional['safety_level'] := IntToStr(Ord(Safety));
    if Content <> ctNone then
      Optional['content_type'] := IntToStr(Ord(Content));
    if hideIt <> ssIgnore then
      Optional['hidden'] := IntToStr(Ord(hideIt));
    Optional['async'] := BoolStr(Asynchronous, False);
    Required['api_sig'] := GetSignature(FRequest, Owner.Secret);
  end;
end;

procedure TUploader.GetReplaceRequest(photoId: String; Asynchronous: Boolean);
begin
  with FRequest do begin
    Initialize;
    Required['api_key'] := Owner.ApiKey;
    Required['auth_token'] := Owner.Token;
    Required['photo_id'] := photoId;
    Optional['async'] := BoolStr(Asynchronous, False);
    Required['api_sig'] := GetSignature(FRequest, Owner.Secret);
  end;
end;

function TUploader.checkTickets(tickets: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['tickets'] := tickets;
  end;
  Result := SimpleCall('flickr.photos.upload.checkTickets');
end;

function TUploader.checkTickets(tickets: array of String): String;
begin
  checkTickets(CommaString(tickets));
end;

function TUploader.Upload(Stream: TStream; FileName: String;
                        Title: String = '';
                        Description: String = '';
                        Tags: String = '';
                        Visibility: TVisibility = [];
                        Safety: TSafetyLevel = slIgnore;
                        Content: TContentType = ctNone;
                        hideIt: TSearchStatus = ssIgnore;
                        Asynchronous: Boolean = False): String;

var MFData: TIdMultiPartFormDataStream;
    i: Integer;
    Name: String;
begin
  GetUploadRequest(Title, Description, Tags, Visibility, Safety, Content,
                   hideIt, Asynchronous);
  MFData := TIdMultiPartFormDataStream.Create;
  { Convert the request (+signature) to form fields }
  for i := 0 to FRequest.Count - 1 do begin
    Name := FRequest.Parameters.Names[i];
    MFData.AddFormField(Name, FRequest.Parameters.Values[Name]);
  end;
  { Add the file data and do the call. }
  if Stream = nil then
    MFData.AddFile('photo', FileName, '') { MIME Type is added internally }
  else
    MFData.AddObject('photo', '', Stream, FileName); { idem }
  //Result := WebMethodCall(FLICKR_UPLOAD_URL, MFData);
  Result := WebMethodCall(Owner.FService.GetEndpoint(epUpload), MFData);
end;

function TUploader.Replace(Stream: TStream; FileName: String;
                         photoId: String;
                         Asynchronous: Boolean = False): String;
var MFData: TIdMultiPartFormDataStream;
    i: Integer;
    Name: String;
begin
  GetReplaceRequest(photoId, Asynchronous);

  MFData := TIdMultiPartFormDataStream.Create;
  { Convert the request (+signature) to form fields }
  for i := 0 to FRequest.Count - 1 do begin
    Name := FRequest.Parameters.Names[i];
    MFData.AddFormField(Name, FRequest.Parameters.Values[Name]);
  end;
  { Add the file data and do the call }
  if Stream = nil then
    MFData.AddFile('photo', FileName, '') {MIME Type added internally }
  else
    MFData.AddObject('photo', '', Stream, FileName); { idem }
  //Result := WebMethodCall(FLICKR_REPLACE_URL, MFData);
  Result := WebMethodCall(Owner.FService.GetEndpoint(epReplace), MFData);
end;

constructor TUploader.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
  FErrorClass := EFlickrUploadError;
end;


{**************************************}
{*    TPhotosets = class(TRESTApi)    *}
{**************************************}

function TPhotosets.GetComments: TComments;
var Sign: TSignOption;
begin
  if FComments = nil then begin
    if FSignAll then Sign := sgnAlways
                else Sign := sgnRequired;
    FComments := TComments.Create(FOwner, 'photosets', 'photoset', Sign);
  end;
  Result := FComments;
end;

function TPhotosets.getList(userId: String = ''): String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
  end;
  if userId = '' then
    Result := SimpleCall('flickr.photosets.getList')
  else
    Result := SignedCall('flickr.photosets.getList');
end;

function TPhotosets.orderSets(setIds: array of String): String;
begin
  with FRequest do begin
    Initialize;
    Optional['photoset_ids'] := CommaString(setIds);
  end;
  Result := SignedCall('flickr.photosets.orderSets');
end;

function TPhotosets.createSet(title, primaryId: String;
                              description: String = ''): String;
begin
  with FRequest do begin
    Initialize;
    Required['title'] := title;
    Optional['description'] := description;
    Required['primary_photo_id'] := primaryId;
  end;
  Result := SignedCall('flickr.photosets.create');
end;

function TPhotoSets.deleteSet(setId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photoset_id'] := setId;
  end;
  Result := SignedCall('flickr.photosets.delete');
end;

function TPhotosets.getInfo(setId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photoset_id'] := setId;
  end;
  Result := SimpleCall('flickr.photosets.getInfo');
end;

function TPhotosets.editMeta(setId, title: String; description: String = ''): String;
begin
  with FRequest do begin
    Initialize;
    Required['photoset_id'] := setId;
    Required['title'] := title;
    Optional['description'] := description;
  end;
  Result := SignedCall('flickr.photosets.editMeta');
end;

function TPhotosets.getPhotos(setId: String; privacy: TPrivacyFilter;
                              extra: TXtraParams): String;

begin
  FRequest.Initialize;
  FRequest.Required['photoset_id'] := setId;
  if Privacy <> pfNone then
      FRequest.Optional['privacy_filter'] := IntToStr(Ord(privacy));
  AddXtraPars(FRequest, extra);
  Result := SimpleCall('flickr.photosets.getPhotos');
end;

function TPhotosets.editPhotos(setId, primaryId: String;
                               photoIds: array of String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photoset_id'] := setId;
    Required['primary_photo_id'] := primaryId;
    Required['photo_ids'] := CommaString(photoIds);
  end;
  Result := SignedCall('flickr.photosets.editPhotos');
end;

function TPhotosets.addPhoto(setId, photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photoset_id'] := setId;
    Required['photo_id'] := photoId;
  end;
  Result := SignedCall('flickr.photosets.addPhoto');
end;

function TPhotosets.removePhoto(setId, photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photoset_id'] := setId;
    Required['photo_id'] := photoId;
  end;
  Result := SignedCall('flickr.photosets.removePhoto');
end;

function TPhotosets.getContext(setId, photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
    Required['photoset_id'] := setId;
  end;
  Result := SimpleCall('flickr.photosets.getContext');
end;

constructor TPhotosets.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TPlaces = class(TRESTApi)       *}
{**************************************}
function TPlaces.find(query: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['query'] := query;
  end;
  Result := SimpleCall('flickr.places.find');
end;

function TPlaces.findByLatLon(Latitude, Longitude: Double;
                              Accuracy: TGeoAccuracy): String;
begin
  with FRequest do begin
    Initialize;
    Required['lat'] := CoordToStr(Latitude);
    Required['lon'] := CoordToStr(Longitude);
    if Accuracy <> 0 then
      Optional['accuracy'] := IntToStr(Accuracy);
  end;
  Result := SimpleCall('flickr.places.findByLatLon');
end;

function TPlaces.resolvePlaceId(placeId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['place_id'] := placeId;
  end;
  Result := SimpleCall('flickr.places.resolvePlaceId');
end;

function TPlaces.resolvePlaceURL(placeURL: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['url'] := placeURL;
  end;
  Result := SimpleCall('flickr.places.resolvePlaceURL');
end;

constructor TPlaces.Create(AOwner: TFlickr; Sign: TSignOption);
begin
  inherited;
end;


{**************************************}
{*    TTPrefs = class(TRESTApi)       *}
{**************************************}

function TPrefs.getContentType: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.prefs.getContentType');
end;

function TPrefs.getGeoPerms: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.prefs.getHidden');
end;

function TPrefs.getHidden: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.prefs.getHidden');
end;

function TPrefs.getPrivacy: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.prefs.getPrivacy');
end;

function TPrefs.getSafetyLevel: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.prefs.getSafetyLevel');
end;

constructor TPrefs.Create(AOwner: TFlickr; Sign: TSignOption);
begin
  inherited;
end;


{**************************************}
{*    TReflection = class(TRESTApi)   *}
{**************************************}

function TReflection.getMethodInfo(Name: string): String;
begin
  with FRequest do begin
    Initialize;
    Required['method_name'] := Name;
  end;
  Result := SimpleCall('flickr.reflection.getMethodInfo');
end;

function TReflection.getMethods: String;
begin
  FRequest.Initialize;
  Result := SimpleCall('flickr.reflection.getMethods');
end;

constructor TReflection.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TTags = class(TRESTApi)         *}
{**************************************}

function TTags.getHotList(period: String = ''; count: Integer = 0): String;
begin
  FRequest.Initialize;
  FRequest.Optional['period'] := period;
  {A example of the dangers of "with...do"; if I'd used it here,
  "count" would had meant "FRequest.Count"--And no, I didn't at first. :-)}
  if count > 0 then
    FRequest.Optional['count'] := IntToStr(count);
  Result := SimpleCall('flickr.tags.getListPhoto');
end;


function TTags.getListPhoto(photoId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['photo_id'] := photoId;
  end;
  Result := SimpleCall('flickr.tags.getListPhoto');
end;

{This method needs some testing, since I don't know if the result will
 depends of whether the call is signed or not, and if an empty user_id
 means the current user or all Flickr users, etc.
 In the mean time I'll do just a SimpleCall.}
function TTags.getListUser(userId: String = ''): String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
  end;
  {if userId <> '' then
    Result := SignedCall('flickr.tags.getListUser')
  else {}
    Result := SimpleCall('flickr.tags.getListUser');
end;

function TTags.getListUserPopular(userId: String = '';
                                  count: Integer = 0): String;
begin
  FRequest.Initialize;
  FRequest.Optional['user_id'] := userId;
  if count > 0 then
    FRequest.Optional['count'] := IntToStr(Count);
  {I'm not sure if this is the correct way to cope with this situation...}
  if userId = '' then
    Result := SimpleCall('flickr.tags.getListUserPopular')
  else
    Result := SignedCall('flickr.tags.getListUserPopular');
end;

{LCM: 2008/03/31}
function TTags.getListUserRaw(userId: String = ''; tag: String = ''): String;
begin
  FRequest.Initialize;
  FRequest.Optional['tag'] := tag;
  {I'm not sure if this is the correct way to cope with this situation...}
  if userId = '' then
    Result := SimpleCall('flickr.tags.getListUserRaw')
  else
    Result := SignedCall('flickr.tags.getListUserRaw');
end;


function TTags.getRelated(tag: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['tag'] := tag;
  end;
  Result := SimpleCall('flickr.tags.getRelated');
end;

constructor TTags.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TTest = class(TRESTApi)         *}
{**************************************}

constructor TTest.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;

function TTest.echo(source: array of String): String;
var i: Integer;
begin
  with FRequest do begin
    Initialize;
    for i := Low(source) to High(source) do
      Parameters.Add(source[i]);
  end;
  Result := SimpleCall('flickr.test.echo');
end;

function TTest.echo(source: TStrings): String;
begin
  with FRequest do begin
    Initialize;
    AddStrings(source);
  end;
  Result := SimpleCall('flickr.test.echo');
end;

function TTest.login: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.test.login');
end;

function TTest.null: String;
begin
  FRequest.Initialize;
  Result := SignedCall('flickr.test.null');
end;

function TTest.GenericCall(Method: String; Params: TStrings;
                           Signed: Boolean): String;
begin
  with FRequest do begin
    Initialize;
    AddStrings(Params);
  end;
  if Signed then Result := SignedCall(Method)
            else Result := SimpleCall(Method);
end;


{**************************************}
{*    TUrls = class(TRESTApi)         *}
{**************************************}

function TUrls.getGroup(groupId: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['group_id'] := groupId;
  end;
  Result := SimpleCall('flickr.urls.getGroup');
end;

function TUrls.getUserPhotos(userId: String = ''): String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
  end;
  if userId = '' then
    Result := SimpleCall('flickr.urls.getUserPhotos')
  else
    Result := SignedCall('flickr.urls.getUserPhotos');
end;

function TUrls.getUserProfile(userId: String = ''): String;
begin
  with FRequest do begin
    Initialize;
    Optional['user_id'] := userId;
  end;
  if userId = '' then
    Result := SimpleCall('flickr.urls.getUserProfile')
  else
    Result := SignedCall('flickr.urls.getUserProfile');
end;

function TUrls.lookupGroup(groupUrl: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['url'] := groupUrl;
  end;
  Result := SimpleCall('flickr.urls.lookupGroup');
end;

function TUrls.lookupUser(userUrl: String): String;
begin
  with FRequest do begin
    Initialize;
    Required['url'] := userUrl;
  end;
  Result := SimpleCall('flickr.urls.lookupUser');
end;

constructor TUrls.Create(AOwner: TFlickr; Sign: TSignOption = sgnRequired);
begin
  inherited;
end;


{**************************************}
{*    TWebService = class             *}
{**************************************}

procedure TWebService.SetServiceType(const Value: TServiceType);
begin
  if FServiceType <> Value then begin
    FServiceType := Value;
    FBaseURI := KnownBaseURI[FServiceType];
  end;
end;

procedure TWebService.SetBaseURI(const Value: String);
begin
  FBaseURI := Value;
end;

function TWebService.GetEndpoint(Index: TEndpoints): String;
begin
  case Index of
  epBaseRPC:  Result := FBaseURI + 'services/xmlrpc/';
  epBaseSOAP: Result := FBaseURI + 'services/soap/';
  epBaseREST: Result := FBaseURI + 'services/rest/';
  epUpload:   Result := FBaseURI + 'services/upload/';
  epReplace:  Result := FBaseURI + 'services/replace/';
  epAuth:     Result := FBaseURI + 'services/auth/';
  epLogout:   Result := GetEndpoint(epAuth) + 'fresh/';
  epMethod:   Result := GetEndpoint(epBaseREST) + '?method=';
  else {raise OutofBounds(unknown endpoint)};
  end;
end;

constructor TWebService.Create(Service: TServiceType = stFlickr);
begin
  ServiceType := Service;
end;


{$IFDEF DELPHI}
{**************************************}
{*  Default Authorize Event Handler   *}
{**************************************}
procedure DefaultAuthorize(Sender: TFlickr; LoginURL: String;
                           Reason:TAuthReason; var Cancel: Boolean);
const //sCap = 'Authorization Request for Flickr API-based Applications';
      FEED = #13#10; DFEED = FEED + FEED;
resourceString
      sReq = 'This program requires your authorization' + FEED +
             'before it can interact with Flickr on your behalf.' + DFEED +
             'In order to do that I''ll open a special web page  ' + FEED +
             'of Flickr in your browser. When you''ve finished, ' + FEED +
             'just come back to this program to complete the process.' + FEED;
      sWait = 'Return here once you have finished the authorization' + FEED +
              'process on www.flickr.com and click "OK".' + DFEED +
              'If there was any problem or just don''t want to' + FEED +
              'authorize now, click "Cancel".' + FEED +
              'Remember that you can revoke the authorization ' + FEED +
              'at any time in your account page on Flickr.com' + FEED;
      sBrowserError = 'Sorry! For some queer reason' +
                      'I can''t launch your browser';
//var UrlWide: WideString;
var doWhat: Word;
    s: String;
begin
  {*Depends: Windows.pas->IDCANCEL; Dialogs.pas->MessageDlg, mtXXX, mbXXXX}
  doWhat := MessageDlg(sReq, mtConfirmation, mbOKCancel + [mbIgnore], 0);
  case doWhat of
  IDIGNORE: begin
      s := LoginURL;
      if InputQuery('Redirecting by hand', 'Navigate to this link:', s) then
        Cancel := MessageDlg(sWait, mtConfirmation, mbOKCancel, 0) = IDCANCEL;
    end;
  IDOK:
    if LaunchBrowser(WideString(LoginURL)) then
        Cancel := MessageDlg(sWait, mtConfirmation, mbOKCancel, 0) = IDCANCEL
    else
      raise Exception.Create(SBrowserError);
  else
    Cancel := True;
  end;
end;
{$ENDIF}


{**************************************}
{*    TFlickr = class                 *}
{**************************************}

procedure TFlickr.SetApiKey(AKey: String);
begin
  FApiKey := AKey;
end;

procedure TFlickr.SetSecret(ASecret: String);
begin
  FSecret := ASecret;
end;

{LCM: 2007-01-07 - Added because the change of type of FService}
function TFlickr.GetService: TWebService;
begin
  if not Assigned(FService) then
    FService := TWebService.Create(stFlickr);
  Result := FService;
end;

constructor TFlickr.Create(AKey, ASecret: String;
                           AService: TServiceType = stFlickr);
begin
  inherited Create;
  FApiKey  := AKey;
  FSecret  := ASecret;
  FToken   := '';
  FLevel   := '';
  FService := TWebService.Create(AService);
  FUser    := TBasicUser.Create;
end;


{**************************************}
{*    TFlickrEx = class               *}
{**************************************}

function TFlickr.GetUser: TBasicUser;
begin
  if FUser = nil then
    FUser := TBasicUser.Create;
  Result := FUser;
end;

function TFlickrEx.GetAuth: TAuth;
begin
  if FAuth = nil then
    FAuth := TAuth.Create(Self);
  Result := FAuth;
end;

function TFlickrEx.GetActivity: TActivity;
begin
  if FActivity = nil then
    FActivity := FActivity.Create(Self, FSignOption);
  Result := FActivity;
end;

function TFlickrEx.GetBlogs: TBlogs;
begin
  if FBlogs = nil then
    FBlogs := TBlogs.Create(Self, FSignOption);
  Result := FBlogs;
end;

function TFlickrEx.GetCommons: TCommons;
begin
  if FCommons = nil then
    FCommons := TCommons.Create(Self, FSignOption);
  Result := FCommons;
end;

function TFlickrEx.GetContacts: TContacts;
begin
  if FContacts = nil then
    FContacts := TContacts.Create(Self, FSignOption);
  Result := FContacts;
end;

function TFlickrEx.GetFavorites: TFavorites;
begin
  if FFavorites = nil then
    FFavorites := TFavorites.Create(Self, FSignOption);
  Result := FFavorites;
end;

function TFlickrEx.GetGroups: TGroups;
begin
  if FGroups = nil then
    FGroups := TGroups.Create(Self, FSignOption);
  Result := FGroups;
end;

function TFlickrEx.GetInterestingness: TInterestingness;
begin
  if FInteresting  = nil then
    FInteresting := TInterestingness.Create(Self, FSignOption);
  Result := FInteresting;
end;

function TFlickrEx.GetPeople: TPeople;
begin
  if FPeople = nil then
    FPeople := TPeople.Create(Self, FSignOption);
  Result := FPeople;
end;

function TFlickrEx.GetPhotos: TPhotos;
begin
  if FPhotos = nil then
    FPhotos := TPhotos.Create(Self, FSignOption);
  Result := FPhotos;
end;

function TFlickrEx.GetPhotosets: TPhotosets;
begin
  if FPhotosets = nil then
    FPhotosets := TPhotosets.Create(Self, FSignOption);
  Result := FPhotosets;
end;

function TFlickrEx.GetPlaces: TPlaces;
begin
  if FPlaces = nil then
    FPlaces := TPlaces.Create(Self, FSignOption);
  Result := FPlaces;
end;

function TFlickrEx.GetPrefs: TPrefs;
begin
  if FPrefs = nil then
    FPrefs := TPrefs.Create(Self, FSignOption);
  Result := FPrefs;
end;

function TFlickrEx.GetReflection: TReflection;
begin
  if FReflection = nil then
    FReflection := TReflection.Create(Self, FSignOption);
  Result := FReflection;
end;

function TFlickrEx.GetTags: TTags;
begin
  if FTags = nil then
    FTags := TTags.Create(Self, FSignOption);
  Result := FTags;
end;

function TFlickrEx.GetTest: TTest;
begin
  if FTest = nil then
    FTest := TTest.Create(Self, FSignOption);
  Result := FTest;
end;

function TFlickrEx.GetUrls: TUrls;
begin
  if FUrls = nil then
    FUrls := TUrls.Create(Self, FSignOption);
  Result := FUrls;
end;

procedure TFlickrEx.SetSignAll(Value: Boolean);
begin
  if Value then FSignOption := sgnAlways
           else FSignOption := sgnRequired;
  if Assigned(FActivity) then FActivity.SignAll := Value;
  if Assigned(FBlogs) then FBlogs.SignAll := Value;
  if Assigned(FCommons) then FCommons.SignAll := Value;
  if Assigned(FContacts) then FContacts.SignAll := Value;
  if Assigned(FFavorites) then FFavorites.SignAll := Value;
  if Assigned(FGroups) then FGroups.SignAll := Value;
  if Assigned(FPeople) then FPeople.SignAll := Value;
  if Assigned(FPhotos) then FPhotos.SignAll := Value;
  if Assigned(FPhotosets) then FPhotosets.SignAll := Value;
  if Assigned(FPlaces) then FPlaces.SignAll := Value;
  if Assigned(FPrefs) then FPrefs.SignAll := Value; {LCM: 2009/03/30 Bug}
  if Assigned(FReflection) then FReflection.SignAll := Value;
  if Assigned(FTags) then FTags.SignAll := Value;
  if Assigned(FTest) then FTest.SignAll := Value;
  if Assigned(FUrls) then FUrls.SignAll := Value;
end;

function TFlickrEx.Authorize(Perms: String = ''; Token: String = ''): Boolean;
var Cancel: Boolean;
    Reason: TAuthReason;
    LoginURL: String;
    Retry: ShortInt;
    WantLevel, GotLevel: byte; // LCM 2006-11-22

  function LevelCode(Value: String): byte; // LCM 2006-11-22
  begin
    if Value = 'delete' then Result := 4
    else if Value = 'write' then Result := 2
    else if Value = 'read' then Result := 1
    else Result := 0;
  end;

begin
  Result := False;
  if Perms = '' then
    Result := True
  else begin
    Reason := arOther;
    Perms := AnsiLowerCase(Perms); { Just in case... ;-) }
    if Token <> '' then begin {If there's a token, check it}
      try
        Auth.checkToken(Token);
        GotLevel  := LevelCode(Level);
        WantLevel := LevelCode(Perms);
        if (GotLevel >= WantLevel) then Result := True
                                   else Reason := arLevelPromotion;
      except
        on e: EFlickrAuthError do
          if e.Code = 98 then Reason := arInvalidLoginOrToken
                         else raise;
      end;
    end else
      Reason := arNoToken;

    if not Result then begin
      Cancel := False;
      with Auth do LoginURL := GetLoginLink(Perms, getFrob);
      if Assigned(FOnAuthorize) then
        FOnAuthorize(Self, LoginURL, Reason, Cancel)
      else
{$IFDEF DELPHI}
        DefaultAuthorize(Self, LoginURL, Reason, Cancel);
{$ELSE}
        Cancel := True;
{$ENDIF}
      if not Cancel then begin
        Retry := FFrobRetries;
        repeat
(**
          with Auth do try
            getToken(FFrob);
            Result := True;
          except
            on EFlickrError do begin
              Dec(Retry);
              if Retry > 0 then Sleep(1000); {*DEPENDS: windows.pas}
            end; { on EFlickrError }
          end;{ try (with Auth do ...)}
(**)
          try
            Auth.getToken(Auth.FFrob);
            Result := True;
          except
            on EFlickrError do begin
              Dec(Retry);
              if Retry > 0 then Sleep(1000); {*DEPENDS: windows.pas}
            end; { on EFlickrError }
          end;{ try ... }
(**)


        until (Retry <= 0) or Result;
        {If there was an error, it can be re-raised with
         Flickr.Auth.CheckError(LastResponse)}
      end;{if not Cancel }
    end;{if not Result }
  end;{if Perms = '' ... else }
end;

constructor TFlickrEx.Create(AKey, ASecret: String;
                             AService: TServiceType = stFlickr);
begin
  inherited Create(AKey, ASecret, AService);
  FOnAuthorize := nil;
  FFrobRetries := 5;
  FApiKey := AKey;
  FSecret := ASecret;
  FToken := '';
  FLevel := '';
  {FService := TWebService.Create(AService);{Already created by inheritance}
  FUser      := TBasicUser.Create;
  FAuth      := nil;
  FActivity  := nil;
  FBlogs     := nil;
  FCommons   := nil;
  FContacts  := nil;
  FFavorites := nil;
  FGroups    := nil;
  FPeople    := nil;
  FPhotos    := nil;
  FPhotosets := nil;
  FPlaces    := nil;
  FReflection:= nil;
  FTags      := nil;
  FTest      := nil;
  FUrls      := nil;
  SetSignAll(False);
end;

destructor TFlickrEx.Destroy;
begin
  FOnAuthorize := nil;{DefaultAuthorize;}
  FService.Free;
  FUser.Free;
  FAuth.Free;
  FActivity.Free;
  FBlogs.Free;
  FCommons.Free;
  FContacts.Free;
  FFavorites.Free;
  FGroups.Free;
  FInteresting.Free;
  FPeople.Free;
  FPhotos.Free;
  FPhotosets.Free;
  FPlaces.Free;
  FReflection.Free;
  FTags.Free;
  FTest.Free;
  FUrls.Free;
  inherited Destroy;
end;

{---------------------------------------------------------}

{initialization
{}

end.

