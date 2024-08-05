program BMUlid;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Spring.Benchmark,
  VSoft.Ulid;

procedure BM_Create(const state: TState);
begin
  // Perform setup here
  for var _ in state do
  begin
    // This code gets timed
    var ulid := TUlid.Create;
  end;
end;

procedure BM_Parse(const state: TState);
begin
  // Perform setup here
  for var _ in state do
  begin
    // This code gets timed
    var ulid := TUlid.Parse('01J4JC3MY6S461H3P96FB4QAGS');
  end;
end;


begin

  // Register the function as a benchmark
  Benchmark(BM_Create, 'TUlid.Create');
  Benchmark(BM_Parse, 'TUlid.Parse');
  // Run the benchmark
  Benchmark_Main;
  Readln;
end.
