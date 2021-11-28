module zthor.filetable;

import zgrf.compression;
import zthor.constants;
import zthor.exception;
import zthor.types;

void fill(ref THOR thor, ref THORFiletable files, const(wstring)[] filters = [])
in (thor.filehandle.isOpen(), "Filehandle must be open to read the filetable")
in (thor.filesize > thor.header.filetableOffset, "THOR filesize < Filetable offset")
{
    import core.stdc.stdio : SEEK_SET;
    import std.exception : enforce;
    import std.format : format;
    import std.string : toLower;
    import std.zlib : crc32;

    thor.filehandle.seek(thor.header.filetableOffset, SEEK_SET);

    ubyte[] zbuffer = new ubyte[thor.header.filetableCompressedSize];

    auto actualRead = thor.filehandle.rawRead(zbuffer);

    enforce!ThorException(actualRead.length == thor.header.filetableCompressedSize,
            format("Read compressed filetable size (%d bytes) differs from header (%d bytes)",
                actualRead.length, thor.header.filetableCompressedSize));

    ubyte[] buffer = uncompress(zbuffer);

    ulong offset = 0;

    if (filters.length > 0)
    {
        foreach (i; 0 .. thor.header.filecount)
        {
            THORFile file = extractFile(buffer, offset);
            file.thor = &thor;
            if (inFilter(file, filters))
            {
                file.hash = crc32(0, file.name.toLower);
                files.require(file.hash, file);
            }
        }
    }
    else
    {
        foreach (i; 0 .. thor.header.filecount)
        {
            THORFile file = extractFile(buffer, offset);
            file.thor = &thor;
            file.hash = crc32(0, file.name.toLower);
            files.require(file.hash, file);
        }
    }
}

void fillSingleFile(ref THOR thor, ref THORFiletable files, const(wstring)[] filters = [])
in (thor.filehandle.isOpen(), "Filehandle must be open to read the filetable")
in (thor.filesize > cast(ushort) thor.header.containerMode, "THOR filesize < Header size")
{
    import core.stdc.stdio : SEEK_SET;
    import std.bitmanip : read;
    import std.string : toLower;
    import std.system : Endian;
    import std.zlib : crc32;

    thor.filehandle.seek(cast(ushort) thor.header.containerMode, SEEK_SET);

    THORFile file;

    auto buffer = thor.filehandle.rawRead(new ubyte[4]);
    file.compressed_size = read!(uint, Endian.littleEndian)(buffer);
    buffer = thor.filehandle.rawRead(new ubyte[4]);
    file.size = read!(uint, Endian.littleEndian)(buffer);

    const filenameLen = thor.filehandle.rawRead(new ubyte[1])[0];

    if (filenameLen > 0)
    {
        file.rawName = new ubyte[filenameLen];
        thor.filehandle.rawRead(file.rawName);

        import zencoding.windows949 : fromWindows949;

        file.name = fromWindows949(file.rawName);
    }

    file.offset = cast(uint) thor.filehandle.tell();

    if (filters.length > 0 && inFilter(file, filters))
    {
        file.thor = &thor;
        file.hash = crc32(0, file.name.toLower);
        files.require(file.hash, file);
    }
    else if (filters.length == 0)
    {
        file.thor = &thor;
        file.hash = crc32(0, file.name.toLower);
        files.require(file.hash, file);
    }
}

private THORFile extractFile(ref ubyte[] buffer, ref ulong offset)
{
    THORFile file;

    const filenameLen = buffer[offset];
    offset += 1;

    if (filenameLen > 0)
    {
        file.rawName = buffer[offset .. (offset + filenameLen)].dup;
        offset += filenameLen;

        import zencoding.windows949 : fromWindows949;

        file.name = fromWindows949(file.rawName);
    }

    import std.conv : to;
    import zthor.constants : FileFlags;

    file.flags = buffer[offset].to!FileFlags;
    offset += 1;

    if (file.flags != FileFlags.remove)
    {
        import std.system : Endian;
        import std.bitmanip : peek;

        file.offset = buffer.peek!(uint, Endian.littleEndian)(&offset);
        file.compressed_size = buffer.peek!(uint, Endian.littleEndian)(&offset);
        file.size = buffer.peek!(uint, Endian.littleEndian)(&offset);
    }

    return file;
}

/**
 * Checks if a given [THORFile] matches one of our filters.
 *
 * The check performs a case insensitive glob match.
 *
 * Params:
 *  file = The file to check
 *  filterList = The array of filters to check against
 *
 * Returns:
 *  Whether the file matches one of the provided filters
 */
bool inFilter(in ref THORFile file, in ref const(wstring)[] filterList)
{
    if (filterList.length == 0)
    {
        return true;
    }

    foreach (const filterString; filterList)
    {
        import std.path : globMatch, CaseSensitive;

        if (globMatch!(CaseSensitive.no)(file.name, filterString))
        {
            return true;
        }
    }
    return false;
}

