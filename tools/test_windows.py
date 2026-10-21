"""Ejecuta las pruebas Lua con el runtime incluido en OBS para Windows."""
import argparse
import ctypes
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--obs-bin", required=True, type=Path,
                        help="Carpeta bin/64bit de la instalación de OBS")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    with os.add_dll_directory(str(args.obs_bin.resolve())):
        lua = ctypes.CDLL(str(args.obs_bin / "lua51.dll"))
        lua.luaL_newstate.restype = ctypes.c_void_p
        lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
        lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
        lua.lua_tolstring.restype = ctypes.c_char_p
        lua.lua_close.argtypes = [ctypes.c_void_p]
        state = lua.luaL_newstate()
        if not state:
            raise RuntimeError("No se pudo crear el entorno Lua")
        try:
            lua.luaL_openlibs(state)
            result = lua.luaL_loadfile(state, b"tests/recording_beep_spec.lua")
            if result == 0:
                result = lua.lua_pcall(state, 0, 0, 0)
            if result:
                raise RuntimeError(lua.lua_tolstring(state, -1, None).decode("utf-8"))
        finally:
            lua.lua_close(state)


if __name__ == "__main__":
    main()
