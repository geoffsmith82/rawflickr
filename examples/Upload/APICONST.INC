
{ Before using this application, you need to obtain an API key and secret
  from Flickr, at: http://www.flickr.com/services/api/keys
  Once you hve them, insert insert each value in the corresponding constant.
}
const
{$IFDEF UPTO23}
  APIKEY = 'DemoUploader';
  SECRET = '';
{$ELSE}
  APIKEY = 'YOUR_API_KEY_HERE';
  SECRET = 'ASSOCIATED_SECRET_HERE';
{$ENDIF}

