program Upload;

uses
  Forms,
  Mainform in 'Mainform.pas' {Main};

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
