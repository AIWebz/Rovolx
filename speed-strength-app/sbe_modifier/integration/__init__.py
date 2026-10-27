"""Game integration layer. The UI talks only to ``GameIntegration``."""

from sbe_modifier.integration.base import (
    ConnectionState,
    GameIntegration,
    IntegrationError,
    ModifierRequest,
    Outcome,
)
from sbe_modifier.integration.opencloud import OpenCloudIntegration
from sbe_modifier.integration.unsupported import UnsupportedGameIntegration
from sbe_modifier.settings import BACKEND_OPEN_CLOUD, BACKEND_UNSUPPORTED

REGISTRY = {
    BACKEND_UNSUPPORTED: UnsupportedGameIntegration,
    BACKEND_OPEN_CLOUD: OpenCloudIntegration,
}

__all__ = [
    "ConnectionState",
    "GameIntegration",
    "IntegrationError",
    "ModifierRequest",
    "OpenCloudIntegration",
    "Outcome",
    "REGISTRY",
    "UnsupportedGameIntegration",
]
