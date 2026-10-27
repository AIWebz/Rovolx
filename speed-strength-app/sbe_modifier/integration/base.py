"""Contract between the UI and any game integration.

An integration receives a ``ModifierRequest`` and either delivers it through a
real, documented channel or raises ``IntegrationError`` explaining why it
cannot. Integrations must never report success for something they did not do.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum


class ConnectionState(Enum):
    NOT_CONFIGURED = "Not configured"
    CONFIGURED = "Configured — not verified"
    CHECKING = "Checking connection…"
    CONNECTED = "Connected"
    APPLYING = "Applying settings…"
    UNAVAILABLE = "Game functionality unavailable"
    ERROR = "Error"


@dataclass(frozen=True)
class ModifierRequest:
    """What the user asked for. ``None`` means the modifier is disabled:
    speed returns to the game default, money is left unchanged."""

    speed: int | None
    money: int | None


@dataclass(frozen=True)
class Outcome:
    state: ConnectionState
    message: str


class IntegrationError(Exception):
    def __init__(self, message: str, state: ConnectionState = ConnectionState.ERROR):
        super().__init__(message)
        self.state = state


class GameIntegration(ABC):
    #: Shown in the integration picker.
    display_name: str = ""
    #: One-paragraph explanation shown under the picker.
    description: str = ""
    #: Whether the UI should show Universe ID / Topic / User ID / API key fields.
    needs_credentials: bool = False

    @abstractmethod
    def initial_state(self) -> Outcome:
        """State to show before any network activity."""

    @abstractmethod
    def check_connection(self) -> Outcome:
        """Verify the integration can reach the game. Raises IntegrationError."""

    @abstractmethod
    def apply(self, request: ModifierRequest) -> Outcome:
        """Deliver ``request``. Raises IntegrationError."""

    def close(self) -> None:
        """Release resources. Called on shutdown and when switching integration."""
