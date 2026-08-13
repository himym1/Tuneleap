class RecommendationSessionExpired(RuntimeError):
    """The requested recommendation session is no longer active."""


class RecommendationTemporarilyUnavailable(RuntimeError):
    """Recommendation dependencies are temporarily unavailable."""
