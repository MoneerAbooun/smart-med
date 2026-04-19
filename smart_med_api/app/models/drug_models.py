from pydantic import BaseModel, Field


class DrugDetailsResponse(BaseModel):
    query: str
    matched_name: str | None = None
    generic_name: str | None = None
    brand_names: list[str] = Field(default_factory=list)
    active_ingredients: list[str] = Field(default_factory=list)
    uses: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    side_effects: list[str] = Field(default_factory=list)
    dosage_notes: list[str] = Field(default_factory=list)
    contraindications: list[str] = Field(default_factory=list)
    source: str = "rxnorm+dailymed+openfda"
    rxcui: str | None = None
    set_id: str | None = None
