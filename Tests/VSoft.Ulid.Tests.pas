unit VSoft.Ulid.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture('TUlid.tests')]
  TTestULid = class
  public

//    [Test]
    procedure TestULID_Create;

//    [Test]
    procedure TestULID_Equals;

//    [Test]
    procedure Test_Parse;

    [Test]
    procedure Test_ToString;

//    [Test]
    procedure Test_FromGuid;
  end;

implementation

uses
  VSoft.ULid,
  System.SysUtils,
  System.Diagnostics,
  System.Generics.Collections;

{ TTestULid }

procedure TTestULid.TestULID_Create;
var
  i : integer;
//  dict : TDictionary<string,byte>;
  stopWatch : TStopwatch;
  ulid : TUlid;
//  s : string;

const
    {$IFDEF WIN64}
    //5 M
    count =  5000000;
    {$ELSE}
    count =  5000000; //will get out of memory for too many on win32
    {$ENDIF}

begin
//  dict := TDictionary<string,byte>.Create; //slow.
//  try
    stopWatch := TStopwatch.StartNew;
    //using dictionary to detect dupes
    for I := 0 to count -1 do
    begin
      ulid := TUlid.Create;
//      s := ulid.ToString;
      //dict.Add(ulid.ToString,0);
    end;
    stopwatch.Stop;
    Writeln(IntToStr(count) + ' uli''s created  in : ' + IntToStr(stopwatch.ElapsedMilliseconds) + 'ms - ' + IntToStr((count div stopWatch.ElapsedMilliseconds)) + ' p/ms' );
//  finally
//  //  dict.Free;
//  end;
end;

procedure TTestULid.TestULID_Equals;
var
  a, b : TUlid;
begin
  a := TUlid.Create;
  b := a;
  Assert.IsTrue(a.Equals(b));
end;

procedure TTestULid.Test_FromGuid;
var
  guid : TGuid;
  ulid : TUlid;
begin
  guid := TGuid.NewGuid;
  ulid := TUlid.FromGuid(guid);
  writeln(ulid.ToString);
  ulid := TUlid.Create;
  writeln(ulid.ToString);

end;

procedure TTestULid.Test_Parse;
var
  ulId : TUlid;
begin
  ulId := TUlid.Parse('01J4GNG4KAH5EHPWVHD6WQWS70');

end;

procedure TTestULid.Test_ToString;
var
  ulId : TUlid;
begin
  ulId := TUlid.Parse('01J4GNG4KAH5EHPWVHD6WQWS70');

  Assert.AreEqual('01J4GNG4KAH5EHPWVHD6WQWS70', ulId.ToString);

end;

initialization
  TDUnitX.RegisterTestFixture(TTestULid);

end.
