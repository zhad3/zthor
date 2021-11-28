unittest
{
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
        writefln("Name: %s, flags: %s, compressed_size: %u, size: %u", file.name, file.flags, file.compressed_size, file.size);
    }
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

        // Unencrypt und decompress file data
        const data = file.getFileData();

        import std.stdio : File;

        auto fout = File("output/" ~ fullpath, "w+");
        fout.rawWrite(data);
        fout.close();

        fileindex++;
    }
}
