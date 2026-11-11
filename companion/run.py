"""Entry point for MCP clients: py -I companion/run.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from outrider_companion import server  # noqa: E402

sys.exit(server.main())
