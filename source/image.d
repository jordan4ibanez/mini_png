module image;

import std.stdio;

public import color;
public import png;

import core.memory;

static if (__traits(compiles, { import iv.vfs; }))
    enum ArsdImageHasIVVFS = true;
else
    enum ArsdImageHasIVVFS = false;

private bool strEquCI(const(char)[] s0, const(char)[] s1) pure nothrow @trusted @nogc {
    if (s0.length != s1.length)
        return false;
    foreach (immutable idx, char ch; s0) {
        if (ch >= 'A' && ch <= 'Z')
            ch += 32; // poor man's tolower()
        char c1 = s1.ptr[idx];
        if (c1 >= 'A' && c1 <= 'Z')
            c1 += 32; // poor man's tolower()
        if (ch != c1)
            return false;
    }
    return true;
}

/// Image formats `arsd.image` can load (except `Unknown`, of course).
enum ImageFileFormat {
    Unknown, ///
    Png, ///
}

/// Try to guess image format from file extension.
public ImageFileFormat guessImageFormatFromExtension(const(char)[] filename) {
    if (filename.length < 2)
        return ImageFileFormat.Unknown;
    size_t extpos = filename.length;
    version (Windows) {
        while (extpos > 0 && filename.ptr[extpos - 1] != '.' && filename.ptr[extpos - 1] != '/' && filename
            .ptr[extpos - 1] != '\\' && filename.ptr[extpos - 1] != ':')
            --extpos;
    } else {
        while (extpos > 0 && filename.ptr[extpos - 1] != '.' && filename.ptr[extpos - 1] != '/')
            --extpos;
    }
    if (extpos == 0 || filename.ptr[extpos - 1] != '.')
        return ImageFileFormat.Unknown;
    auto ext = filename[extpos .. $];
    if (strEquCI(ext, "png"))
        return ImageFileFormat.Png;
    return ImageFileFormat.Unknown;
}

/// Try to guess image format by first data bytes.
public ImageFileFormat guessImageFormatFromMemory(const(void)[] membuf) {
    auto buf = cast(const(ubyte)[]) membuf;
    if (buf.length == 0)
        return ImageFileFormat.Unknown;
    // detect file format
    // png
    if (buf.length > 7 && buf.ptr[0] == 0x89 && buf.ptr[1] == 0x50 && buf.ptr[2] == 0x4E &&
        buf.ptr[3] == 0x47 && buf.ptr[4] == 0x0D && buf.ptr[5] == 0x0A && buf.ptr[6] == 0x1A) {
        return ImageFileFormat.Png;
    }
    // dunno
    return ImageFileFormat.Unknown;
}

/// Try to guess image format from file name and load that image.
public MemoryImage loadImageFromFile(T : const(char)[])(T filename) {
    static if (is(T == typeof(null))) {
        throw new Exception("cannot load image from unnamed file");
    } else {
        final switch (guessImageFormatFromExtension(filename)) {
        case ImageFileFormat.Unknown:

            static if (is(T == string)) {
                auto fl = File(filename);
            } else {
                auto fl = File(filename.idup);
            }

            auto fsz = fl.size - fl.tell;
            if (fsz < 4)
                throw new Exception("cannot determine file format");
            if (fsz > int.max / 8)
                throw new Exception("image data too big");
            auto data = new ubyte[](cast(uint) fsz);
            scope (exit) {
                import core.memory : GC;

                GC.free(data.ptr);
            } // this should be safe, as image will copy data to it's internal storage
            fl.rawReadExact(data);
            return loadImageFromMemory(data);
        case ImageFileFormat.Png:
            static if (is(T == string))
                return readPng(filename);
            else
                return readPng(filename.idup);
        }
    }
}

/// Try to guess image format from data and load that image.
public MemoryImage loadImageFromMemory(const(void)[] membuf) {
    final switch (guessImageFormatFromMemory(membuf)) {
    case ImageFileFormat.Unknown:
        throw new Exception("cannot determine file format");
    case ImageFileFormat.Png:
        return imageFromPng(readPng(cast(const(ubyte)[]) membuf));
    }
}
