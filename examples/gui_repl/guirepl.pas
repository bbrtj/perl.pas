unit GUIRepl;

{$mode objfpc}{$H+}

interface

uses
	Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ActnList,
	PerlEmbed;

type

	{ TReplForm }

	TReplForm = class(TForm)
		RunPerlCode: TAction;
		FormActions: TActionList;
		RunButton: TButton;
		InputMemo: TMemo;
		OutputMemo: TMemo;
		procedure FormCreate(Sender: TObject);
		procedure FormDestroy(Sender: TObject);
		procedure RunPerlCodeExecute(Sender: TObject);
	strict private
		FPerl: TPerlHandle;
	end;

var
	ReplForm: TReplForm;

implementation

{$R *.lfm}

procedure TReplForm.FormCreate(Sender: TObject);
begin
	FPerl := TDynaLoaderPerl.Create(['-MData::Dumper', '-e0']);
end;

procedure TReplForm.FormDestroy(Sender: TObject);
begin
	FPerl.Free;
end;

procedure TReplForm.RunPerlCodeExecute(Sender: TObject);
var
	Res: TPerlSV;
	Dump: String;
begin
	FPerl.EnterContext;

	try try
		Res := FPerl.RunCode(self.InputMemo.Text);
		Dump := FPerl.ScalarToString(
			FPerl.CallSub(
				'Data::Dumper::Dumper',
				[Res]
			)
		);

		self.OutputMemo.Text := Dump;
	except
		on E: EPerl do
			self.OutputMemo.Text := 'Perl error occured: ' + E.Message;
	end;
	finally
		FPerl.LeaveContext;
	end;
end;

end.

