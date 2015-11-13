# Rawflickr Delphi Library #

> Rawflickr is a library designed to allow Delphi programs to access the Flickr API as if it were a set of local function. It does so by providing a set of classes, one for each group of Flickr API methods (auth, blogs, photos, ...) and making the methods inside each class mimic almost exactly the corresponding API method, though using comfortable ObjectPascal types rather than raw strings.
> > &lt;wiki:gadget url="http://www.ohloh.net/p/46157/widgets/project\_factoids.xml" border="0" /&gt;
## License ##


> This library is free, open source software released under a **Mozilla Public License 1.1** and all the third-party libraries used or referenced (except, of course, Borland's ones) are also open source, released under similar licenses.

## Features ##
  * Very easy to install and use. (But there is a Beginners Guide in preparation)
  * Easy built-in (desktop) authentication, should your application require it.
  * Contains all published API methods (as of **June, 2008**), including **Upload** and **Replace** APIs
  * Except those requiring a permission level, you can make calls either signed or unsigned.
  * Most calls return directly the Flickr XML response
  * It can be used with services other than Flickr, provided they use the same API (p.e. 23hq)
  * Complete set of documentation ... and I'm working on more!.
  * Easily to update and extend; API updates can be normally reflected in minutes.
  * (planned) Support for either Indy or Synapse as networking libraries.
  * (planned) Multiplatform support through compatibility with Delphi, Kylix and Lazarus/FPC.
> &lt;wiki:gadget url="http://www.ohloh.net/p/46157/widgets/project\_users.xml?style=blue" height="100"  border="0" /&gt;
## Requirements ##

To use this library you'll need:
  * Delphi 5 or higher, Kylix 3 (planned) or Lazarus/FPC (planned)
  * Internet Direct (Indy <http://www.indyproject.org/>) version 9 (compat. with Indy 10 planned) -or-
  * Synapse 37+ <http://www.ararat.cz/synapse/> (planned; [issue #2](http://code.google.com/p/rawflickr/issues/detail?id=2))
  * MD5.pas, by M. Fichtner <http://www.fichtner.net/delphi/md5/>; (copy included in the package and [available in the repository](http://rawflickr.googlecode.com/svn/externals/MD5.zip))
  * LibXMLParser, by S. Heymann <http://www.destructor.de> (copy included in the package and [in the repository](http://rawflickr.googlecode.com/svn/externals/xmlparser.zip))
  * API key & shared secret if your target is Flickr:  http://www.flickr.com/services/api/keys/

**Notes**
  * If your Delphi version is newer than Delphi 5, you may experience some problems, as noted in [issue 7](http://code.google.com/p/rawflickr/issues/detail?id=7).
    * Also, [compatibility with Delphi 2009](http://code.google.com/p/rawflickr/issues/detail?id=10), specifically ref. Unicode support, hasn't been checked yet.


---

### A bit of legalese ###

> Flickr is a trademark of Yahoo, Inc. This library was designed to interface with Flickr(tm) services, but it's in no way related to or endorsed by Flickr or Yahoo themselves.