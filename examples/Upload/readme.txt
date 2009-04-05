{ $Id$ }

= Upload Example =

This example is a fully functional--albeit rough--demo showing how to authenticate an application and upload an image to Flickr. 

== License ==

This example program is subject to the Mozilla Public License Version 1.1 (the "License");
You can obtain a copy of the license at http://www.mozilla.org/MPL/

== Installation ==

No installation is needed, other than dumping the files in your directory of choice, provided you already installed Rawflickr.

Do note, though, that this example was built against rev 7 of rawflickr.pas, which implemented some missing parameters in TUploadr.Upload; it won't compile with previous versions. If you have one of those (p.e. you version 1.2 from the zip package) you'll need to, at least, download rawflicrk.pas from the trunk and overwrite your copy with it.

The next step is to enter the directory where you dumped the example and edit the file APICONST.INC to insert your own API key and secret. Then, open the project in the IDE and check the DEFINEs at the beginning of Mainform.pas, right after the license block, to suit your needs.

{.DEFINE WC}
  If set, _undefine_ it. That 'wc' stands for 'working copy' and it's there to make the compiler take my own key/secret during development.

{$DEFINE ImgExt}
  Let it set if you've installed Melander's GIFImage and G. Daub's PNGImage. Of course, you could also delete it altogether and modify the 'uses' clause to fit your installation; remember that this was made with Delphi 5, which supports only BMPs, Win metafiles, Win icons and JPG.

Once that's done, compile.

== How to use it ==

It should be obvious but just in case, begin by clicking the button labelled 'User'; then the program will try to, first, read a file named 'user.txt' to see whether an user was already authentified; then it'll try to (re-)authentify the user and, if it succeded, save the token (back) to 'user.txt'. You'll know that all went OK if the signed user name appears in the toolbar.

Do note that such as it is now this program doesn't support multiple accounts; to authenticate as another user you'll have to manually delete the file 'user.txt' and reauthorize.

Once you've authorized the program, all that rests is to open a file (click the button, navigate, select, etc.), fill in the image data (if you want) and click the 'Upload' button. Uploading is done synchronously so, depending of the size of your file, it can take a while; once it's done, there will appear a message box showing the response Flickr sent back, which may be either an OK reponse showing the photo id or an error. In this last case, an exception will be raised  after you click OK in the message box.

Regardless of the result, you can now open and upload another file, or retry uploading the one already opened.

== Suggestions for enhancements ==

Too many to say them all: multiple accounts, upload multiple images, automatic redirection after the upload, add to set, add to group, convert unsupported file types, ... 

Have fun with it!
