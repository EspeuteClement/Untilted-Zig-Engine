# Description

![Screenshot](doc/screenshot.png)

Prototype 2d oriented game engine, featuring automatic atlas baking and various experimentations in sprite rendering.
Used by me as a playground for the zig language.

Uses mach-glfw bindings for glfw
Zig-opengl for opengl bindings
Zigimg for image loading/saving
imgui for the debug ui
stb_rect_pack for the atlas packing

# How to get running

* Setup [zig](https://ziglang.org/download/) latest version on your system
* `git clone --recurse-submodules https://github.com/EspeuteClement/Untitled-Zig-Engine.git`
* `cd Untitled-Zig-Engine` 
* Run `zig build run-asset` to build the game assets
* Run `zig build run` to run the engine
