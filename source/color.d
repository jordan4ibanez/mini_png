module color;

@safe:
private {
    double toInternal(T)(scope const(char)[] s) {
        double accumulator = 0.0;
        size_t i = s.length;
        foreach (idx, c; s) {
            if (c >= '0' && c <= '9') {
                accumulator *= 10;
                accumulator += c - '0';
            } else if (c == '.') {
                i = idx + 1;
                break;
            } else {
                string thrower = "bad char to make double from ";
                thrower ~= s;
                throw new Exception(thrower);
            }
        }

        double accumulator2 = 0.0;
        double count = 1;
        foreach (c; s[i .. $]) {
            if (c >= '0' && c <= '9') {
                accumulator2 *= 10;
                accumulator2 += c - '0';
                count *= 10;
            } else {
                string thrower = "bad char to make double from ";
                thrower ~= s;
                throw new Exception(thrower);
            }
        }

        return accumulator + accumulator2 / count;
    }

    @trusted
    string toInternal(T)(long a) {
        if (a == 0)
            return "0";
        char[] ret;
        bool neg;
        if (a < 0) {
            neg = true;
            a = -a;
        }
        while (a) {
            ret ~= (a % 10) + '0';
            a /= 10;
        }
        for (int i = 0; i < ret.length / 2; i++) {
            char c = ret[i];
            ret[i] = ret[$ - i - 1];
            ret[$ - i - 1] = c;
        }
        if (neg)
            ret = "-" ~ ret;

        return cast(string) ret;
    }

    string toInternal(T)(double a) {
        // a simplifying assumption here is the fact that we only use this in one place: toInternal!string(cast(double) a / 255)
        // thus we know this will always be between 0.0 and 1.0, inclusive.
        if (a <= 0.0)
            return "0.0";
        if (a >= 1.0)
            return "1.0";
        string ret = "0.";
        // I wonder if I can handle round off error any better. Phobos does, but that isn't worth 100 KB of code.
        int amt = cast(int)(a * 1000);
        return ret ~ toInternal!string(amt);
    }

    nothrow @safe @nogc pure
    double absInternal(double a) {
        return a < 0 ? -a : a;
    }

    nothrow @safe @nogc pure
    double minInternal(double a, double b, double c) {
        auto m = a;
        if (b < m)
            m = b;
        if (c < m)
            m = c;
        return m;
    }

    nothrow @safe @nogc pure
    double maxInternal(double a, double b, double c) {
        auto m = a;
        if (b > m)
            m = b;
        if (c > m)
            m = c;
        return m;
    }

    nothrow @safe @nogc pure
    bool startsWithInternal(in char[] a, in char[] b) {
        return (a.length >= b.length && a[0 .. b.length] == b);
    }

    void splitInternal(scope inout(char)[] a, char c, scope void delegate(int, scope inout(char)[]) @safe dg) {
        int count;
        size_t previous = 0;
        foreach (i, char ch; a) {
            if (ch == c) {
                dg(count++, a[previous .. i]);
                previous = i + 1;
            }
        }
        if (previous != a.length)
            dg(count++, a[previous .. $]);
    }

    nothrow @safe @nogc pure
    inout(char)[] stripInternal(return inout(char)[] s) {
        foreach (i, char c; s)
            if (c != ' ' && c != '\t' && c != '\n') {
                s = s[i .. $];
                break;
            }
        for (int a = cast(int)((s.length) - 1); a > 0; a--) {
            char c = s[a];
            if (c != ' ' && c != '\t' && c != '\n') {
                s = s[0 .. a + 1];
                break;
            }
        }

        return s;
    }
}

/// Represents an RGBA color
struct Color {

    @system static Color fromJsVar(T)(T v) { // it is a template so i don't have to actually import arsd.jsvar...
        return Color.fromString(v.get!string);
    }

@safe:
    /**
		The color components are available as a static array, individual bytes, and a uint inside this union.

		Since it is anonymous, you can use the inner members' names directly.
	*/
    union {
        ubyte[4] components; /// [r, g, b, a]

        /// Holder for rgba individual components.
        struct {
            ubyte r; /// red
            ubyte g; /// green
            ubyte b; /// blue
            ubyte a; /// alpha. 255 == opaque
        }

        uint asUint; /// The components as a single 32 bit value (beware of endian issues!)
    }

    /**
		Returns a value compatible with [https://docs.microsoft.com/en-us/windows/win32/gdi/colorref|a Win32 COLORREF].

		Please note that the alpha value is lost in translation.
	*/
    nothrow pure @nogc
    uint asWindowsColorRef() {
        uint cr;
        cr |= b << 16;
        cr |= g << 8;
        cr |= r;
        return cr;
    }

    /**
		Constructs a Color from [https://docs.microsoft.com/en-us/windows/win32/gdi/colorref|a Win32 COLORREF].
	*/
    nothrow pure @nogc
    static Color fromWindowsColorRef(uint cr) {
        return Color(cr & 0xff, (cr >> 8) & 0xff, (cr >> 16) & 0xff);
    }

    /**
		Like the constructor, but this makes sure they are in range before casting. If they are out of range, it saturates: anything less than zero becomes zero and anything greater than 255 becomes 255.
	*/
    nothrow pure @nogc
    static Color fromIntegers(int red, int green, int blue, int alpha = 255) {
        return Color(clampToByte(red), clampToByte(green), clampToByte(blue), clampToByte(alpha));
    }

    /// Construct a color with the given values. They should be in range 0 <= x <= 255, where 255 is maximum intensity and 0 is minimum intensity.
    nothrow pure @nogc
    this(int red, int green, int blue, int alpha = 255) {
        this.r = cast(ubyte) red;
        this.g = cast(ubyte) green;
        this.b = cast(ubyte) blue;
        this.a = cast(ubyte) alpha;
    }

    /**
		Construct a color from components[0 .. 4]. It must have length of at least 4 and be in r, g, b, a order.
	*/
    nothrow pure @nogc
    this(ubyte[] components) {
        this.components[] = components[0 .. 4];
    }

    /// Static convenience functions for common color names
    nothrow pure @nogc
    static Color transparent() {
        return Color(0, 0, 0, 0);
    }

    nothrow pure @nogc
    static Color white() {
        return Color(255, 255, 255);
    }

    nothrow pure @nogc
    static Color gray() {
        return Color(128, 128, 128);
    }

    nothrow pure @nogc
    static Color black() {
        return Color(0, 0, 0);
    }

    nothrow pure @nogc
    static Color red() {
        return Color(255, 0, 0);
    }

    nothrow pure @nogc
    static Color green() {
        return Color(0, 255, 0);
    }

    nothrow pure @nogc
    static Color blue() {
        return Color(0, 0, 255);
    }

    nothrow pure @nogc
    static Color yellow() {
        return Color(255, 255, 0);
    }

    nothrow pure @nogc
    static Color teal() {
        return Color(0, 255, 255);
    }

    nothrow pure @nogc
    static Color purple() {
        return Color(128, 0, 128);
    }

    nothrow pure @nogc
    static Color magenta() {
        return Color(255, 0, 255);
    }

    nothrow pure @nogc
    static Color brown() {
        return Color(128, 64, 0);
    }

    nothrow pure @nogc
    void premultiply() {
        r = (r * a) / 255;
        g = (g * a) / 255;
        b = (b * a) / 255;
    }

    nothrow pure @nogc
    void unPremultiply() {
        r = cast(ubyte)(r * 255 / a);
        g = cast(ubyte)(g * 255 / a);
        b = cast(ubyte)(b * 255 / a);
    }

    /// Return black-and-white color
    Color toBW()() nothrow pure @safe @nogc {
        int intens = clampToByte(cast(int)(0.2126 * r + 0.7152 * g + 0.0722 * b));
        return Color(intens, intens, intens, a);
    }

    /// Makes a string that matches CSS syntax for websites
    string toCssString() const {
        if (a == 255)
            return "#" ~ toHexInternal(r) ~ toHexInternal(g) ~ toHexInternal(b);
        else {
            return "rgba(" ~ toInternal!string(r) ~ ", " ~ toInternal!string(
                g) ~ ", " ~ toInternal!string(b) ~ ", " ~ toInternal!string(
                cast(double) a / 255.0) ~ ")";
        }
    }

    /// Makes a hex string RRGGBBAA (aa only present if it is not 255)
    string toString() const {
        if (a == 255)
            return toCssString()[1 .. $];
        else
            return toRgbaHexString();
    }

    /// returns RRGGBBAA, even if a== 255
    string toRgbaHexString() const {
        return toHexInternal(r) ~ toHexInternal(g) ~ toHexInternal(b) ~ toHexInternal(a);
    }

    /// Gets a color by name, iff the name is one of the static members listed above
    static Color fromNameString(string s) {
        Color c;
        foreach (member; __traits(allMembers, Color)) {
            static if (__traits(compiles, c = __traits(getMember, Color, member))) {
                if (s == member)
                    return __traits(getMember, Color, member);
            }
        }
        throw new Exception("Unknown color " ~ s);
    }

    /**
		Reads a CSS style string to get the color. Understands #rrggbb, rgba(), hsl(), and rrggbbaa
	*/
    static Color fromString(scope const(char)[] s) {
        s = s.stripInternal();

        Color c;
        c.a = 255;

        // trying named colors via the static no-arg methods here
        foreach (member; __traits(allMembers, Color)) {
            static if (__traits(compiles, c = __traits(getMember, Color, member))) {
                if (s == member)
                    return __traits(getMember, Color, member);
            }
        }

        // hsl(h,s,l,a) where h is degrees and s,l,a are 0 >= x <= 1.0
        if (s.startsWithInternal("hsl(") || s.startsWithInternal("hsla(")) {
            assert(s[$ - 1] == ')');
            s = s[s.startsWithInternal("hsl(") ? 4: 5 .. $ - 1]; // the closing paren

            double[3] hsl;
            ubyte a = 255;

            s.splitInternal(',', (int i, scope const(char)[] part) {
                if (i < 3)
                    hsl[i] = toInternal!double(part.stripInternal);
                else
                    a = clampToByte(cast(int)(toInternal!double(part.stripInternal) * 255));
            });

            c = .fromHsl(hsl);
            c.a = a;

            return c;
        }

        // rgb(r,g,b,a) where r,g,b are 0-255 and a is 0-1.0
        if (s.startsWithInternal("rgb(") || s.startsWithInternal("rgba(")) {
            assert(s[$ - 1] == ')');
            s = s[s.startsWithInternal("rgb(") ? 4: 5 .. $ - 1]; // the closing paren

            s.splitInternal(',', (int i, scope const(char)[] part) {
                // lol the loop-switch pattern
                auto v = toInternal!double(part.stripInternal);
                switch (i) {
                case 0: // red
                    c.r = clampToByte(cast(int) v);
                    break;
                case 1:
                    c.g = clampToByte(cast(int) v);
                    break;
                case 2:
                    c.b = clampToByte(cast(int) v);
                    break;
                case 3:
                    c.a = clampToByte(cast(int)(v * 255));
                    break;
                default: // ignore
                }
            });

            return c;
        }

        // otherwise let's try it as a hex string, really loosely

        if (s.length && s[0] == '#')
            s = s[1 .. $];

        // support short form #fff for example
        if (s.length == 3 || s.length == 4) {
            string n;
            n.reserve(8);
            foreach (ch; s) {
                n ~= ch;
                n ~= ch;
            }
            s = n;
        }

        // not a built in... do it as a hex string
        if (s.length >= 2) {
            c.r = fromHexInternal(s[0 .. 2]);
            s = s[2 .. $];
        }
        if (s.length >= 2) {
            c.g = fromHexInternal(s[0 .. 2]);
            s = s[2 .. $];
        }
        if (s.length >= 2) {
            c.b = fromHexInternal(s[0 .. 2]);
            s = s[2 .. $];
        }
        if (s.length >= 2) {
            c.a = fromHexInternal(s[0 .. 2]);
            s = s[2 .. $];
        }

        return c;
    }

    /// from hsl
    static Color fromHsl(double h, double s, double l) {
        return .fromHsl(h, s, l);
    }

    // this is actually branch-less for ints on x86, and even for longs on x86_64
    static ubyte clampToByte(T)(T n) pure nothrow @safe @nogc
            if (__traits(isIntegral, T)) {
        static if (__VERSION__ > 2067)
            pragma(inline, true);
        static if (T.sizeof == 2 || T.sizeof == 4) {
            static if (__traits(isUnsigned, T)) {
                return cast(ubyte)(n & 0xff | (255 - ((-cast(int)(n < 256)) >> 24)));
            } else {
                n &= -cast(int)(n >= 0);
                return cast(ubyte)(n | ((255 - cast(int) n) >> 31));
            }
        } else static if (T.sizeof == 1) {
            static assert(__traits(isUnsigned, T), "clampToByte: signed byte? no, really?");
            return cast(ubyte) n;
        } else static if (T.sizeof == 8) {
            static if (__traits(isUnsigned, T)) {
                return cast(ubyte)(n & 0xff | (255 - ((-cast(long)(n < 256)) >> 56)));
            } else {
                n &= -cast(long)(n >= 0);
                return cast(ubyte)(n | ((255 - cast(long) n) >> 63));
            }
        } else {
            static assert(false, "clampToByte: integer too big");
        }
    }

    /** this mixin can be used to alphablend two `uint` colors;
	 * `colu32name` is variable that holds color to blend,
	 * `destu32name` is variable that holds "current" color (from surface, for example).
	 * alpha value of `destu32name` doesn't matter.
	 * alpha value of `colu32name` means: 255 for replace color, 0 for keep `destu32name`.
	 *
	 * WARNING! This function does blending in RGB space, and RGB space is not linear!
	 */
    public enum ColorBlendMixinStr(string colu32name, string destu32name) = "{
		immutable uint a_tmp_ = (256-(255-(("
        ~ colu32name ~ ")>>24)))&(-(1-(((255-((" ~
        colu32name ~ ")>>24))+1)>>8))); // to not lose bits, but 255 should become 0
		immutable uint dc_tmp_ = ("
        ~ destu32name ~ ")&0xffffff;
		immutable uint srb_tmp_ = (("
        ~ colu32name ~ ")&0xff00ff);
		immutable uint sg_tmp_ = (("
        ~ colu32name ~ ")&0x00ff00);
		immutable uint drb_tmp_ = (dc_tmp_&0xff00ff);
		immutable uint dg_tmp_ = (dc_tmp_&0x00ff00);
		immutable uint orb_tmp_ = (drb_tmp_+(((srb_tmp_-drb_tmp_)*a_tmp_+0x800080)>>8))&0xff00ff;
		immutable uint og_tmp_ = (dg_tmp_+(((sg_tmp_-dg_tmp_)*a_tmp_+0x008000)>>8))&0x00ff00;
		("
        ~ destu32name ~ ") = (orb_tmp_|og_tmp_)|0xff000000; /*&0xffffff;*/
	}";

    /// Perform alpha-blending of `fore` to this color, return new color.
    /// WARNING! This function does blending in RGB space, and RGB space is not linear!
    Color alphaBlend(Color fore) const pure nothrow @trusted @nogc {
        version (LittleEndian) {
            static if (__VERSION__ > 2067)
                pragma(inline, true);
            Color res;
            res.asUint = asUint;
            mixin(ColorBlendMixinStr!("fore.asUint", "res.asUint"));
            return res;
        } else {
            alias foreground = fore;
            alias background = this;
            foreach (idx, ref part; foreground.components)
                part = cast(ubyte)(part * foreground.a / 255 + background.components[idx] * (
                        255 - foreground.a) / 255);
            return foreground;
        }
    }
}

void premultiplyBgra(ubyte[] bgra) pure @nogc @safe nothrow
in {
    assert(bgra.length == 4);
}
do {
    auto a = bgra[3];

    bgra[2] = (bgra[2] * a) / 255;
    bgra[1] = (bgra[1] * a) / 255;
    bgra[0] = (bgra[0] * a) / 255;
}

void unPremultiplyRgba(ubyte[] rgba) pure @nogc @safe nothrow
in {
    assert(rgba.length == 4);
}
do {
    auto a = rgba[3];

    rgba[0] = cast(ubyte)(rgba[0] * 255 / a);
    rgba[1] = cast(ubyte)(rgba[1] * 255 / a);
    rgba[2] = cast(ubyte)(rgba[2] * 255 / a);
}

unittest {
    Color c = Color.fromString("#fff");
    assert(c == Color.white);
    assert(c == Color.fromString("#ffffff"));

    c = Color.fromString("#f0f");
    assert(c == Color.fromString("rgb(255, 0, 255)"));
}

nothrow @safe
private string toHexInternal(ubyte b) {
    string s;
    if (b < 16)
        s ~= '0';
    else {
        ubyte t = (b & 0xf0) >> 4;
        if (t >= 10)
            s ~= 'A' + t - 10;
        else
            s ~= '0' + t;
        b &= 0x0f;
    }
    if (b >= 10)
        s ~= 'A' + b - 10;
    else
        s ~= '0' + b;

    return s;
}

nothrow @safe @nogc pure
private ubyte fromHexInternal(in char[] s) {
    int result = 0;

    int exp = 1;
    foreach_reverse (c; s) {
        if (c >= 'A' && c <= 'F')
            result += exp * (c - 'A' + 10);
        else if (c >= 'a' && c <= 'f')
            result += exp * (c - 'a' + 10);
        else if (c >= '0' && c <= '9')
            result += exp * (c - '0');
        else
            return 0;

        exp *= 16;
    }

    return cast(ubyte) result;
}

/// Converts hsl to rgb
Color fromHsl(real[3] hsl) nothrow pure @safe @nogc {
    return fromHsl(cast(double) hsl[0], cast(double) hsl[1], cast(double) hsl[2]);
}

Color fromHsl(double[3] hsl) nothrow pure @safe @nogc {
    return fromHsl(hsl[0], hsl[1], hsl[2]);
}

/// Converts hsl to rgb
Color fromHsl(double h, double s, double l, double a = 255) nothrow pure @safe @nogc {
    h = h % 360;

    double C = (1 - absInternal(2 * l - 1)) * s;

    double hPrime = h / 60;

    double X = C * (1 - absInternal(hPrime % 2 - 1));

    double r, g, b;

    if (h is double.nan)
        r = g = b = 0;
    else if (hPrime >= 0 && hPrime < 1) {
        r = C;
        g = X;
        b = 0;
    } else if (hPrime >= 1 && hPrime < 2) {
        r = X;
        g = C;
        b = 0;
    } else if (hPrime >= 2 && hPrime < 3) {
        r = 0;
        g = C;
        b = X;
    } else if (hPrime >= 3 && hPrime < 4) {
        r = 0;
        g = X;
        b = C;
    } else if (hPrime >= 4 && hPrime < 5) {
        r = X;
        g = 0;
        b = C;
    } else if (hPrime >= 5 && hPrime < 6) {
        r = C;
        g = 0;
        b = X;
    }

    double m = l - C / 2;

    r += m;
    g += m;
    b += m;

    return Color(
        cast(int)(r * 255),
        cast(int)(g * 255),
        cast(int)(b * 255),
        cast(int)(a));
}

/// Assumes the input `u` is already between 0 and 1 fyi.
nothrow pure @safe @nogc
double srgbToLinearRgb(double u) {
    if (u < 0.4045)
        return u / 12.92;
    else
        return ((u + 0.055) / 1.055) ^^ 2.4;
}

/*
Converts an RGB color into an HSL triplet. 
useWeightedLightness will try to get a better value for luminosity for the human eye, 
which is more sensitive to green than red and more to red than blue. 
If it is false, it just does average of the rgb.
*/
double[3] toHsl(Color c, bool useWeightedLightness = false) nothrow pure @trusted @nogc {
    double r1 = cast(double) c.r / 255;
    double g1 = cast(double) c.g / 255;
    double b1 = cast(double) c.b / 255;

    double maxColor = maxInternal(r1, g1, b1);
    double minColor = minInternal(r1, g1, b1);

    double L = (maxColor + minColor) / 2;
    if (useWeightedLightness) {
        // the colors don't affect the eye equally
        // this is a little more accurate than plain HSL numbers
        L = 0.2126 * srgbToLinearRgb(r1) + 0.7152 * srgbToLinearRgb(g1) + 0.0722 * srgbToLinearRgb(
            b1);
        // maybe a better number is 299, 587, 114
    }
    double S = 0;
    double H = 0;
    if (maxColor != minColor) {
        if (L < 0.5) {
            S = (maxColor - minColor) / (maxColor + minColor);
        } else {
            S = (maxColor - minColor) / (2.0 - maxColor - minColor);
        }
        if (r1 == maxColor) {
            H = (g1 - b1) / (maxColor - minColor);
        } else if (g1 == maxColor) {
            H = 2.0 + (b1 - r1) / (maxColor - minColor);
        } else {
            H = 4.0 + (r1 - g1) / (maxColor - minColor);
        }
    }

    H = H * 60;
    if (H < 0) {
        H += 360;
    }

    return [H, S, L];
}

Color lighten(Color c, double percentage) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[2] *= (1 + percentage);
    if (hsl[2] > 1)
        hsl[2] = 1;
    return fromHsl(hsl);
}

Color darken(Color c, double percentage) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[2] *= (1 - percentage);
    return fromHsl(hsl);
}

/// for light colors, call darken. for dark colors, call lighten.
/// The goal: get toward center grey.
Color moderate(Color c, double percentage) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    if (hsl[2] > 0.5)
        hsl[2] *= (1 - percentage);
    else {
        if (hsl[2] <= 0.01) // if we are given black, moderating it means getting *something* out
            hsl[2] = percentage;
        else
            hsl[2] *= (1 + percentage);
    }
    if (hsl[2] > 1)
        hsl[2] = 1;
    return fromHsl(hsl);
}

/// the opposite of moderate. Make darks darker and lights lighter
Color extremify(Color c, double percentage) nothrow pure @safe @nogc {
    auto hsl = toHsl(c, true);
    if (hsl[2] < 0.5)
        hsl[2] *= (1 - percentage);
    else
        hsl[2] *= (1 + percentage);
    if (hsl[2] > 1)
        hsl[2] = 1;
    return fromHsl(hsl);
}

/// Move around the lightness wheel, trying not to break on moderate things
Color oppositeLightness(Color c) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);

    auto original = hsl[2];

    if (original > 0.4 && original < 0.6)
        hsl[2] = 0.8 - original; // so it isn't quite the same
    else
        hsl[2] = 1 - original;

    return fromHsl(hsl);
}

/// Try to determine a text color - either white or black - based on the input
Color makeTextColor(Color c) nothrow pure @safe @nogc {
    auto hsl = toHsl(c, true); // give green a bonus for contrast
    if (hsl[2] > 0.71)
        return Color(0, 0, 0);
    else
        return Color(255, 255, 255);
}

// These provide functional access to hsl manipulation; useful if you need a delegate

Color setLightness(Color c, double lightness) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[2] = lightness;
    return fromHsl(hsl);
}

Color rotateHue(Color c, double degrees) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[0] += degrees;
    return fromHsl(hsl);
}

Color setHue(Color c, double hue) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[0] = hue;
    return fromHsl(hsl);
}

Color desaturate(Color c, double percentage) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[1] *= (1 - percentage);
    return fromHsl(hsl);
}

Color saturate(Color c, double percentage) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[1] *= (1 + percentage);
    if (hsl[1] > 1)
        hsl[1] = 1;
    return fromHsl(hsl);
}

Color setSaturation(Color c, double saturation) nothrow pure @safe @nogc {
    auto hsl = toHsl(c);
    hsl[1] = saturation;
    return fromHsl(hsl);
}

ubyte unalpha(ubyte colorYouHave, float alpha, ubyte backgroundColor) nothrow pure @safe @nogc {
    // resultingColor = (1-alpha) * backgroundColor + alpha * answer
    auto resultingColorf = cast(float) colorYouHave;
    auto backgroundColorf = cast(float) backgroundColor;

    auto answer = (resultingColorf - backgroundColorf + alpha * backgroundColorf) / alpha;
    return Color.clampToByte(cast(int) answer);
}

ubyte makeAlpha(ubyte colorYouHave, ubyte backgroundColor /*, ubyte foreground = 0x00*/ ) nothrow pure @safe @nogc {
    //auto foregroundf = cast(float) foreground;
    auto foregroundf = 0.00f;
    auto colorYouHavef = cast(float) colorYouHave;
    auto backgroundColorf = cast(float) backgroundColor;

    // colorYouHave = backgroundColorf - alpha * backgroundColorf + alpha * foregroundf
    auto alphaf = 1 - colorYouHave / backgroundColorf;
    alphaf *= 255;

    return Color.clampToByte(cast(int) alphaf);
}

int fromHex(string s) {
    int result = 0;

    int exp = 1;
    // foreach(c; retro(s)) {
    foreach_reverse (c; s) {
        if (c >= 'A' && c <= 'F')
            result += exp * (c - 'A' + 10);
        else if (c >= 'a' && c <= 'f')
            result += exp * (c - 'a' + 10);
        else if (c >= '0' && c <= '9')
            result += exp * (c - '0');
        else
            throw new Exception("invalid hex character: " ~ cast(char) c);

        exp *= 16;
    }

    return result;
}

Color colorFromString(string s) {
    if (s.length == 0)
        return Color(0, 0, 0, 255);
    if (s[0] == '#')
        s = s[1 .. $];
    assert(s.length == 6 || s.length == 8);

    Color c;

    c.r = cast(ubyte) fromHex(s[0 .. 2]);
    c.g = cast(ubyte) fromHex(s[2 .. 4]);
    c.b = cast(ubyte) fromHex(s[4 .. 6]);
    if (s.length == 8)
        c.a = cast(ubyte) fromHex(s[6 .. 8]);
    else
        c.a = 255;

    return c;
}

/// An image in memory
interface MemoryImage {
    //IndexedImage convertToIndexedImage() const;
    //TrueColorImage convertToTrueColor() const;

    /// gets it as a TrueColorImage. May return this or may do a conversion and return a new image
    TrueColorImage getAsTrueColorImage() pure nothrow @safe;

    /// Image width, in pixels
    int width() const pure nothrow @safe @nogc;

    /// Image height, in pixels
    int height() const pure nothrow @safe @nogc;

    /// Get image pixel. Slow, but returns valid RGBA color (completely transparent for off-image pixels).
    Color getPixel(immutable int x, immutable int y) const pure nothrow @safe @nogc;

    /// Set image pixel.
    void setPixel(immutable int x, immutable int y, in Color clr) nothrow @safe;

    /// Returns a copy of the image
    MemoryImage clone() const pure nothrow @safe;

    /// Load image from file. This will import arsd.image to do the actual work, and cost nothing if you don't use it.
    static MemoryImage fromImage(T : const(char)[])(T filename) @trusted {
        static if (__traits(compiles, () { import arsd.image; })) {
            // yay, we have image loader here, try it!
            import arsd.image;

            return loadImageFromFile(filename);
        } else {
            static assert(0, "please provide 'arsd.image' to load images!");
        }
    }

    // ***This method is deliberately not publicly documented.***
    void clearInternal() nothrow @system;

    /// Convenient alias for `fromImage`
    alias fromImageFile = fromImage;
}

/// An image that consists of indexes into a color palette. Use [getAsTrueColorImage]() if you don't care about palettes
class IndexedImage : MemoryImage {
    bool hasAlpha;

    Color[] palette;
    /// the data as indexes into the palette. Stored left to right, top to bottom, no padding.
    ubyte[] data;

    override void clearInternal() nothrow @system { // @nogc {
        import core.memory : GC;

        // it is safe to call [GC.free] with `null` pointer.
        GC.free(GC.addrOf(palette.ptr));
        palette = null;
        GC.free(GC.addrOf(data.ptr));
        data = null;
        _width = _height = 0;
    }

    override int width() const pure nothrow @safe @nogc {
        return _width;
    }

    override int height() const pure nothrow @safe @nogc {
        return _height;
    }

    override IndexedImage clone() const pure nothrow @trusted {
        auto n = new IndexedImage(width, height);
        n.data[] = this.data[]; // the data member is already there, so array copy
        n.palette = this.palette.dup; // and here we need to allocate too, so dup
        n.hasAlpha = this.hasAlpha;
        return n;
    }

    override Color getPixel(immutable int x, immutable int y) const pure nothrow @trusted @nogc {
        if (x >= 0 && y >= 0 && x < _width && y < _height) {
            size_t pos = cast(size_t) y * _width + x;
            if (pos >= data.length)
                return Color(0, 0, 0, 0);
            ubyte b = data.ptr[pos];
            if (b >= palette.length)
                return Color(0, 0, 0, 0);
            return palette.ptr[b];
        } else {
            return Color(0, 0, 0, 0);
        }
    }

    override void setPixel(immutable int x, immutable int y, in Color clr) nothrow @trusted {
        if (x >= 0 && y >= 0 && x < _width && y < _height) {
            size_t pos = cast(size_t) y * _width + x;
            if (pos >= data.length)
                return;
            ubyte pidx = findNearestColor(palette, clr);
            if (palette.length < 255 &&
                (palette.ptr[pidx].r != clr.r || palette.ptr[pidx].g != clr.g || palette.ptr[pidx].b != clr.b || palette
                    .ptr[pidx].a != clr.a)) {
                // add new color
                pidx = addColor(clr);
            }
            data.ptr[pos] = pidx;
        }
    }

    private int _width;
    private int _height;

    this(int w, int h) pure nothrow @safe {
        _width = w;
        _height = h;

        // ensure that the computed size does not exceed basic address space limits
        assert(cast(ulong) w * h <= size_t.max);
        // upcast to avoid overflow for images larger than 536 Mpix
        data = new ubyte[cast(size_t) w * h];
    }

    /// returns a new image
    override TrueColorImage getAsTrueColorImage() pure nothrow @safe {
        return convertToTrueColor();
    }

    /// Creates a new TrueColorImage based on this data
    TrueColorImage convertToTrueColor() const pure nothrow @trusted {
        auto tci = new TrueColorImage(width, height);
        foreach (i, b; data) {
            tci.imageData.colors[i] = palette[b];
        }
        return tci;
    }

    /// Gets an exact match, if possible, adds if not. See also: the findNearestColor free function.
    ubyte getOrAddColor(Color c) nothrow @trusted {
        foreach (i, co; palette) {
            if (c == co)
                return cast(ubyte) i;
        }

        return addColor(c);
    }

    /// Number of colors currently in the palette (note: palette entries are not necessarily used in the image data)
    int numColors() const pure nothrow @trusted @nogc {
        return cast(int) palette.length;
    }

    /// Adds an entry to the palette, returning its index
    ubyte addColor(Color c) nothrow @trusted {
        assert(palette.length < 256);
        if (c.a != 255)
            hasAlpha = true;
        palette ~= c;

        return cast(ubyte)((palette.length) - 1);
    }
}

/// An RGBA array of image data. Use the free function quantize() to convert to an IndexedImage
class TrueColorImage : MemoryImage {

    struct Data {
        ubyte[] bytes; /// the data as rgba bytes. Stored left to right, top to bottom, no padding.
        // the union is no good because the length of the struct is wrong!

        /// the same data as Color structs
        @trusted // the cast here is typically unsafe, but it is ok
        // here because I guarantee the layout, note the static assert below
        @property inout(Color)[] colors() inout pure nothrow @nogc {
            return cast(inout(Color)[]) bytes;
        }

        static assert(Color.sizeof == 4);
    }

    Data imageData;

    alias data = imageData.bytes;

    int _width;
    int _height;

    override void clearInternal() nothrow @system { // @nogc {
        import core.memory : GC;

        // it is safe to call [GC.free] with `null` pointer.
        GC.free(GC.addrOf(imageData.bytes.ptr));
        imageData.bytes = null;
        _width = _height = 0;
    }

    override TrueColorImage clone() const pure nothrow @trusted {
        auto n = new TrueColorImage(width, height);
        n.imageData.bytes[] = this.imageData.bytes[]; // copy into existing array ctor allocated
        return n;
    }

    override int width() const pure nothrow @trusted @nogc {
        return _width;
    }
    ///.
    override int height() const pure nothrow @trusted @nogc {
        return _height;
    }

    pragma(inline, true)
    override Color getPixel(immutable int x, immutable int y) const pure nothrow @trusted @nogc {
        if (x >= 0 && y >= 0 && x < _width && y < _height) {
            size_t pos = cast(size_t) y * _width + x;
            return imageData.colors.ptr[pos];
        } else {
            return Color(0, 0, 0, 0);
        }
    }

    pragma(inline, true)
    override void setPixel(immutable int x, immutable int y, in Color clr) nothrow @trusted {
        if (x >= 0 && y >= 0 && x < _width && y < _height) {
            size_t pos = cast(size_t) y * _width + x;
            if (pos < imageData.bytes.length / 4)
                imageData.colors.ptr[pos] = clr;
        }
    }

    this(int w, int h) pure nothrow @safe {
        _width = w;
        _height = h;

        // ensure that the computed size does not exceed basic address space limits
        assert(cast(ulong) w * h * 4 <= size_t.max);
        // upcast to avoid overflow for images larger than 536 Mpix
        imageData.bytes = new ubyte[cast(size_t) w * h * 4];
    }

    /// Creates with existing data. The data pointer is stored here.
    this(int w, int h, ubyte[] data) pure nothrow @safe {
        _width = w;
        _height = h;
        assert(cast(ulong) w * h * 4 <= size_t.max);
        assert(data.length == cast(size_t) w * h * 4);
        imageData.bytes = data;
    }

    /// Returns this
    override TrueColorImage getAsTrueColorImage() pure nothrow @safe {
        return this;
    }
}

alias Comparator = extern (C) int function(scope const void*, scope const void*) @system;

@trusted void nonPhobosSort(T)(T[] obj, Comparator comparator) {
    import core.stdc.stdlib;

    qsort(obj.ptr, obj.length, typeof(obj[0]).sizeof, comparator);
}

/// Converts true color to an indexed image. It uses palette as the starting point, adding entries
/// until maxColors as needed. If palette is null, it creates a whole new palette.
///
/// After quantizing the image, it applies a dithering algorithm.
///
/// This is not written for speed.
IndexedImage quantize(in TrueColorImage oldImage, Color[] palette = null, in int maxColors = 256) // this is just because IndexedImage assumes ubyte palette values
in {
    assert(maxColors <= 256);
}
do {
    int[Color] uses;
    foreach (pixel; oldImage.imageData.colors) {
        if (auto i = pixel in uses) {
            (*i)++;
        } else {
            uses[pixel] = 1;
        }
    }

    struct ColorUse {
        Color c;
        int uses;
        //string toString() { import std.conv; return c.toCssString() ~ " x " ~ to!string(uses); }
        int opCmp(ref const ColorUse co) const {
            return co.uses - uses;
        }

        extern (C) static int comparator(scope const void* lhs, scope const void* rhs) {
            return (cast(ColorUse*) rhs).uses - (cast(ColorUse*) lhs).uses;
        }
    }

    ColorUse[] sorted;

    foreach (color, count; uses)
        sorted ~= ColorUse(color, count);

    uses = null;

    nonPhobosSort(sorted, &ColorUse.comparator);
    // or, with phobos, but that adds 70ms to compile time
    //import std.algorithm.sorting : sort;
    //sort(sorted);

    ubyte[Color] paletteAssignments;
    foreach (idx, entry; palette)
        paletteAssignments[entry] = cast(ubyte) idx;

    // For the color assignments from the image, I do multiple passes, decreasing the acceptable
    // distance each time until we're full.

    // This is probably really slow.... but meh it gives pretty good results.

    auto ddiff = 32;
    for (int d1 = 128; d1 >= 0; d1 -= ddiff) {
        auto minDist = d1 * d1;
        if (d1 <= 64)
            ddiff = 16;
        if (d1 <= 32)
            ddiff = 8;
        foreach (possibility; sorted) {
            if (palette.length == maxColors)
                break;
            if (palette.length) {
                auto co = palette[findNearestColor(palette, possibility.c)];
                auto pixel = possibility.c;

                auto dr = cast(int) co.r - pixel.r;
                auto dg = cast(int) co.g - pixel.g;
                auto db = cast(int) co.b - pixel.b;

                auto dist = dr * dr + dg * dg + db * db;
                // not good enough variety to justify an allocation yet
                if (dist < minDist)
                    continue;
            }
            paletteAssignments[possibility.c] = cast(ubyte) palette.length;
            palette ~= possibility.c;
        }
    }

    // Final pass: just fill in any remaining space with the leftover common colors
    while (palette.length < maxColors && sorted.length) {
        if (sorted[0].c !in paletteAssignments) {
            paletteAssignments[sorted[0].c] = cast(ubyte) palette.length;
            palette ~= sorted[0].c;
        }
        sorted = sorted[1 .. $];
    }

    bool wasPerfect = true;
    auto newImage = new IndexedImage(oldImage.width, oldImage.height);
    newImage.palette = palette;
    foreach (idx, pixel; oldImage.imageData.colors) {
        if (auto p = pixel in paletteAssignments)
            newImage.data[idx] = *p;
        else {
            // gotta find the closest one...
            newImage.data[idx] = findNearestColor(palette, pixel);
            wasPerfect = false;
        }
    }

    if (!wasPerfect)
        floydSteinbergDither(newImage, oldImage);

    return newImage;
}

/// Finds the best match for pixel in palette (currently by checking for minimum euclidean distance in rgb colorspace)
ubyte findNearestColor(in Color[] palette, in Color pixel) nothrow pure @trusted @nogc {
    int best = 0;
    int bestDistance = int.max;
    foreach (pe, co; palette) {
        auto dr = cast(int) co.r - pixel.r;
        auto dg = cast(int) co.g - pixel.g;
        auto db = cast(int) co.b - pixel.b;
        int dist = dr * dr + dg * dg + db * db;

        if (dist < bestDistance) {
            best = cast(int) pe;
            bestDistance = dist;
        }
    }

    return cast(ubyte) best;
}

/// Perform alpha-blending of `fore` to this color, return new color.
/// WARNING! This function does blending in RGB space, and RGB space is not linear!
Color alphaBlend(Color foreground, Color background) pure nothrow @safe @nogc {
    //if(foreground.a == 255)
    //return foreground;
    if (foreground.a == 0)
        return background; // the other blend function always returns alpha 255, but if the foreground has nothing, we should keep the background the same so its antialiasing doesn't get smashed (assuming this is blending in like a png instead of on a framebuffer)

    static if (__VERSION__ > 2067)
        pragma(inline, true);
    return background.alphaBlend(foreground);
}

// I think I did this wrong... but the results aren't too bad so the bug can't be awful.
/// Dithers img in place to look more like original.
void floydSteinbergDither(IndexedImage img, in TrueColorImage original) nothrow @trusted {
    assert(img.width == original.width);
    assert(img.height == original.height);

    auto buffer = new Color[](original.imageData.colors.length);

    int x, y;

    foreach (idx, c; original.imageData.colors) {
        auto n = img.palette[img.data[idx]];
        int errorR = cast(int) c.r - n.r;
        int errorG = cast(int) c.g - n.g;
        int errorB = cast(int) c.b - n.b;

        void doit(int idxOffset, int multiplier) {
            //	if(idx + idxOffset < buffer.length)
            buffer[idx + idxOffset] = Color.fromIntegers(
                c.r + multiplier * errorR / 16,
                c.g + multiplier * errorG / 16,
                c.b + multiplier * errorB / 16,
                c.a
            );
        }

        if ((x + 1) != original.width)
            doit(1, 7);
        if ((y + 1) != original.height) {
            if (x != 0)
                doit(-1 + img.width, 3);
            doit(img.width, 5);
            if (x + 1 != original.width)
                doit(1 + img.width, 1);
        }

        img.data[idx] = findNearestColor(img.palette, buffer[idx]);

        x++;
        if (x == original.width) {
            x = 0;
            y++;
        }
    }
}

// these are just really useful in a lot of places where the color/image functions are used,
// so I want them available with Color

struct Point {
    int x;
    int y;

pure const nothrow @safe:

    Point opBinary(string op)(in Point rhs) @nogc {
        return Point(mixin("x" ~ op ~ "rhs.x"), mixin("y" ~ op ~ "rhs.y"));
    }

    Point opBinary(string op)(int rhs) @nogc {
        return Point(mixin("x" ~ op ~ "rhs"), mixin("y" ~ op ~ "rhs"));
    }
}

struct Size {
    int width;
    int height;

    int area() pure nothrow @safe const @nogc {
        return width * height;
    }
}

struct Rectangle {
    int left;
    int top;
    int right;
    int bottom;

pure const nothrow @safe @nogc:

    this(int left, int top, int right, int bottom) {
        this.left = left;
        this.top = top;
        this.right = right;
        this.bottom = bottom;
    }

    this(in Point upperLeft, in Point lowerRight) {
        this(upperLeft.x, upperLeft.y, lowerRight.x, lowerRight.y);
    }

    this(in Point upperLeft, in Size size) {
        this(upperLeft.x, upperLeft.y, upperLeft.x + size.width, upperLeft.y + size.height);
    }

    @property Point upperLeft() {
        return Point(left, top);
    }

    @property Point upperRight() {
        return Point(right, top);
    }

    @property Point lowerLeft() {
        return Point(left, bottom);
    }

    @property Point lowerRight() {
        return Point(right, bottom);
    }

    @property Point center() {
        return Point((right + left) / 2, (bottom + top) / 2);
    }

    @property Size size() {
        return Size(width, height);
    }

    @property int width() {
        return right - left;
    }

    @property int height() {
        return bottom - top;
    }

    /// Returns true if this rectangle entirely contains the other
    bool contains(in Rectangle r) {
        return contains(r.upperLeft) && contains(r.lowerRight);
    }

    bool contains(in Point p) {
        return (p.x >= left && p.x < right && p.y >= top && p.y < bottom);
    }

    /// Returns true of the two rectangles at any point overlap
    bool overlaps(in Rectangle r) {
        // the -1 in here are because right and top are exclusive
        return !((right - 1) < r.left || (r.right - 1) < left || (bottom - 1) < r.top || (
                r.bottom - 1) < top);
    }

    /**
		Returns a Rectangle representing the intersection of this and the other given one.
	*/
    Rectangle intersectionOf(in Rectangle r) {
        auto tmp = Rectangle(max(left, r.left), max(top, r.top), min(right, r.right), min(bottom, r
                .bottom));
        if (tmp.left >= tmp.right || tmp.top >= tmp.bottom)
            tmp = Rectangle.init;

        return tmp;
    }
}

private int max(int a, int b) @nogc nothrow pure @safe {
    return a >= b ? a : b;
}

private int min(int a, int b) @nogc nothrow pure @safe {
    return a <= b ? a : b;
}

/**
	Implements a flood fill algorithm, like the bucket tool in
	MS Paint.

	Note it assumes `what.length == width*height`.

	Params:
		what = the canvas to work with, arranged as top to bottom, left to right elements
		width = the width of the canvas
		height = the height of the canvas
		target = the type to replace. You may pass the existing value if you want to do what Paint does
		replacement = the replacement value
		x = the x-coordinate to start the fill (think of where the user clicked in Paint)
		y = the y-coordinate to start the fill
		additionalCheck = A custom additional check to perform on each square before continuing. Returning true means keep flooding, returning false means stop. If null, it is not used.
*/
void floodFill(T)(
    T[] what, int width, int height, // the canvas to inspect
    T target, T replacement, // fill params
    int x, int y, bool delegate(int x, int y) @safe additionalCheck) { // the node

    assert(what.length == width * height); // will use the contract above when gdc supports it

    T node = what[y * width + x];

    if (target == replacement)
        return;

    if (node != target)
        return;

    if (additionalCheck is null)
        additionalCheck = (int, int) => true;

    if (!additionalCheck(x, y))
        return;

    Point[] queue;

    queue ~= Point(x, y);

    while (queue.length) {
        auto n = queue[0];
        queue = queue[1 .. $];
        //queue.assumeSafeAppend(); // lol @safe breakage

        auto w = n;
        int offset = cast(int)(n.y * width + n.x);
        auto e = n;
        auto eoffset = offset;
        w.x--;
        offset--;
        while (w.x >= 0 && what[offset] == target && additionalCheck(w.x, w.y)) {
            w.x--;
            offset--;
        }
        while (e.x < width && what[eoffset] == target && additionalCheck(e.x, e.y)) {
            e.x++;
            eoffset++;
        }

        // to make it inclusive again
        w.x++;
        offset++;
        foreach (o; offset .. eoffset) {
            what[o] = replacement;
            if (w.y && what[o - width] == target && additionalCheck(w.x, w.y))
                queue ~= Point(w.x, w.y - 1);
            if (w.y + 1 < height && what[o + width] == target && additionalCheck(w.x, w.y))
                queue ~= Point(w.x, w.y + 1);
            w.x++;
        }
    }
}
