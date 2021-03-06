
// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.rmem;

import core.stdc.string;

version(GC)
{
import core.memory : GC;

extern(C++)
struct Mem
{
    char* strdup(const char* p)
    {
        return p[0..strlen(p)+1].dup.ptr;
    }
    void free(void* p) {}
    void* malloc(size_t n) { return GC.malloc(n); }
    void* calloc(size_t size, size_t n) { return GC.calloc(size * n); }
    void* realloc(void* p, size_t size) { return GC.realloc(p, size); }
}
extern(C++) __gshared Mem mem;

version(Windows)
{
    extern(C++)
    pragma(mangle, "??2@YAPAXI@Z")
    void* operator_new(size_t n)
    {
        return GC.malloc(n);
    }

    extern(C++)
    pragma(mangle, "??3@YAPAXI@Z")
    void operator_delete(void* p)
    {
    }
    extern(C++)
    pragma(mangle, "??_P@YAPAXI@Z")
    void* operator_new_array(size_t n)
    {
        return GC.malloc(n);
    }

    extern(C++)
    pragma(mangle, "??_Q@YAXPAX@Z")
    void operator_delete_array(void* p)
    {
    }
}
else
{
    static assert(0);
}

}
else
{

import core.stdc.stdlib;
import core.stdc.stdio;

extern(C++)
struct Mem
{
    char* strdup(const char* s)
    {
        if (s)
        {
            auto p = .strdup(s);
            if (p)
                return p;
            error();
        }
        return null;
    }
    void free(void* p)
    {
        if (p)
            .free(p);
    }
    void* malloc(size_t size)
    {
        if (!size)
            return null;

        auto p = .malloc(size);
        if (!p)
            error();
        return p;
    }
    void* calloc(size_t size, size_t n)
    {
        if (!size || !n)
            return null;

        auto p = .calloc(size, n);
        if (!p)
            error();
        return p;
    }
    void* realloc(void* p, size_t size)
    {
        if (!size)
        {
            if (p)
                .free(p);
            return null;
        }

        if (!p)
        {
            p = .malloc(size);
            if (!p)
                error();
            return p;
        }

        p = .realloc(p, size);
        if (!p)
            error();
        return p;
    }
    void error()
    {
        printf("Error: out of memory\n");
        exit(EXIT_FAILURE);
    }
}
extern(C++) __gshared Mem mem;

enum CHUNK_SIZE = (256 * 4096 - 64);

__gshared size_t heapleft = 0;
__gshared void *heapp;

extern (C) Object _d_newclass(const ClassInfo ci)
{
    auto m_size = ci.init.length;

    // 16 byte alignment is better (and sometimes needed) for doubles
    m_size = (m_size + 15) & ~15;

    // The layout of the code is selected so the most common case is straight through
    if (m_size <= heapleft)
    {
    L1:
        heapleft -= m_size;
        auto p = heapp;
        heapp = cast(void *)(cast(char *)heapp + m_size);
        (cast(byte*) p)[0 .. ci.init.length] = ci.init[];
        return cast(Object)p;
    }

    if (m_size > CHUNK_SIZE)
    {
        auto p = malloc(m_size);
        if (p)
        {
            (cast(byte*) p)[0 .. ci.init.length] = ci.init[];
            return cast(Object)p;
        }
        printf("Error: out of memory\n");
        exit(EXIT_FAILURE);
    }

    heapleft = CHUNK_SIZE;
    heapp = malloc(CHUNK_SIZE);
    if (!heapp)
    {
        printf("Error: out of memory\n");
        exit(EXIT_FAILURE);
    }
    goto L1;
}

}
