"""Break and Steal an Egg (public Roblox experience by ILGames x Eggs).

NOT IMPLEMENTED — BY DESIGN. The game publishes no API, modding interface or
plugin system. Player stats in Roblox experiences live on the game's servers;
an outside program could only change them by injecting into the Roblox client
and defeating its anti-cheat, which this application does not do. This class
reports that honestly instead of pretending to apply anything.
"""

from sbe_modifier.integration.base import (
    ConnectionState,
    GameIntegration,
    IntegrationError,
    ModifierRequest,
    Outcome,
)

REASON = (
    "Break and Steal an Egg does not provide any supported interface for outside "
    "applications. Speed and money are controlled by the game's Roblox servers, "
    "so nothing was changed in-game."
)


class UnsupportedGameIntegration(GameIntegration):
    display_name = "Break and Steal an Egg (public game) — no supported interface"
    description = (
        "The public game exposes no API, mod loader or plugin mechanism, and its stats "
        "are server-controlled. Settings can be configured and saved here, but they "
        "cannot be applied to this game. Changing them would require the game's "
        "developer to publish an interface (for example an Open Cloud messaging topic)."
    )

    def initial_state(self) -> Outcome:
        return Outcome(ConnectionState.UNAVAILABLE, REASON)

    def check_connection(self) -> Outcome:
        raise IntegrationError(REASON, ConnectionState.UNAVAILABLE)

    def apply(self, request: ModifierRequest) -> Outcome:
        raise IntegrationError(REASON, ConnectionState.UNAVAILABLE)
