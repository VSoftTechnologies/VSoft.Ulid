unit VSoft.Ulid;


interface

uses
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

    // Randomness(80bits)
//    FRandomness : array[0..9] of byte;

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
    class function InternalNewUlid(timestamp : UInt64) : TUlid;static;
    class function InternalNewUlidFromBytes(base32bytes : TBytes) : TUlid;static;
    class constructor Init;
  public
	  class function TryParse(const base32Str : string; out ulid : TUlId) : boolean;static;
    class function Parse(const base32Str : string) : TUlId;static;
	  class function Create : TUlid;static;
    class function Empty : TUlid;static;
    class function FromGuid(value : TGuid) : TUlid;static;
  	function ToString : string;
    function Equals(value : TUlId) : boolean;
    function IsEmpty : boolean;
  end;

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

  base32StringLen  = 26;

type //not available in XE2
    Int64Rec = packed record
    case Integer of
      0: (Lo, Hi: Cardinal);
      1: (Cardinals: array [0..1] of Cardinal);
      2: (Words: array [0..3] of Word);
      3: (Bytes: array [0..7] of Byte);
  end;


function Random64: UInt64;
var
  Overlay: Int64Rec absolute Result;
begin
  Assert(SizeOf(Overlay)=SizeOf(Result));
  Overlay.Lo := Random(MaxInt);
  Overlay.Hi := Random(MaxInt);
end;

function TUlid.ToString : string;
begin
  SetLength(result, base32StringLen);

  // timestamp
  result[1] := Base32Text[(FTimestamp0 and 224) shr 5];
  result[2] := Base32Text[FTimestamp0 and 31];
  result[3] := Base32Text[(FTimestamp1 and 248) shr 3];
  result[4] := Base32Text[((FTimestamp1 and 7) shl 2) or ((FTimestamp2 and 192) shr 6)];
  result[5] := Base32Text[(FTimestamp2 and 62) shr 1];
  result[6] := Base32Text[((FTimestamp2 and 1) shl 4) or ((FTimestamp3 and 240) shr 4)];
  result[7] := Base32Text[((FTimestamp3 and 15) shl 1) or ((FTimestamp4 and 128) shr 7)];
  result[8] := Base32Text[(FTimestamp4 and 124) shr 2];
  result[9] := Base32Text[((FTimestamp4 and 3) shl 3) or ((FTimestamp5 and 224) shr 5)];
  result[10] := Base32Text[FTimestamp5 and 31];

  // FRandomness
  result[11] := Base32Text[(FRandomness0 and 248) shr 3];
  result[12] := Base32Text[((FRandomness0 and 7) shl 2) or ((FRandomness1 and 192) shr 6)];
  result[13] := Base32Text[(FRandomness1 and 62) shr 1];
  result[14] := Base32Text[((FRandomness1 and 1) shl 4) or ((FRandomness2 and 240) shr 4)];
  result[15] := Base32Text[((FRandomness2 and 15) shl 1) or ((FRandomness3 and 128) shr 7)];
  result[16] := Base32Text[(FRandomness3 and 124) shr 2];
  result[17] := Base32Text[((FRandomness3 and 3) shl 3) or ((FRandomness4 and 224) shr 5)];
  result[18] := Base32Text[FRandomness4 and 31];
  result[19] := Base32Text[(FRandomness5 and 248) shr 3];
  result[20] := Base32Text[((FRandomness5 and 7) shl 2) or ((FRandomness6 and 192) shr 6)];
  result[21] := Base32Text[(FRandomness6 and 62) shr 1];
  result[22] := Base32Text[((FRandomness6 and 1) shl 4) or ((FRandomness7 and 240) shr 4)];
  result[23] := Base32Text[((FRandomness7 and 15) shl 1) or ((FRandomness8 and 128) shr 7)];
  result[24] := Base32Text[(FRandomness8 and 124) shr 2];
  result[25] := Base32Text[((FRandomness8 and 3) shl 3) or ((FRandomness9 and 224) shr 5)];
  result[26] := Base32Text[FRandomness9 and 31];


end;

class function TUlid.TryParse(const base32Str : string; out ulid : TUlId) : boolean;
begin
  if (Length(base32Str) <> base32StringLen) then
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
  ZeroMemory(@result.FTimeStamp0, SizeOf(TUlId)); //not strictly needed;
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
  result := default(TUlId);
  //reverse order!
  result.FTimeStamp0 := ts.Bytes[5];
  result.FTimeStamp1 := ts.Bytes[4];
  result.FTimeStamp2 := ts.Bytes[3];
  result.FTimeStamp3 := ts.Bytes[2];
  result.FTimeStamp4 := ts.Bytes[1];
  result.FTimeStamp5 := ts.Bytes[0];
  random := FXorShift64.Next;
  Move(random,result.FRandomness0, 2); // randomness 0-1
  random := FXorShift64.Next;
  Move(random,result.FRandomness2, 8); // randomness 2-9
end;


class function TUlid.InternalNewUlidFromBytes(base32bytes : TBytes): TUlid;
begin
  result := default(TUlId);

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

//borrowed from 12.1
function NowUTC: TDateTime;
{$IFDEF MSWINDOWS}
var
  SystemTime: TSystemTime;
begin
  GetSystemTime(SystemTime);
  Result := EncodeDate(SystemTime.wYear, SystemTime.wMonth, SystemTime.wDay) +
    EncodeTime(SystemTime.wHour, SystemTime.wMinute, SystemTime.wSecond, SystemTime.wMilliseconds);
end;
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
var
  T: time_t;
  TV: timeval;
  UT: tm;
begin
  gettimeofday(TV, nil);
  T := TV.tv_sec;
  gmtime_r(T, UT);
  Result := EncodeDate(UT.tm_year + 1900, UT.tm_mon + 1, UT.tm_mday) +
    EncodeTime(UT.tm_hour, UT.tm_min, UT.tm_sec, TV.tv_usec div 1000);
end;
{$ENDIF POSIX}

function UNIXTimeInMilliseconds: Int64;
var
  DT: TDateTime;
begin
  DT := NowUTC;
  Result := MilliSecondsBetween(DT, UnixDateDelta);
end;

class function TUlid.Create : TUlid;
var
  timeStamp : UInt64;
begin
  timeStamp :=  UNIXTimeInMilliseconds;
  result := TUlid.InternalNewUlid(timestamp);
end;


class function TUlid.Parse(const base32Str : string): TUlId;
var
  base32bytes : TBytes;
begin
  if (Length(base32Str) <> base32StringLen) then
    raise EArgumentException.Create('Invalid base32 string length, length:' + IntToStr(Length(base32Str)) + ' - expected :' + IntToStr(base32StringLen));

  base32bytes := TEncoding.UTF8.GetBytes(base32Str);
  result := TUlid.InternalNewUlidFromBytes(base32bytes)
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

function TXorShift64.Next: UInt64;
begin
  Fx := FX xor (Fx shl 7);
  Fx := Fx xor (Fx shr 9);
  result := Fx;
end;


initialization
  System.Randomize;
end.
