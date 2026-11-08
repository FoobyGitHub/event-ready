import os, sys
from lupa.lua51 import LuaRuntime
here = os.path.dirname(os.path.abspath(__file__))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ADDON_DIR = os.path.join(here, "..", "EventReady") + "/"
lua.execute(open(os.path.join(here, "test.lua")).read())
