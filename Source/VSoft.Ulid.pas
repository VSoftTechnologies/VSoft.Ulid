unit VSoft.Ulid;


interface

uses
  System.SyncObjs,
  System.SysUtils;


type
  //see https://en.wikipedia.org/wiki/Xorshift
  //
  TXorShift64 = record
  private
    Fx : UInt64;
  public
    class function Create(seed : UInt64) : TXorShift64;static;
    function Next : UInt64;inline;
    function IsInit : boolean;
  end;

  TUlid = packed record
  private
    //the order of these fields matter, do not change.
    // Timestamp(48bits)
    FTimeStamp0 : byte;
    FTimeStamp1 : byte;
    FTimeStamp2 : byte;
    FTimeStamp3 : byte;
    FTimeStamp4 : byte;
    FTimeStamp5 : byte;

    FRandomness0 : byte;
    FRandomness1 : byte;
    FRandomness2 : byte;
    FRandomness3 : byte;
    FRandomness4 : byte;
    FRandomness5 : byte;
    FRandomness6 : byte;
    FRandomness7 : byte;
    FRandomness8 : byte;
    FRandomness9 : byte;

  private
    class var
      FXorShift64 : TXorShift64;
  private
    class function InternalNewUlid(timestamp : UInt64) : TUlid;static;inline;
    class function InternalNewUlidFromBytes(const base32bytes : PByte) : TUlid;static;
    class constructor Init;
    class procedure CheckString(const base32Str : string);overload;static;
    class procedure CheckString(const base32Str : AnsiString);overload;static;
  public
    class function TryParse(const base32Str : string; out ulid : TUlId) : boolean;static;
    class function Parse(const base32Str : string) : TUlId;overload;static;
    class function Parse(const base32Str : AnsiString) : TUlId;overload;static;

    class function Create : TUlid;static;
    class function Empty : TUlid;static;
    class function FromGuid(value : TGuid) : TUlid;static;
    function ToString : string;
    function Equals(value : TUlId) : boolean;
    function IsEmpty : boolean;
  end;

{$IFDEF CPUX86}
//only declared here to allow inlining.
procedure AtomicLoad(var target, source: UInt64);
{$ENDIF}

implementation


uses
  {$IFDEF MSWINDOWS}
  WinApi.Windows,
  {$ENDIF}
  System.DateUtils;

const
  Base32Text : array[0..31] of char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','J','K','M','N','P','Q','R','S','T','V','W','X','Y','Z');

  CharToBase32 : array[0..122] of byte = (255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                                  255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 1, 2, 3, 4, 5, 6,
                                  7, 8, 9, 255, 255, 255, 255, 255, 255, 255, 10, 11, 12, 13, 14, 15, 16, 17, 1, 18, 19, 1, 20, 21, 0, 22, 23, 24, 25, 26, 255, 27,
                                  28, 29, 30, 31, 255, 255, 255, 255, 255, 255, 10, 11, 12, 13, 14, 15, 16, 17, 1, 18, 19, 1, 20, 21, 0, 22, 23, 24, 25, 26, 255, 27, 28, 29, 30, 31);

  cBase32StringLen  = 26;


type
  //not available in XE2
    TUInt64Rec = packed record
    case Integer of
      0: (Lo, Hi: Cardinal);
      1: (Cardinals: array [0..1] of Cardinal);
      2: (Words: array [0..3] of Word);
      3: (Bytes: array [0..7] of Byte);
  end;


{ TXorShift64 }

class function TXorShift64.Create(seed: UInt64): TXorShift64;
begin
  if seed <> 0 then
    result.Fx := seed
  else
    result.Fx := 88172645463325252;
end;



function TXorShift64.IsInit: boolean;
begin
  result := Fx <> 0;
end;

//function TXorShift64.Next: UInt64;
//begin
//  Result := Fx;
//  Result := Result xor (Result shl 7);
//  Result := Result xor (Result shr 9);
//  Fx := Result;
//end;

{$IF CompilerVersion < 24}
{$IFDEF CPUX64}
function AtomicCmpExchange(var Destination: UInt64; Exchange: UInt64; Comparand: Int64): UInt64;
asm
      .NOFRAME
      MOV     RAX,R8
 LOCK CMPXCHG [RCX],RDX
end;
{$ELSE}
function AtomicCmpExchange(var Destination: UInt64; Exchange: UInt64; Comparand: UInt64): UInt64;
begin
    result := WinApi.Windows.InterlockedCompareExchange64(Int64(Destination), Int64(Exchange), Int64(Comparand));
end;
{$ENDIF}

{$IFEND}



{$IFDEF CPUX86}
procedure AtomicLoad(var target, source: UInt64);
asm
  movq xmm0,[source]
  movq [target],xmm0
end;
{$ENDIF}
function TXorShift64.Next: UInt64;
var
  prev: UInt64;
begin
  repeat
    {$IFDEF CPUX86}
    AtomicLoad(prev, Fx);
    {$ELSE}
    prev := Fx;
    {$ENDIF}
    Result := prev xor (prev shl 7);
    Result := Result xor (Result shr 9);
  until AtomicCmpExchange(Fx, Result, prev) = prev;
end;

function Random64: UInt64;
var
  Overlay: TUInt64Rec absolute Result;
begin
  Assert(SizeOf(Overlay)=SizeOf(Result));
  Overlay.Lo := Cardinal(Random(MaxInt));
  Overlay.Hi := Cardinal(Random(MaxInt));
end;

function TUlid.ToString : string;
var
  p : PChar;
begin
  SetLength(result, cBase32StringLen);
  p := Pointer(result);

  // timestamp
  p[0] := Base32Text[(FTimestamp0 and 224) shr 5];
  p[1] := Base32Text[FTimestamp0 and 31];
  p[2] := Base32Text[(FTimestamp1 and 248) shr 3];
  p[3] := Base32Text[((FTimestamp1 and 7) shl 2) or ((FTimestamp2 and 192) shr 6)];
  p[4] := Base32Text[(FTimestamp2 and 62) shr 1];
  p[5] := Base32Text[((FTimestamp2 and 1) shl 4) or ((FTimestamp3 and 240) shr 4)];
  p[6] := Base32Text[((FTimestamp3 and 15) shl 1) or ((FTimestamp4 and 128) shr 7)];
  p[7] := Base32Text[(FTimestamp4 and 124) shr 2];
  p[8] := Base32Text[((FTimestamp4 and 3) shl 3) or ((FTimestamp5 and 224) shr 5)];
  p[9] := Base32Text[FTimestamp5 and 31];

  // FRandomness
  p[10] := Base32Text[(FRandomness0 and 248) shr 3];
  p[11] := Base32Text[((FRandomness0 and 7) shl 2) or ((FRandomness1 and 192) shr 6)];
  p[12] := Base32Text[(FRandomness1 and 62) shr 1];
  p[13] := Base32Text[((FRandomness1 and 1) shl 4) or ((FRandomness2 and 240) shr 4)];
  p[14] := Base32Text[((FRandomness2 and 15) shl 1) or ((FRandomness3 and 128) shr 7)];
  p[15] := Base32Text[(FRandomness3 and 124) shr 2];
  p[16] := Base32Text[((FRandomness3 and 3) shl 3) or ((FRandomness4 and 224) shr 5)];
  p[17] := Base32Text[FRandomness4 and 31];
  p[18] := Base32Text[(FRandomness5 and 248) shr 3];
  p[19] := Base32Text[((FRandomness5 and 7) shl 2) or ((FRandomness6 and 192) shr 6)];
  p[20] := Base32Text[(FRandomness6 and 62) shr 1];
  p[21] := Base32Text[((FRandomness6 and 1) shl 4) or ((FRandomness7 and 240) shr 4)];
  p[22] := Base32Text[((FRandomness7 and 15) shl 1) or ((FRandomness8 and 128) shr 7)];
  p[23] := Base32Text[(FRandomness8 and 124) shr 2];
  p[24] := Base32Text[((FRandomness8 and 3) shl 3) or ((FRandomness9 and 224) shr 5)];
  p[25] := Base32Text[FRandomness9 and 31];


end;

class function TUlid.TryParse(const base32Str : string; out ulid : TUlId) : boolean;
begin
  if (Length(base32Str) <> cBase32StringLen) then
    exit(false);

  try
    ulid := Parse(base32Str);
    result := true;
  except
    result := false;
  end;
end;



class function TUlid.Empty: TULid;
begin
  result := Default(TUlid);
end;

function TUlid.Equals(value: TUlId): boolean;
var
  p1, p2 : PByte;
begin
  p1 := @FTimeStamp0;
  p2 := @value.FTimeStamp0;
  result := CompareMem(p1,p2,SizeOf(TUlid));
end;


class function TUlid.FromGuid(value: TGuid): TUlid;
var
  bytes : TArray<byte>;
begin
  bytes := value.ToByteArray();
  Move(bytes, result, 16);
end;

class constructor TUlid.Init;
begin
  FXorShift64 := TXorShift64.Create(Random64);
end;


class function TUlid.InternalNewUlid(timestamp: UInt64): TUlid;
var
  random : UInt64;
  ts : Int64Rec absolute timestamp;
begin
  //reverse order!
  result.FTimeStamp0 := ts.Bytes[5];
  result.FTimeStamp1 := ts.Bytes[4];
  result.FTimeStamp2 := ts.Bytes[3];
  result.FTimeStamp3 := ts.Bytes[2];
  result.FTimeStamp4 := ts.Bytes[1];
  result.FTimeStamp5 := ts.Bytes[0];

  random := FXorShift64.Next;
  PNativeUInt(@result.FRandomness0)^ := NativeUInt(random); // only using 0-1 but faster to just overflow here
  random := FXorShift64.Next;
  PUInt64(@result.FRandomness2)^ := random; // 2-9

end;


class function TUlid.InternalNewUlidFromBytes(const base32bytes : PByte): TUlid;
begin
  result.FTimestamp0 := byte((CharToBase32[base32bytes[0]] shl 5) or CharToBase32[base32bytes[1]]);
  result.FTimestamp1 := byte((CharToBase32[base32bytes[2]] shl 3) or (CharToBase32[base32bytes[3]] shr 2));
  result.FTimestamp2 := byte((CharToBase32[base32bytes[3]] shl 6) or (CharToBase32[base32bytes[4]] shl 1) or (CharToBase32[base32bytes[5]] shr 4));
  result.FTimestamp3 := byte((CharToBase32[base32bytes[5]] shl 4) or (CharToBase32[base32bytes[6]] shr 1));
  result.FTimestamp4 := byte((CharToBase32[base32bytes[6]] shl 7) or (CharToBase32[base32bytes[7]] shl 2) or (CharToBase32[base32bytes[8]] shr 3));
  result.FTimestamp5 := byte((CharToBase32[base32bytes[8]] shl 5) or CharToBase32[base32bytes[9]]);

  result.FRandomness0 := byte((CharToBase32[base32bytes[10]] shl 3) or (CharToBase32[base32bytes[11]] shr 2));
  result.FRandomness1 := byte((CharToBase32[base32bytes[11]] shl 6) or (CharToBase32[base32bytes[12]] shl 1) or (CharToBase32[base32bytes[13]] shr 4));
  result.FRandomness2 := byte((CharToBase32[base32bytes[13]] shl 4) or (CharToBase32[base32bytes[14]] shr 1));
  result.FRandomness3 := byte((CharToBase32[base32bytes[14]] shl 7) or (CharToBase32[base32bytes[15]] shl 2) or (CharToBase32[base32bytes[16]] shr 3));
  result.FRandomness4 := byte((CharToBase32[base32bytes[16]] shl 5) or CharToBase32[base32bytes[17]]);
  result.FRandomness5 := byte((CharToBase32[base32bytes[18]] shl 3) or (CharToBase32[base32bytes[19]] shr 2));
  result.FRandomness6 := byte((CharToBase32[base32bytes[19]] shl 6) or (CharToBase32[base32bytes[20]] shl 1) or (CharToBase32[base32bytes[21]] shr 4));
  result.FRandomness7 := byte((CharToBase32[base32bytes[21]] shl 4) or (CharToBase32[base32bytes[22]] shr 1));
  result.FRandomness8 := byte((CharToBase32[base32bytes[22]] shl 7) or (CharToBase32[base32bytes[23]] shl 2) or (CharToBase32[base32bytes[24]] shr 3));
  result.FRandomness9 := byte((CharToBase32[base32bytes[24]] shl 5) or CharToBase32[base32bytes[25]]);

end;

function TUlid.IsEmpty: boolean;
var
  e : TUlid;
begin
  e := TUlid.Empty;
  result := Self.Equals(e);
end;

class function TUlid.Parse(const base32Str: AnsiString): TUlId;
begin
  CheckString(base32Str);
  result := TUlid.InternalNewUlidFromBytes(Pointer(base32Str))
end;


{$IFDEF MSWINDOWS}
function UNIXTimeInMilliseconds: UInt64;inline;
const
  TimeOffset = 116444736000000000;
var
  ft: TFileTime;
begin
  GetSystemTimeAsFileTime(ft);
  result := (UInt64(ft) - UInt64(TimeOffset)) div 10000;
end;
{$ELSE}
//TODO : find an implementation of this for non windows platforms in earlier versions
// NowUtc only available in 11.3 or later.
// this is slow.
function UNIXTimeInMilliseconds: UInt64;inline;
  DT: TDateTime;
begin
  DT := TDateTime.NowUTC;
  Result := MilliSecondsBetween(DT, UnixDateDelta);
end;
{$ENDIF}



class procedure TUlid.CheckString(const base32Str: string);
begin
  if (Length(base32Str) <> cBase32StringLen) then
    raise EArgumentException.Create('Invalid base32 string length, length:' + IntToStr(Length(base32Str)) + ' - expected :' + IntToStr(cBase32StringLen));
end;

class procedure TUlid.CheckString(const base32Str: AnsiString);
label
  InvalidChar, InvalidLength;
var
  i : nativeint;
  b : byte;
begin
  if (Length(base32Str) <> cBase32StringLen) then goto InvalidLength;

  //we can do this here since we don't need to convert it.
  for i := 1 to cBase32StringLen do
  begin
    b := Ord(base32Str[i]);
    if ((b < 48) or ((b > 57) and (b < 65)) or (b > 90)) then goto InvalidChar;
  end;
  Exit;
InvalidChar:
  raise EArgumentException.Create('Invalid chars in base 32 string');
InvalidLength:
  raise EArgumentException.Create('Invalid base32 string length, length:' + IntToStr(Length(base32Str)) + ' - expected :' + IntToStr(cBase32StringLen));
end;


class function TUlid.Create : TUlid;
var
  timeStamp : UInt64;
begin
  timeStamp :=  UNIXTimeInMilliseconds;
  result := TUlid.InternalNewUlid(timestamp);
end;


class function TUlid.Parse(const base32Str : string): TUlId;
label
  InvalidChar;
var
  buffer : array[1..26] of byte;
  c : Char;
  w : Word;
  i : NativeInt;
begin
  TUlid.CheckString(base32Str);

  //hacky way to avoid using TEncoding.GetBytes which is slow!
  for i := 1 to 26 do
  begin
    c := base32Str[i];
    w := Ord(c);
    //        0           9             A            Z
    if ((w < 48) or ((w > 57) and (w < 65)) or (w > 90)) then goto InvalidChar;
    buffer[i] := w;
  end;

  result := TUlid.InternalNewUlidFromBytes(@buffer[1]);
  Exit;
InvalidChar:
  raise EArgumentException.Create('Invalid chars in base 32 string');
end;


initialization
  System.Randomize;
end.
