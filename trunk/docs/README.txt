= Rawflickr Delphi Library =

Rawflickr is a library designed to allow Delphi programs to access the Flickr API as if it were a set of local function. It does so by providing a set of classes, one for each group of Flickr API methods (auth, blogs, photos, ...) and making the methods inside each class mimic almost exactly the corresponding API method, though using comfortable !ObjectPascal types rather than raw strings.

== License ==

This library is free, open source software released under a *Mozilla Public License 1.1*.
All the third-party libraries used or referenced (except, of course, Borland's ones) are also open source, released under similar licenses.

== Features ==
  * Very easy to install and use. (But there is a Beginners Guide in preparation)
  * Easy built-in (desktop) authentication, should your application require it.
  * Contains all published API methods (as of *June, 2008*), including the *Upload* and *Replace* APIs
  * Except those requiring a permission level, you can make calls either signed or unsigned.
  * Most calls return directly the Flickr XML response
  * It can be used with services other than Flickr, provided they use the same API (p.e. 23hq)
  * Complete set of documentation ... and I'm working on more!. 
  * Easily to update and extend; API updates can be normally reflected in minutes.
  * (planned) Support for either Indy or Synapse as networking libraries.
  * (planned) Multiplatform support through compatibility with Delphi, Kylix and Lazarus/FPC.

== Requirements ==

To use this library you'll need:

  * Delphi 5 (3?) or higher, Kylix 3 (planned) or Lazarus/FPC (planned)
  * Internet Direct (Indy) version 9 (compat. with Indy 10 planned) -or-
  * Synapse 37+ (in development)
  * MD5.pas, by M. Fichtner <http://www.fichtner.net/delphi/md5/> (included in the package)
  * LibXMLParser, by S. Heymann <http://www.destructor.de> (included in the package)
  * API key & shared secret if your target is Flickr:
    http://www.flickr.com/services/api/keys/

----
=== A bit of legalese ===

Flickr is a trademark of Yahoo, Inc. This library was designed to interface with Flickr(tm) services, but it's in no way related to or endorsed by Flickr or Yahoo themselves.

----
{ $Id }