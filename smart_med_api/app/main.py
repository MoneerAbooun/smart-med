from fastapi import FastAPI

from app.routers.drug_details import router as drug_details_router
from app.routers.drug_interaction import router as drug_interaction_router

app = FastAPI(
    title="Smart Med API",
    version="0.3.0",
    description="Drug details and interaction backend for Smart Med.",
)

app.include_router(drug_details_router)
app.include_router(drug_interaction_router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"message": "Smart Med API is running"}
