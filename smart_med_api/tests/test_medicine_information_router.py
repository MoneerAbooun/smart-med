from fastapi.testclient import TestClient

from app.main import app
from app.models.medicine_models import MedicineInformationResponse
from app.routers import medicine_information as medicine_information_router


def test_get_medicine_information_route(monkeypatch):
    async def fake_lookup_medicine_information(*, query: str, **_: object):
        assert query == "ibuprofen"
        return MedicineInformationResponse(
            query="ibuprofen",
            search_mode="name",
            medicine_name="Ibuprofen",
            generic_name="ibuprofen",
            used_for=["Pain relief"],
            dose=["200 mg every 4 to 6 hours"],
            warnings=["Avoid if allergic to NSAIDs."],
            side_effects=["Upset stomach"],
            interactions=["May interact with anticoagulants."],
            storage=["Store at room temperature."],
            disclaimer=["Talk to a clinician for personal advice."],
        )

    monkeypatch.setattr(
        medicine_information_router,
        "lookup_medicine_information",
        fake_lookup_medicine_information,
    )

    client = TestClient(app)
    response = client.get("/medicine-information", params={"name": "ibuprofen"})

    assert response.status_code == 200
    assert response.json()["medicine_name"] == "Ibuprofen"
    assert response.json()["generic_name"] == "ibuprofen"


def test_post_medicine_information_image_route_uses_filename_extension(monkeypatch):
    async def fake_lookup_medicine_information_from_image(
        *,
        file_bytes: bytes,
        content_type: str,
    ):
        assert file_bytes == b"fake-image"
        assert content_type == "image/png"
        return MedicineInformationResponse(
            query="Advil",
            search_mode="image",
            medicine_name="Advil",
            generic_name="ibuprofen",
            used_for=["Pain relief"],
            dose=["Use as directed on the label."],
            warnings=["Use carefully with stomach ulcers."],
            side_effects=["Nausea"],
            interactions=["May interact with anticoagulants."],
            storage=["Keep tightly closed."],
            disclaimer=["This is not personal medical advice."],
            identification_reason="The label visibly shows Advil.",
        )

    monkeypatch.setattr(
        medicine_information_router,
        "lookup_medicine_information_from_image",
        fake_lookup_medicine_information_from_image,
    )

    client = TestClient(app)
    response = client.post(
        "/medicine-information/image",
        files={"image": ("pill.png", b"fake-image", "application/octet-stream")},
    )

    assert response.status_code == 200
    assert response.json()["search_mode"] == "image"
    assert response.json()["medicine_name"] == "Advil"
