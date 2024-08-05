# VSoft.Ulid

A Delphi Implementation of [ULID](https://github.com/ulid/spec) for Delphi XE2 or later.

- 128-bit compatibility with UUID
- Lexicographically sortable!
- Canonically encoded as a 26 character string, as opposed to the 36 character UUID
- Uses Crockford's base32 for better efficiency and readability (5 bits per character)
- Case insensitive
- No special characters (URL safe)
- Monotonic sort order (correctly detects and handles the same millisecond)

## Installation

### DPM

Install VSoft.Ulid in the DPM IDE plugin,  or 
```
dpm install VSoft.Ulid .\yourproject.dproj
```
### Manually
Clone the repository and add the VSoft.Ulid.pas file to your project, or add the repo\Source folder to your project's search path.

## Usage

```
var
  ulid : TUlid;
  s : string;
begin
  ulid := TUlid.Create;
  s := ulid.ToString;
  
  .....
  ulid := TUlid.Parse('01J4H739Z46PZEFF5F6X5Q338Z');
  writeln(ulid.ToString);
end;
```
