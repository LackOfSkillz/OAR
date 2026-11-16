"""Outrider Intelligence (sprint 1): grounded answers from a local model.

context.py       snapshot -> ContextEnvelope v2 (privacy filtered, bounded)
providers.py     model providers: OpenAI-compatible local endpoint, fake for tests
orchestrator.py  question -> model -> validated answer (schema 2 advice)
ask.py           command line: snapshot code in, advice code out

Nothing here executes Lua, reads the game process or acts in game. See
docs/AI_PRIVACY_AND_TRANSPORT.md.
"""
