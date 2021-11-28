module zthor.constants;

/// The minimum required header size. Any filesize less than this and the THOR is invalid.
enum uint MIN_HEADER_LEN = 33;
/**
 * The maximum possible header length. Including the max allowed
 * grfTargetName of 255.
 */
enum uint MAX_HEADER_LEN = MIN_HEADER_LEN + 4 + 3 + 0xFF;

/**
  Defines where the files from the THOR container should
  be saved to/merged with.
*/
enum MergeMode : ubyte
{
    /// Saved to the filesystem (e.g. data directory)
    filesystem,
    /**
      Saved to the GRF file directly. Which GRF is defined
      in the headers `grfTargetName` member variable
    */
    grf
}

/// Defines the way files are stored inside the THOR container.
enum ContainerMode : ushort
{
    /// The THOR container contains only a single file
    single = 0x21,
    /// The THOR container contains multiple files.
    multiple = 0x30
}

/// File specific flags
enum FileFlags : ubyte
{
    /// Normal file that will be saved/merged
    normal = 0x0,
    /// File should be removed
    remove = 0x1
}
