"""Import-only stand-in for the organisers' `bazaar_sdk` (part of their bazaar-kit, not redistributed here).

The tests never talk to the game: every test injects its own fake. This module only lets the code under test import.
Put the real bazaar-kit on PYTHONPATH and it is used instead of this file.
"""


class BazaarError(Exception):
    """Same shape as the SDK's: `code` is the server's reason, `status` the HTTP status (0 = no response)."""

    def __init__(self, code: str, message: str = "", status: int = 0, extra: dict | None = None):
        super().__init__(f"{code}: {message}" if message else code)
        self.code = code
        self.message = message
        self.status = status
        self.extra = extra or {}


class _Http:
    def __init__(self, *args, **kwargs):
        raise RuntimeError("bazaar_sdk stub: install the organisers' bazaar-kit to reach the game")


class Bazaar(_Http):
    pass


class Broker(_Http):
    pass
