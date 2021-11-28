# zthor

Library to interact with Aeomin's THOR patchers file format.

## Documentation
The documentation can be found here: https://zthor.dpldocs.info

## Building
### Requirements
- DMD, LDC or GDC

Additionally in order to compile the LZMA library a c compiler is required.
For linux that would be
- gcc

and for Windows
- msvc

To obtain msvc on Windows you will need the [Build Tools for Visual Studio](https://visualstudio.microsoft.com/de/downloads/#build-tools-for-visual-studio-2019).

### Compiling
#### Linux
If everything is present simply run  
`dub build`

#### Windows
From within the Developer Console that will be available after installing the Build Tools  
run `dub build`

## Example
Extract all files in a grf/gpf
```d
import zthor;

THOR thor = THOR("patch.thor");

scope(exit)
    thor.close();

thor.parse(["data\\wav\\*"]);

import std.stdio : writefln;

// Let's extract all files
ulong fileindex = 0;
ulong filecount = thor.files.length;
foreach (ref THORFile file; thor.files)
{
    import std.path : dirName;

    // Filenames are stored with Windows paths
    version(Posix)
    {
        import std.array : replace;
        wstring fullpath = file.name.replace("\\"w, "/"w);
        wstring path = dirName(fullpath);
    }
    else
    {
        // Windows, no need to change anything
        wstring fullpath = file.name;
        wstring path = dirName(file.name);
    }

    // Print some progress
    writefln("Extracting (%d/%d): %s", fileindex + 1, filecount, fullpath);

    import std.file : mkdirRecurse;
    import std.utf : toUTF8;

    mkdirRecurse("output/" ~ path.toUTF8);

    // Decompress file data
    const data = file.getFileData();

    import std.stdio : File;

    auto fout = File("output/" ~ fullpath, "w+");
    fout.rawWrite(data);
    fout.close();

    fileindex++;
}
}
```
