program chepin_php;

{$APPTYPE CONSOLE}

uses
  SysUtils, RegExpr;

type
  TArray = array [1..4] of Boolean;
  TVariable = record
     Variable : string;
     ArrayOfTypes : TArray;
    end;

const
  enteredType = 1;
  modifyType = 2;
  manageType = 3;
  parasitType = 4;

var
  ArrayOfRecords : array of TVariable;


// считывание из файла
procedure OpenFileAndReadText(out codeText : string);
var
  fileName : TextFile;
  stringCurrent : string;
  IsComment : Boolean;

// проверка на наличие комментариев
  procedure CheckForComments(var codeString : string);
  var
    i : Integer;
    IsDelete : Boolean;
    // удаление многострочного комментария
    procedure DeleteMultiLineComment();
    var
      i : Integer;
    begin
      i := 1;
      while (i <= Length(codeString)) and (not IsDelete) do
        begin
          if not ((codeString[i] = '*') and (codeString[i + 1] = '/')) then
            begin
              Delete(codeString, i, 1);
              Dec(i);
            end
          else
            begin
              Delete(codeString, i, 2);
              IsComment := False;
            end;
          Inc(i);
        end;
    end;

    // удаление однострочного комментария
    procedure DeleteOneLineComment();
    var
      i : Integer;
    begin
      i := 1;
      while i <= Length(codeString) do
        begin
          if ((codeString[i] = '/') and (codeString[i + 1] = '/')) or (codeString[i] = '#') then
          SetLength(codeString, i - 1);
          Inc(i);
        end;
    end;

  //выбор типа удаляемого комментария
  begin
    i := 1;
    IsComment := False;
    while (i <= Length(codeString)) and (not IsComment) do
    if (codeString[i] = '/') and (codeString[i + 1] = '*') then
      IsComment := True
    else Inc(i);

    if IsComment then DeleteMultiLineComment
    else DeleteOneLineComment;
  end;

  //удаление строковых констант
  procedure DeleteStrings(var codeString : string);
  var
    Regular : TRegExpr;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := '"([^"]*)"';
    codeString := Regular.Replace(codeString, ' ', False);
  end;

begin
  AssignFile(fileName, 'text.txt');
  Reset(fileName);
  while not Eof(fileName) do
  begin
    Readln(fileName, stringCurrent);
    CheckForComments(stringCurrent);
    DeleteStrings(stringCurrent);
    codeText := codeText +  stringCurrent;
  end;
  CloseFile(fileName);
end;

// проверка на повтор переменной
function CheckReplays(const variable : string) : Boolean;
var
  i : Integer;
begin
  Result := False;
  for i := 0 to High(ArrayOfRecords) do
   if ArrayOfRecords[i].Variable = variable then
     begin
       Result := True;
       Exit;
     end;
end;

// поиск управляющих переменных
procedure FindManageVariables(const codeText, variable : string);
var
  Regular : TRegExpr;
begin
  Regular := TRegExpr.Create;
  Regular.Expression := '(if|while|for|foreach|switch)\s*\([^\)]*?(\' + variable + ').*?\)';
  if Regular.Exec(codeText) then
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[manageType] := True
  else
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[manageType] := False;
end;

// переприсваиваемые переменные
procedure FindModifyVariables(const codeText, variable : string);

  // изменяемые переменные
  function FindChangeableVariables(const codeText, variable : string) : Boolean;
  var
    Regular : TRegExpr;
    numberMatches : Integer;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := '(\' + variable + ')\s*(=|\+=|\-=|\*=)\s*\w*';
    numberMatches := 0;
    if Regular.Exec(codeText) = True then
    begin
      repeat
        Inc(numberMatches)
      until not Regular.ExecNext;
    end;
    if numberMatches >= 2 then
      Result := True
    else
      Result := False;
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[modifyType] := Result;
  end;

  // созданные переменные, не паразитные
  function FindCreatableVariables(const codeText, variable : string) : Boolean;
  var
    Regular : TRegExpr;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := '(\' + variable + ')\s*=\s*\w*';
    if  Regular.Exec(codeText) then
      begin
        Regular.Expression := '\$[a-zA-Z_][\w_]*\s*=[^\=]*?(\' + variable + ').*?\;';
        if Regular.Exec(codeText) then
          Result := True
        else
          Result := False;
      end;
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[modifyType] := Result;
  end;

  // поиск массивов и переменных в функциях
  function FindModifyVariable(const RegExp : string; const codeText : string) : Boolean;
  var
    Regular : TRegExpr;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := RegExp;
    if Regular.Exec(codeText) then
      Result := True
    else
      Result := False;
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[modifyType] := Result;
  end;

begin
  if not ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[parasitType] then
  if FindChangeableVariables(codeText, variable) then Exit
  else
  if FindCreatableVariables(codeText, variable) then Exit
  else
  if FindModifyVariable('(\' + variable + ')\[(\w*|\s*)\]\s*=' ,codeText) then Exit
  else
  if FindModifyVariable('(for|while|do).*?\{.*?(\' + variable + ')\s*=\s*\w*.*;' ,codeText) then Exit;
end;

// переменные ввода/вывода, для расчетов
procedure FindEnteredVariables(const codeText, variable : string);

  // переменные присваиваемые 1 раз
  function FindCreateableAndReWriteable1TimeVariables (const codeText, variabe : string) : Boolean;
  var
    Regular : TRegExpr;
    numberMatches: Integer;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := '(\' + variable + ')\s*=\s*\w*';
    numberMatches := 0;
    if Regular.Exec(codeText) then
      repeat
        Inc(numberMatches);
      until not Regular.ExecNext;
    if numberMatches = 1 then
      Result := True
    else
      Result := False;
  end;

  //переменные для ввода
  function FindVariablesForInput(const RegExp : string; const codeText : string) : Boolean;
  var
    Regular : TRegExpr;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := RegExp;
    if Regular.Exec(codeText) then
      Result := True
    else
    Result := False;
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType] := Result;
  end;

  // переменные вывода (echo)
  procedure FindOutputVariables(const codeText : string; variable : string);
  var
    Regular : TRegExpr;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := '(echo)[^;]*\' + variable;
    if Regular.Exec(codeText) then
      ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType] := True;
  end;

  // неиспользуемые переменные
  procedure FindNonUsableVariables(const codeText : string; variable : string);
  var
    Regular : TRegExpr;
    numberMatches : Integer;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := ';\s*?\$[a-zA-Z_][\w_]*\s*=.*?(\' + variable + ').*?\;';
    numberMatches := 0;
    numberMatches := 0;
    if Regular.Exec(codeText) then
     repeat
       Inc(numberMatches);
     until not Regular.ExecNext;
    if numberMatches <> 0 then
      ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType] := True
    else
    begin
      ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[parasitType] := True;
      ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType] := False;
    end;
  end;

  // инкрементируемые/декрементируемые переменные
  procedure FindIncrementVariables(const codeText, variable : string);
  var
    Regular : TRegExpr;
  begin
    Regular := TRegExpr.Create;
    Regular.Expression := '(\' + variable + ')((\s*(\+=|\-=|\*=))|((\+\+)|(\-\-)))';
    if Regular.Exec(codeText) then
      ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType] := False;
  end;

begin
  if FindCreateableAndReWriteable1TimeVariables(codeText, variable) then
  FindNonUsableVariables(codeText, variable);
  if not ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[parasitType] then
  FindVariablesForInput('(if|switch)\s*\([^\)]*?(\' + variable + ').*?\)', codeText);
  if ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType] then FindIncrementVariables(codeText, variable);
  if not ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType] then FindOutputVariables(codeText, variable);
end;

procedure FindParasitVariables(const codeText, variable : string);
var
  Regular : TRegExpr;
  numberMatches : Integer;
begin
  Regular := TRegExpr.Create;
  Regular.Expression :=  variable;
  numberMatches := 0;
  if Regular.Exec(codeText) then
    repeat
      Inc(numberMatches);
    until not Regular.ExecNext;
  if numberMatches = 1 then
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[parasitType] := True
  else
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[parasitType] := False;
  if (not ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[enteredType]) and (not ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[modifyType]) and (not ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[manageType]) then
    ArrayOfRecords[High(ArrayOfRecords)].ArrayOfTypes[parasitType] := True
end;

procedure FindVariable(const codeText : string);
const
  regExpression = '\$[w]([wd]+)*';
var
  Regular : TRegExpr;
  lengthArray: Integer;
begin
  Regular := TRegExpr.Create;
  Regular.Expression := '\$[a-zA-Z_]([\w_]*)';
  lengthArray := 1;
 // Writeln('All variables are:');
  if (Regular.Exec(codeText)) then
  repeat
   if not CheckReplays(Regular.Match[0]) then
    begin
   //  Writeln(Regular.Match[0]);
     SetLength(ArrayOfRecords , lengthArray);
     ArrayOfRecords[High(ArrayOfRecords)].Variable := Regular.Match[0];
     FindManageVariables(codeText, Regular.Match[0]);
     FindModifyVariables(codeText, Regular.Match[0]);
     FindEnteredVariables(codeText, Regular.Match[0]);
     FindParasitVariables(codeText, Regular.Match[0]);
     Inc(lengthArray);
    end;
  until not (Regular.ExecNext);
  Regular.Free
end;

function CountChepinMetric : Real;
var
  i : Integer;
  enteredCoefficient, modifyCoefficient, manageCoefficient, parasitCoefficient: Integer;
begin
  Result := 0;
  for i := 0 to High(ArrayOfRecords) do
  begin
    if ArrayOfRecords[i].ArrayOfTypes[enteredType] then enteredCoefficient := 1
    else enteredCoefficient := 0;
    if ArrayOfRecords[i].ArrayOfTypes[modifyType] then modifyCoefficient := 1
    else modifyCoefficient := 0;
    if ArrayOfRecords[i].ArrayOfTypes[manageType] then manageCoefficient := 1
    else manageCoefficient := 0;
    if ArrayOfRecords[i].ArrayOfTypes[parasitType] then parasitCoefficient := 1
    else parasitCoefficient := 0;
    Result := Result + 1 * enteredCoefficient + 2 * modifyCoefficient + 3 * manageCoefficient + 0.5 * parasitCoefficient;
  end;
end;

function PrintVariables(typeVariable : integer) : integer;
var
  i: integer;
begin
  Result:= 0;
  for i := 0 to High(ArrayOfRecords) do
    if ArrayOfRecords[i].ArrayOfTypes[typeVariable] then
     begin
       Writeln(ArrayOfRecords[i].Variable);
       Inc(Result);
     end;
end;

procedure PrintResult(typeNumber : Integer; varType : string);
begin
  Writeln(varType);
  writeln(PrintVariables(typeNumber), ' - number of variables in this type');
  Writeln;
end;

procedure Main;
var
  codeText : string;
  chepinMetric : Real;
begin
  OpenFileAndReadText(codeText);
  FindVariable(codeText);
  chepinMetric := CountChepinMetric;
  PrintResult(1, '///////input/output///////');
  PrintResult(2, '///////modify///////');
  PrintResult(3, '///////manage///////');
  PrintResult(4, '///////parasit///////');
  Writeln('Result Chepin''s metric = ', chepinMetric:0:1);
  Readln;
end;

begin
  Main
end.
