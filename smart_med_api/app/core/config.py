from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    openai_api_key: str | None
    openai_model: str
    openai_base_url: str
    openai_timeout_seconds: float
    firestore_users_collection: str
    firestore_drug_catalog_collection: str
    firestore_drug_interactions_collection: str


def get_settings() -> Settings:
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
    )
