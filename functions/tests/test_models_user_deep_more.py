import pytest

from models.user import User


def _base_user(**overrides):
    data = {
        "uid": "user_1",
        "email": "user@example.com",
        "name": "Valid Name",
        "roles": ["buyer"],
    }
    data.update(overrides)
    return data


class TestUserModelDeepMore:
    def test_user_name_validator_rejects_html_and_disallowed_chars(self):
        with pytest.raises(ValueError, match="disallowed characters"):
            User(**_base_user(name="Bad<Name>"))

        with pytest.raises(ValueError, match="disallowed character"):
            User(**_base_user(name="Name@"))

    def test_user_roles_validator_rejects_empty_roles(self):
        # Pydantic field min_length guards this in normal construction;
        # call validator directly to cover explicit defensive branch.
        with pytest.raises(ValueError, match="At least one role"):
            User.validate_roles([])
