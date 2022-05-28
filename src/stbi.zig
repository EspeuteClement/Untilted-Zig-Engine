pub usingnamespace @cImport({
    @cDefine("STBI_ONLY_PNG", "");
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("libs/stb/stb_image.h");
});