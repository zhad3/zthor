module zthor.types;

import zthor.constants;

/// Holds information that is present in all THOR files.
struct THORHeader
{
    /// "ASSF (C) 2007 Aeomin DEV"
    ubyte[24] signature;

    /**
     * Version, will always be 0x01 because the THOR format
     * doesn't actually store any versioning
     */
    uint ver;

    /**
     * Defines where the files from the THOR container should
     * be saved to/merged with.
     */
    MergeMode mergeMode;

    /// The number of files in the THOR container.
    uint filecount;

    /**
     * Defines the way files are stored inside the THOR container.
     * Important: This also defines the header size!
     */
    ContainerMode containerMode;

    /**
     * Contains the name of the grf file to write to/merge with
     * if the mergeMode is `MergeMode.grf`
    */
    string grfTargetName;

    /**
     * The offset of the filetable. Value is 0 if `containerMode`
     * is `ContainerMode.single`.
     */
    int filetableOffset;

    /**
     * The compressed size of the filetable. Value is 0 if `containerMode`
     * is `ContainerMode.single`.
     */
    int filetableCompressedSize;
}

/// Holds information about a single file inside a THOR container
struct THORFile
{
    /// Compressed filesize using zlib
    uint compressed_size;

    /// Uncompressed size
    uint size;

    /// Absolute offset of the file
    uint offset;

    /// Hash of the filename
    uint hash;

    /// File specific flags
    FileFlags flags;

    /// Filename
    wstring name;

    /// The raw filename as it is stored inside the file
    ubyte[] rawName;

    /// Data content
    ubyte[] data;

    /// The THOR container this file is saved in
    THOR* thor;
}

/// Hashmap of files inside a THOR container
alias THORFiletable = THORFile[uint];

/**
 * Holds information about a THOR file.
 *
 *  Examples:
 * ------
 * import zthor.types;
 *
 * THOR thor = THOR("my-patch.thor");
 * ------
 */
struct THOR
{
    import std.stdio : File;

    /// Filehandle that is used to read any data from
    File filehandle;

    /// Filename of the THOR file
    string filename;

    /// Filesize of the THOR file
    size_t filesize;

    /// THOR header. Will be filled once [zthor.thor.readHeader] is called.
    THORHeader header;

    /// Associative array of the files.
    /// Will be filled once [zthor.thor.readFiletable] is called.
    THORFiletable files;

    /**
     * Opens the filehandle and stores the filesize
     *
     * Params:
     *  name = Filename of the THOR file
     *
     * Throws:
     *   Exception if name is null or ErrnoException in case of
     *   file operation failure.
     */
    this(string name)
    {
        filename = name;
        filehandle = File(filename, "rb");
        import core.stdc.stdio : SEEK_SET, SEEK_END;

        filehandle.seek(0, SEEK_END);
        filesize = filehandle.tell();
        filehandle.seek(0, SEEK_SET);
    }
}

