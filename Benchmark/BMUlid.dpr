program BMUlid;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Spring.Benchmark,
  VSoft.Ulid in '..\Source\VSoft.Ulid.pas';

procedure BM_Create(const state: TState);
begin
  // Perform setup here
  for var _ in state do
  begin
    // This code gets timed
    var ulid := TUlid.Create;
  end;
end;

procedure BM_ToString(const state: TState);
begin
  var ulid := TUlid.Create;
  // Perform setup here
  for var _ in state do
  begin
    // This code gets timed
    var s := ulid.ToString;
  end;
end;


procedure BM_ParseAnsi(const state: TState);
var
  s : AnsiString;
begin
  // Perform setup here
  s := '01J4JC3MY6S461H3P96FB4QAGS';
  for var _ in state do
  begin
    // This code gets timed
    var ulid := TUlid.Parse(s);
  end;
end;

procedure BM_Parse(const state: TState);
var
  s : string;
begin
  // Perform setup here
  s := '01J4JC3MY6S461H3P96FB4QAGS';
  for var _ in state do
  begin
    // This code gets timed
    var ulid := TUlid.Parse(s);
  end;
end;


begin

  // Register the function as a benchmark
  Benchmark(BM_Create, 'TUlid.Create');
  Benchmark(BM_ParseAnsi, 'TUlid.Parse - AnsiString');
  Benchmark(BM_Parse, 'TUlid.Parse');
  Benchmark(BM_ToString, 'TUlid.ToString');
  // Run the benchmark
  Benchmark_Main;
  Readln;
end.
