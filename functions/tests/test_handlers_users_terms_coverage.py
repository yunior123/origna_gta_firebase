from unittest.mock import MagicMock, Mock, patch
from schema_constants import Fields, ConsentMethodValues, PolicyVersionValues
from handlers.users import update_user_profile

@patch("handlers.users.get_db")
def test_update_user_profile_terms_accepted(mock_get_db):
    """Test that setting termsAcceptedAt=True updates terms with server timestamp."""
    # Properly mock the CallableRequest structure
    mock_request = MagicMock()
    mock_auth = MagicMock()
    mock_auth.uid = "test_user"
    mock_request.auth = mock_auth
    mock_request.data = {Fields.TERMS_ACCEPTED_AT: True}
    
    mock_db = MagicMock()
    mock_get_db.return_value = mock_db
    mock_user_ref = MagicMock()
    mock_db.collection.return_value.document.return_value = mock_user_ref

    # Mock the internal import
    with patch("services.rate_limiter.RateLimiter") as mock_rl_cls:
        mock_rl = MagicMock()
        mock_rl.check.return_value = None
        mock_rl_cls.return_value = mock_rl

        # Explicitly mock get_server_timestamp to avoid relying on side-effects
        with patch("handlers.users.get_server_timestamp", return_value="MOCKED_TIMESTAMP"):
            result = update_user_profile(mock_request)
            
        assert result["success"] is True
        call_args = mock_user_ref.update.call_args[0][0]
        assert call_args[Fields.TERMS_ACCEPTED_AT] == "MOCKED_TIMESTAMP"
        assert call_args[Fields.CONSENT_METHOD] == ConsentMethodValues.CHECKBOX
        assert call_args[Fields.TERMS_VERSION] == PolicyVersionValues.DEFAULT
