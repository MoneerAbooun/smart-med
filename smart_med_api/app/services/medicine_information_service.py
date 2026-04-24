from __future__ import annotations

import asyncio
import base64
import json

from fastapi import HTTPException, status
from openai import APIConnectionError, APIError, APIStatusError, APITimeoutError

from app.core.config import get_settings
from app.core.xai_client import get_xai_client, response_output_text
from app.models.drug_models import DrugAlternativeItem
from app.models.medicine_models import MedicineInformationResponse
from app.services.dailymed_service import get_spl_by_rxcui
from app.services.openfda_service import extract_label_sections, get_label_by_generic_or_brand_name
from app.services.rxnorm_service import get_related_concepts_by_type, resolve_drug_name

RELATED_TERM_TYPES = ["SCD", "SBD", "GPCK", "BPCK", "BN"]

CATEGORY_BY_TERM_TYPE = {
    "SCD": "Generic drug",
    "SBD": "Brand drug",
    "GPCK": "Generic pack",
    "BPCK": "Brand pack",
    "BN": "Brand name",
}


def _normalized_text(value: str | None) -> str:
    if not value:
        return ""
    return " ".join(value.lower().split())


def _preferred_name(concept: dict[str, str]) -> str:
    synonym = concept.get("synonym", "").strip()
    name = concept.get("name", "").strip()
    return synonym or name


def _unique_strings(values: list[str]) -> list[str]:
    seen: set[str] = set()
    results: list[str] = []

    for value in values:
        cleaned = " ".join(str(value).split()).strip()
        if not cleaned:
            continue

        key = cleaned.lower()
        if key in seen:
            continue

        seen.add(key)
        results.append(cleaned)

    return results


def _collect_alternatives(
    related: dict[str, list[dict[str, str]]],
    query: str,
    matched_name: str | None,
    limit: int = 12,
) -> list[DrugAlternativeItem]:
    alternatives: list[DrugAlternativeItem] = []
    seen: set[str] = {_normalized_text(query), _normalized_text(matched_name)}

    for term_type in RELATED_TERM_TYPES:
        for concept in related.get(term_type, []):
            name = _preferred_name(concept)
            key = _normalized_text(name)

            if not name or not key or key in seen:
                continue

            seen.add(key)
            alternatives.append(
                DrugAlternativeItem(
                    name=name,
                    rxcui=concept.get("rxcui") or None,
                    term_type=concept.get("tty") or term_type,
                    category=CATEGORY_BY_TERM_TYPE.get(term_type, "Alternative"),
                )
            )

            if len(alternatives) >= limit:
                return alternatives

    return alternatives


def _build_warning_items(sections: dict[str, list[str]]) -> list[str]:
    contraindications = [
        f"Contraindication: {item}"
        for item in sections.get("contraindications", [])
    ]
    return _unique_strings(sections.get("warnings", []) + contraindications)


def _build_disclaimer_items(sections: dict[str, list[str]]) -> list[str]:
    items = _unique_strings(sections.get("disclaimer", []))
    items.append(
        "This information comes from public medication references and is not a substitute for advice from a doctor or pharmacist."
    )
    return _unique_strings(items)


async def _resolve_label_and_identity(query: str) -> tuple[str, str | None, dict[str, list[str]], str | None]:
    rxcui, matched_name = await resolve_drug_name(query)
    if rxcui is None:
        raise HTTPException(status_code=404, detail="Drug not found in RxNorm")

    spl = await get_spl_by_rxcui(rxcui)
    set_id = spl.get("setid") if isinstance(spl, dict) else None

    lookup_name = matched_name or query
    label_record = await get_label_by_generic_or_brand_name(lookup_name)

    if label_record is None and matched_name and matched_name.lower() != query.lower():
        label_record = await get_label_by_generic_or_brand_name(query)

    sections = extract_label_sections(label_record or {})
    return rxcui, matched_name, sections, set_id


async def lookup_medicine_information(
    *,
    query: str,
    search_mode: str = "name",
    identification_reason: str | None = None,
) -> MedicineInformationResponse:
    normalized_query = query.strip()
    if not normalized_query:
        raise HTTPException(status_code=400, detail="Drug name is required")

    rxcui, matched_name, sections, set_id = await _resolve_label_and_identity(normalized_query)
    generic_name = sections["generic_name"][0] if sections["generic_name"] else None
    active_ingredients = (
        sections["active_ingredients"]
        or ([generic_name] if generic_name else ([matched_name] if matched_name else []))
    )
    related = await get_related_concepts_by_type(rxcui, RELATED_TERM_TYPES)
    alternatives = _collect_alternatives(related, normalized_query, matched_name)

    return MedicineInformationResponse(
        query=normalized_query,
        search_mode="image" if search_mode == "image" else "name",
        medicine_name=matched_name or normalized_query,
        matched_name=matched_name,
        generic_name=generic_name,
        brand_names=_unique_strings(sections["brand_names"]),
        active_ingredients=_unique_strings(active_ingredients),
        used_for=_unique_strings(sections["uses"]),
        dose=_unique_strings(sections["dosage_notes"]),
        warnings=_build_warning_items(sections),
        side_effects=_unique_strings(sections["side_effects"]),
        interactions=_unique_strings(sections["interactions"]),
        alternatives=alternatives,
        storage=_unique_strings(sections["storage"]),
        disclaimer=_build_disclaimer_items(sections),
        identification_reason=identification_reason,
        rxcui=rxcui,
        set_id=set_id,
    )


async def _identify_medicine_name_from_image(
    *,
    file_bytes: bytes,
    content_type: str,
) -> tuple[str, str | None]:
    settings = get_settings()
    client = get_xai_client()

    encoded_image = base64.b64encode(file_bytes).decode("ascii")
    image_url = f"data:{content_type};base64,{encoded_image}"

    try:
        response = await asyncio.to_thread(
            client.responses.create,
            model=settings.xai_model,
            input=[
                {
                    "role": "system",
                    "content": (
                        "You identify medicine names from package, bottle, blister pack, and pill photos. "
                        "Use only text or markings that are visible in the image. "
                        "If the medicine cannot be identified confidently, return medicine_name as null and explain why."
                    ),
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_text",
                            "text": (
                                "Identify the medicine in this image. Return a brand or generic medicine name that can be used for a drug database lookup."
                            ),
                        },
                        {
                            "type": "input_image",
                            "image_url": image_url,
                            "detail": "high",
                        },
                    ],
                },
            ],
            text={
                "format": {
                    "type": "json_schema",
                    "name": "medicine_image_identification",
                    "schema": {
                        "type": "object",
                        "properties": {
                            "medicine_name": {
                                "type": ["string", "null"],
                            },
                            "confidence": {
                                "type": "string",
                                "enum": ["low", "medium", "high"],
                            },
                            "reason": {
                                "type": ["string", "null"],
                            },
                        },
                        "required": ["medicine_name", "confidence", "reason"],
                        "additionalProperties": False,
                    },
                    "strict": True,
                },
            },
            store=False,
        )
    except (APIConnectionError, APITimeoutError, APIStatusError, APIError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Image search could not reach the Grok recognition service.",
        ) from exc

    try:
        output_text = response_output_text(response)
        if not output_text:
            raise ValueError("Missing output text")
        parsed = json.loads(output_text)
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Image search returned an invalid recognition response.",
        ) from exc

    medicine_name = str(parsed.get("medicine_name") or "").strip()
    confidence = str(parsed.get("confidence") or "").strip().lower()
    reason = str(parsed.get("reason") or "").strip() or None

    if not medicine_name or confidence == "low":
        detail = reason or "The image was too unclear to identify the medicine confidently."
        raise HTTPException(status_code=422, detail=detail)

    return medicine_name, reason


async def lookup_medicine_information_from_image(
    *,
    file_bytes: bytes,
    content_type: str,
) -> MedicineInformationResponse:
    medicine_name, reason = await _identify_medicine_name_from_image(
        file_bytes=file_bytes,
        content_type=content_type,
    )
    return await lookup_medicine_information(
        query=medicine_name,
        search_mode="image",
        identification_reason=reason,
    )
