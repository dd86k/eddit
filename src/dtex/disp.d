/* This version of microEmacs is based on the public domain C
 * version written by Dave G. Conroy.
 * The D programming language version is written by Walter Bright.
 * http://www.digitalmars.com/d/
 * This program is in the public domain.
 */

/* D interface to Digital Mars C/C++ disp package.
 * Windows only.
 * http://www.digitalmars.com/rtl/disp.html
 */

module disp;

version (Windows):

import core.stdc.stdarg;
import core.stdc.stdio;
import core.sys.windows.winbase : CreateFileA, WriteFile, CloseHandle,
    GetStdHandle,
    STD_OUTPUT_HANDLE,
    OPEN_EXISTING, OPEN_ALWAYS;
import core.sys.windows.winnt : GENERIC_READ, GENERIC_WRITE,
    FILE_SHARE_READ, FILE_SHARE_WRITE,
    TRUE, FALSE;
import core.sys.windows.wincon;

extern (C):

struct disp_t
{
align(1):
    uint numrows;
    uint numcols;
    uint cursorrow;
    uint cursorcol;
    ubyte mono;
    ubyte snowycga;
    ubyte mode;
    ubyte inited;
    ubyte ega;
    ubyte[3] reserved;
    short nowrap;

    union
    {
        ushort* base;
        struct
        {
            uint offset;
            ushort basep;
        }
    }

    void* handle;

    short attr;
}

__gshared disp_t disp_state;

int disp_printf(const(char)* format, ...)
{
    enum BUFLEN = 256;
    char[BUFLEN] buf = void;

    va_list args = void;
    va_start(args, format);

    int n = vsnprintf(buf.ptr, BUFLEN, format, args);
    for (int i; i < n; ++i)
    {
        disp_putc(buf[i]);
    }

    return n;
}

int disp_getmode()
{
    return disp_state.mode;
}

int disp_getattr()
{
    return 0;
}

int disp_putc(int c)
{
    uint r = void;
    WriteConsoleA(disp_state.handle, &c, 1, &r, null);
    return r;
}

//void disp_levelblockpoke(int,int,int,int,uint,uint *,uint,uint *,uint);

void disp_open()
{
    disp_state.handle = GetStdHandle(STD_OUTPUT_HANDLE);

    CONSOLE_SCREEN_BUFFER_INFO screen = void;
    GetConsoleScreenBufferInfo(disp_state.handle, &screen);
    disp_state.attr = screen.wAttributes;
    disp_state.numrows = screen.srWindow.Bottom - screen.srWindow.Top + 1;
    disp_state.numcols = screen.srWindow.Right - screen.srWindow.Left + 1;

    disp_move(0, 0);
    COORD coord;
    uint num = void;
    FillConsoleOutputCharacterA(disp_state.handle,
        ' ',
        screen.dwSize.X * screen.dwSize.Y,
        coord,
        &num);

    disp_move(0, 0);
}

void disp_puts(const(char)* str)
{
GET:
    char c = *str;
    if (c == 0)
        return;
    ++str;
    disp_putc(c);
    ++disp_state.cursorcol;
    if (disp_state.cursorcol >= disp_state.numcols)
    {
        disp_state.cursorcol = 0;
        ++disp_state.cursorrow;
    }
    goto GET;
}

//void disp_box(int,int,uint,uint,uint,uint);

void disp_close()
{
    CloseHandle(disp_state.handle);
}

void disp_move(int row, int col)
{
    COORD c = void;
    disp_state.cursorcol = c.X = cast(short) col;
    disp_state.cursorrow = c.Y = cast(short) row;
    SetConsoleCursorPosition(disp_state.handle, c);
}

void disp_flush()
{
    //TODO: refresh col/row count?
    FlushConsoleInputBuffer(disp_state.handle);
}

/// Erase to end of line
void disp_eeol()
{
    int count = disp_state.numcols - disp_state.cursorcol;
    for (int i; i < count; ++i)
        disp_putc(' ');
}

/// Erase to end of page
void disp_eeop()
{
    int total = disp_state.numcols * disp_state.numrows;
    int pos = disp_state.cursorcol * disp_state.cursorrow;

    int count = total - pos;
    for (int i; i < count; ++i)
        disp_putc(' ');
}

/// Start standout mode
void disp_startstand()
{
    with (disp_state)
        SetConsoleTextAttribute(handle, attr | COMMON_LVB_REVERSE_VIDEO);
}

/// End standout mode
void disp_endstand()
{
    with (disp_state)
        SetConsoleTextAttribute(handle, attr);
}

//void disp_setattr(int);

void disp_setcursortype(int cursor)
{
    CONSOLE_CURSOR_INFO info = void;
    info.bVisible = TRUE;
    info.dwSize = cursor;
    SetConsoleCursorInfo(disp_state.handle, &info);
}

//void disp_pokew(int,int,ushort);

//void disp_scroll(int,uint,uint,uint,uint,uint);

void disp_setmode(ubyte mode)
{
    disp_state.mode = mode;
}

//void disp_peekbox(ushort *,uint,uint,uint,uint);

//void disp_pokebox(ushort *,uint,uint,uint,uint);

//void disp_fillbox(uint,uint,uint,uint,uint);

//void disp_hidecursor();

//void disp_showcursor();

//ushort disp_peekw(int,int);

enum
{
    DISP_REVERSEVIDEO = 0x70,
    DISP_NORMAL = 0x07,
    DISP_UNDERLINE = 0x01,
    DISP_NONDISPLAY = 0x00,

    DISP_INTENSITY = 0x08,
    DISP_BLINK = 0x80,

    DISP_CURSORBLOCK = 100,
    DISP_CURSORHALF = 50,
    DISP_CURSORUL = 20,
}
