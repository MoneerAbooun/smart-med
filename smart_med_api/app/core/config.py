from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    openai_api_key: str | None
    openai_model: str
    openai_base_url: str
    openai_timeout_seconds: float
    firestore_users_collection: str
    firestore_drug_catalog_collection: str
    firestore_drug_interactions_collection: str
    upload_root_dir: Path
    upload_base_path: str
    upload_max_image_bytes: int


def get_settings() -> Settings:
    project_root = Path(__file__).resolve().parents[2]
    default_upload_root = project_root / "uploads"

    return Settings(
        openai_api_key=os.getenv("OPENAI_API_KEY"),
        openai_model=os.getenv("OPENAI_MODEL", "gpt-5.4-mini"),
        openai_base_url=os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        openai_timeout_seconds=float(os.getenv("OPENAI_TIMEOUT_SECONDS", "30")),
        firestore_users_collection=os.getenv("FIRESTORE_USERS_COLLECTION", "users"),
        firestore_drug_catalog_collection=os.getenv(
            "FIRESTORE_DRUG_CATALOG_COLLECTION",
            "drug_catalog",
        ),
        firestore_drug_interactions_collection=os.getenv(
            "FIRESTORE_DRUG_INTERACTIONS_COLLECTION",
            "drug_interactions",
        ),
        upload_root_dir=Path(
            os.getenv("UPLOAD_ROOT_DIR", str(default_upload_root)),
        ),
        upload_base_path=os.getenv("UPLOAD_BASE_PATH", "/uploads"),
        upload_max_image_bytes=int(
            os.getenv("UPLOAD_MAX_IMAGE_BYTES", str(5 * 1024 * 1024)),
        ),
    )
