# Description

**Warning : very much work in progress**

![Screenshot](doc/screenshot.png)

Prototype 2d oriented game engine, featuring automatic atlas baking and various experiments in sprite rendering.

Used by me as a playground for the zig language.

Goals :
* Hassle free asset managment, akin to Gamemaker (i.e the engine loads textures when needed and automaticaly batches render calls)
* Optimised workflow for 2d sprite based games

Current features :
* Automatic atlas batching of sprites
* Simple renderer abstraction for 2d rendering (sprites batches and framebuffers)
* Simple windowing abstraction

Uses : 
* [mach-glfw](https://github.com/hexops/mach-glfw) bindings for glfw
* [Zig-opengl](https://github.com/MasterQ32/zig-opengl) for opengl bindings
* [Zigimg](https://github.com/zigimg/zigimg) for image loading/saving
* [Dear-ImGui](https://github.com/ocornut/imgui) for the debug ui (♥)
* [stb_rect_pack.h](https://github.com/nothings/stb/blob/master/stb_rect_pack.h) for the rect packing algorithm


# How to get running

* Setup [zig](https://ziglang.org/download/) latest version on your system
* `git clone --recurse-submodules https://github.com/EspeuteClement/Untitled-Zig-Engine.git`
* `cd Untitled-Zig-Engine` 
* Run `zig build run-asset` to build the game assets
* Run `zig build run` to run the engine
