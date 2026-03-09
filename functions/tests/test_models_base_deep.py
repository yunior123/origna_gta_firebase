import pytest
from pydantic import ValidationError

from models.base import Address, AddressDetails


class TestBaseModelDeep:
    def test_address_full_address_includes_all_non_empty_parts(self):
        address = Address(
            street="123 Main St",
            apartment="Apt 4B",
            city="Toronto",
            state="ON",
            postalCode="M5V3A8",
            country="Canada",
        )
        full = address.full_address()
        assert "123 Main St" in full
        assert "Apt 4B" in full
        assert "Toronto" in full

    def test_address_details_validators_cover_success_and_failures(self):
        details = AddressDetails(
            street="123 Main St",
            city="Toronto",
            state="on",
            postalCode="M5V3A8",
            latitude=43.65,
            longitude=-79.38,
        )
        assert details.state == "ON"
        assert details.postalCode == "M5V 3A8"

        with pytest.raises(ValidationError):
            AddressDetails(
                street="123 Main St",
                city="Toronto",
                state="ON",
                postalCode="12345",
                latitude=43.65,
                longitude=-79.38,
            )

        with pytest.raises(ValidationError):
            AddressDetails(
                street="123 Main St",
                city="Toronto",
                state="XX",
                postalCode="M5V3A8",
                latitude=43.65,
                longitude=-79.38,
            )
