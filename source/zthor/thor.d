module zthor.thor;

import std.stdio : File;
import std.typecons : Flag, No;
import zthor.constants;
import zthor.exception;
import zthor.types;

/**
 * Open the internal filehandle of the THOR struct.
 *
 * Uses std.stdio.File.reopen()
 *
 * Params:
 *   thor = The THOR to open the filehandle for
 *
 * Throws: ErrnoException in case of error
 */
void open(ref THOR thor)
in (!thor.filehandle.isOpen(), "Filehandle is already open")
{
    thor.filehandle.reopen(thor.filename, "rb");
}

/**
 * Close the internal file handle of the THOR struct.
 *
 * Params:
 *  thor = The THOR to close the filehandle for
 *
 * Throws: ErrnoException in case of error
 */
void close(ref THOR thor)
{
    thor.filehandle.close();
}

/**
 * Parses the header of the given THOR
 *
 * Format description: https://z0q.neocities.org/ragnarok-online-formats/thor/
 *
 * Params:
 *   thor = The THOR struct to parse the header for
 *
 * Returns:
 *   Input thor for easy chaining
 *
 * Throws:
 *   ThorException if parsing fails due to wrong format. Exception or
 *   ErrnoException in case of file operation failure.
 */
ref THOR readHeader(return ref THOR thor)
in (thor.filehandle.isOpen(), "Filehandle of the THOR struct must be open " ~
        "to read the header")
{
    if (thor.header.ver > 0)
    {
        // Check if the header has been parsed already
        // and prevent doing it again
        return thor;
    }
    import core.stdc.stdio : SEEK_SET;

    thor.filehandle.seek(0, SEEK_SET);

    import zthor.constants : MIN_HEADER_LEN, MAX_HEADER_LEN;

    ubyte[MAX_HEADER_LEN] buffer;
    auto actualRead = thor.filehandle.rawRead(buffer);

    if (actualRead.length < MIN_HEADER_LEN)
    {
        import std.format : format;

        throw new ThorException(format("THOR's filesize is too small to be valid. " ~
                    "Expected the filesize to be at least %d bytes large but was actually " ~
                    "%d bytes large.", MIN_HEADER_LEN, actualRead.length));
    }

    thor.header.ver = 0x01;

    import std.bitmanip : littleEndianToNative;
    import std.exception : collectException, enforce;
    import std.conv : ConvException, to;

    thor.header.signature = buffer[0 .. 24];

    Exception err = collectException!ConvException(buffer[24].to!MergeMode,
            thor.header.mergeMode);
    enforce!ThorException(!err, err.msg);

    thor.header.filecount = littleEndianToNative!uint(buffer[25 .. 29]);

    import std.stdio : writeln;
    writeln((littleEndianToNative!ushort(buffer[29 .. 31])).to!ContainerMode);

    err = collectException!ConvException((littleEndianToNative!ushort(buffer[29 .. 31])).to!ContainerMode,
            thor.header.containerMode);
    enforce!ThorException(!err, err.msg);

    import std.string : assumeUTF;
    import std.encoding : transcode, Latin1String;

    ubyte grfTargetNameLength = buffer[31];
    size_t idx = 32;

    if (grfTargetNameLength > 0)
    {
        (cast(Latin1String) buffer[idx .. (idx + grfTargetNameLength)]).transcode(thor.header.grfTargetName);
        idx += grfTargetNameLength;
    }

    if (thor.header.containerMode == ContainerMode.multiple)
    {
        ubyte[8] slice = buffer[idx .. (idx + 8)];
        thor.header.filetableCompressedSize = littleEndianToNative!int(slice[0 .. 4]);
        thor.header.filetableOffset = littleEndianToNative!int(slice[4 .. 8]);
        idx += 8;
    } else if (thor.header.containerMode == ContainerMode.single)
    {
        thor.header.filetableCompressedSize = 0;
        thor.header.filetableOffset = 0;
    }

    return thor;
}

/**
 * Parses the filetable of the given THOR.
 * If filters is provided then only the files which
 * matches the filters will be loaded.
 *
 * Params:
 *  thor = The THOR to read the filetable from
 *  filters = Array of filters
 *
 * Returns:
 *  Input thor for easy chaining
 */
ref THOR readFiletable(return ref THOR thor, const(wstring)[] filters = [])
{
    if (thor.header.containerMode == ContainerMode.multiple)
    {
        import zthor.filetable : fill;

        fill(thor, thor.files, filters);
    }
    else if (thor.header.containerMode == ContainerMode.single)
    {
        import zthor.filetable : fillSingleFile;

        fillSingleFile(thor, thor.files, filters);
    }

    return thor;
}

/**
 * Parses a THOR file given optional filters.
 *
 * Calls [readHeader] and [readFiletable] on the input THOR.
 *
 * Params:
 *  thor = The THOR file to parse
 *  filters = The filters to use when parsing the filetable
 *
 * Returns:
 *  Input thor for easy chaining
 */
ref THOR parse(return ref THOR thor, const(wstring)[] filters = [])
{
    return thor.readHeader().readFiletable(filters);
}

/**
 * Get the uncompressed data of a file inside the input THOR.
 *
 * This function will allocate new memory and always call the
 * uncompressing routines _unless_ cache is set to true.
 *
 * Params:
 *  thor = The THOR to read the file from
 *  file = The metadata about the file to be read
 *  thorHandle = Use this file handle instead of the one from thor
 *  useCache = Return the data from cache if it exists
 *
 * Returns:
 *  The unencrypted and uncompressed file data
 */
ubyte[] getFileData(ref THOR thor, ref THORFile file, File thorHandle,
        Flag!"useCache" useCache = No.useCache)
{
    if (file.flags == FileFlags.remove || file.compressed_size == 0 || file.size == 0)
    {
        return [];
    }
    if (useCache && file.data != file.data.init)
    {
        return file.data;
    }

    import core.stdc.stdio : SEEK_SET;

    thorHandle.seek(file.offset, SEEK_SET);

    scope ubyte[] compressedData = new ubyte[file.compressed_size];
    thorHandle.rawRead(compressedData);

    import zgrf.compression : uncompress;

    if (useCache)
    {
        file.data = uncompress(compressedData, file.size);
        return file.data;
    }

    return uncompress(compressedData, file.size);
}


/**
 * Get the uncompressed data of a file inside the input THOR.
 *
 * This function will always allocate new memory and always call the
 * uncompressing routines.
 *
 * Params:
 *  thor = The THOR to read the file from
 *  file = The metadata about the file to be read
 *  useCache = Return the data from cache if it exists
 *
 * Returns:
 *  The uncompressed file data
 */
ubyte[] getFileData(ref THOR thor, ref THORFile file, Flag!"useCache" useCache = No.useCache)
{
    return getFileData(thor, file, thor.filehandle, useCache);
}

/// ditto
ubyte[] getFileData(ref THORFile file, Flag!"useCache" useCache = No.useCache)
{
    if (file.thor is null)
    {
        return [];
    }

    return getFileData(*file.thor, file, useCache);
}

/// ditto
ubyte[] getFileData(ref THOR thor, const wstring filename, Flag!"useCache" useCache = No.useCache)
{
    import std.zlib : crc32;

    const uint hash = crc32(0, filename);
    if (hash in thor.files)
    {
        return getFileData(thor, thor.files[hash], useCache);
    }
    else
    {
        return [];
    }
}
