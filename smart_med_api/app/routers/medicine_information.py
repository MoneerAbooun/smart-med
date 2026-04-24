from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import APIRouter, File, HTTPException, Query, UploadFile, status

from app.core.config import get_settings
from app.models.medicine_models import MedicineInformationResponse
from app.services.medicine_information_service import (
    lookup_medicine_information,
    lookup_medicine_information_from_image,
)

router = APIRouter(tags=["medicine-information"])

settings = get_settings()

_ALLOWED_IMAGE_CONTENT_TYPES = {
    "image/heic": "image/heic",
    "image/jpeg": "image/jpeg",
    "image/jpg": "image/jpeg",
    "image/png": "image/png",
    "image/webp": "image/webp",
}

_ALLOWED_IMAGE_EXTENSIONS = {
    "heic": "image/heic",
    "jpeg": "image/jpeg",
    "jpg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
}


@router.get("/medicine-information", response_model=MedicineInformationResponse)
async def get_medicine_information(
    name: str = Query(..., min_length=2, description="Medicine name typed by the user"),
) -> Any:
    return await lookup_medicine_information(query=name)


@router.post("/medicine-information/image", response_model=MedicineInformationResponse)
async def get_medicine_information_from_image(
    image: UploadFile = File(...),
) -> Any:
    file_name = image.filename or ""
    content_type = (image.content_type or "").strip().lower()
    normalized_content_type = _normalized_content_type(file_name, content_type)

    if normalized_content_type is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPG, PNG, WEBP, and HEIC images are supported.",
        )

    try:
        file_bytes = await image.read()
    finally:
        await image.close()

    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The uploaded image is empty.",
        )

    if len(file_bytes) > settings.upload_max_image_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image is too large. Maximum allowed size is {settings.upload_max_image_bytes // (1024 * 1024)} MB.",
        )

    return await lookup_medicine_information_from_image(
        file_bytes=file_bytes,
        content_type=normalized_content_type,
    )


def _normalized_content_type(file_name: str, content_type: str) -> str | None:
    normalized_content_type = _ALLOWED_IMAGE_CONTENT_TYPES.get(content_type)
    if normalized_content_type:
        return normalized_content_type

    suffix = Path(file_name).suffix.lower().lstrip(".")
    return _ALLOWED_IMAGE_EXTENSIONS.get(suffix)
