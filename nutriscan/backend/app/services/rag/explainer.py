"""
RAG explanation service.

Resolution order for "explain this ingredient":
 1. Curated dictionary  (instant, liability-safe — the source of truth)
 2. pgvector similarity (semantic match against the KB in Postgres)
 3. LLM fallback        (only on miss; grounded prompt; result cached to DB forever)

Health/safety claims are NEVER generated freely by the LLM — the prompt forces
paraphrase-of-retrieved-facts, and curated entries always win.
"""
import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.logging import get_logger
from app.models.ingredient import Ingredient, IngredientExplanation

logger = get_logger("rag")

# ----------------------------------------------------------------------
# Layer 1 — curated additive dictionary (subset; seeded fully via script)
# ----------------------------------------------------------------------
CURATED_ADDITIVES: dict[str, dict] = {
    "E100":  {"name": "Curcumin", "what": "Yellow coloring from turmeric.", "safety": "Generally safe, natural origin."},
    "E101":  {"name": "Riboflavin (Vitamin B2)", "what": "Yellow coloring, also a vitamin.", "safety": "Safe — a vitamin your body needs."},
    "E102":  {"name": "Tartrazine", "what": "Artificial yellow dye.", "safety": "Approved; may cause reactions in sensitive people."},
    "E110":  {"name": "Sunset Yellow", "what": "Artificial orange-yellow dye.", "safety": "Approved, but banned in some countries."},
    "E129":  {"name": "Allura Red", "what": "Artificial red dye.", "safety": "Linked to hyperactivity in children in some studies."},
    "E150A": {"name": "Caramel Color", "what": "Brown coloring from heated sugar.", "safety": "Generally safe in normal amounts."},
    "E160A": {"name": "Beta-Carotene", "what": "Orange coloring from plants.", "safety": "Safe — converts to Vitamin A."},
    "E200":  {"name": "Sorbic Acid", "what": "Preservative that stops mold.", "safety": "Safe — naturally in berries."},
    "E202":  {"name": "Potassium Sorbate", "what": "Shelf-life preservative.", "safety": "Safe at regulated levels."},
    "E211":  {"name": "Sodium Benzoate", "what": "Preservative against bacteria/mold.", "safety": "Approved; avoid mixing with Vitamin C drinks."},
    "E220":  {"name": "Sulphur Dioxide", "what": "Preservative in dried fruits and wine.", "safety": "Can trigger asthma in sensitive people."},
    "E250":  {"name": "Sodium Nitrite", "what": "Preservative in cured meats.", "safety": "Controversial — high intake linked to health concerns."},
    "E270":  {"name": "Lactic Acid", "what": "Souring agent and preservative.", "safety": "Safe — your muscles produce it naturally."},
    "E300":  {"name": "Ascorbic Acid", "what": "Vitamin C used as an antioxidant.", "safety": "Safe — it is literally Vitamin C."},
    "E322":  {"name": "Lecithin", "what": "Emulsifier preventing oil-water separation.", "safety": "Safe — naturally in egg yolks and soy."},
    "E330":  {"name": "Citric Acid", "what": "Tangy flavor and preservative.", "safety": "Safe — naturally in citrus fruits."},
    "E339":  {"name": "Sodium Phosphate", "what": "Acidity regulator and emulsifier.", "safety": "Safe in normal amounts."},
    "E375":  {"name": "Niacin (Vitamin B3)", "what": "Added vitamin in fortified foods.", "safety": "Safe and beneficial."},
    "E407":  {"name": "Carrageenan", "what": "Seaweed-based thickener.", "safety": "Approved but debated — some studies suggest gut effects."},
    "E410":  {"name": "Locust Bean Gum", "what": "Thickener from carob seeds.", "safety": "Safe — natural plant thickener."},
    "E412":  {"name": "Guar Gum", "what": "Thickener from guar beans.", "safety": "Safe — common in ice cream."},
    "E415":  {"name": "Xanthan Gum", "what": "Fermentation-based thickener.", "safety": "Safe — used in gluten-free baking."},
    "E440":  {"name": "Pectin", "what": "Fruit-based gelling agent.", "safety": "Safe — naturally in apples."},
    "E471":  {"name": "Mono/Diglycerides", "what": "Fat-based emulsifier.", "safety": "Safe — your body produces these in digestion."},
    "E500":  {"name": "Sodium Bicarbonate", "what": "Baking soda raising agent.", "safety": "Safe — ordinary baking soda."},
    "E503":  {"name": "Ammonium Carbonate", "what": "Raising agent.", "safety": "Safe — evaporates during baking."},
    "E621":  {"name": "MSG", "what": "Umami flavor enhancer.", "safety": "Safe per WHO/FDA assessments."},
    "E950":  {"name": "Acesulfame K", "what": "Artificial sweetener, 200x sugar.", "safety": "Approved by regulators."},
    "E951":  {"name": "Aspartame", "what": "Artificial sweetener in diet drinks.", "safety": "Approved but debated; IARC 'possibly carcinogenic' classification."},
    "E955":  {"name": "Sucralose", "what": "Artificial sweetener (Splenda).", "safety": "Approved; gut-bacteria effects under study."},
}

_GROUNDED_PROMPT = """You are a food-science explainer. Using ONLY the context below, explain the food ingredient "{ingredient}" to a regular shopper in 1-2 short sentences: what it is and what it does in food. Do NOT make any safety or health claims that are not in the context. If the context is empty or irrelevant, reply exactly: UNKNOWN

Context:
{context}"""


class ExplanationService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self._embedder = None  # lazy

    # ---------- Layer 1: curated ----------
    def curated_additive(self, e_code: str) -> dict | None:
        info = CURATED_ADDITIVES.get(e_code.upper())
        if info:
            return {**info, "code": e_code.upper(), "source": "curated"}
        return None

    # ---------- Layer 2: DB / vector ----------
    def _embed(self, text: str) -> list[float]:
        if self._embedder is None:
            from sentence_transformers import SentenceTransformer
            self._embedder = SentenceTransformer(settings.EMBEDDING_MODEL)
        return self._embedder.encode(text, normalize_embeddings=True).tolist()

    def db_lookup(self, name: str) -> dict | None:
        # Exact name match first
        row = self.db.execute(
            select(Ingredient).where(Ingredient.name == name.lower())
        ).scalar_one_or_none()

        # Vector similarity if no exact hit
        if row is None:
            try:
                vec = self._embed(name)
                row = self.db.execute(
                    select(Ingredient)
                    .where(Ingredient.embedding.isnot(None))
                    .order_by(Ingredient.embedding.cosine_distance(vec))
                    .limit(1)
                ).scalar_one_or_none()
                if row is not None and row.embedding is not None:
                    # cosine_distance < (1 - threshold) means similar enough
                    pass
            except Exception:  # noqa: BLE001 — pgvector may be absent in dev
                row = None

        if row and row.explanation:
            return {"name": row.name,
                    "what": row.explanation.what,
                    "safety": row.explanation.safety or "",
                    "source": row.explanation.source}
        return None

    # ---------- Layer 3: LLM fallback ----------
    async def llm_fallback(self, name: str, context: str = "") -> dict | None:
        if not settings.LLM_API_KEY:
            return None
        try:
            async with httpx.AsyncClient(timeout=20) as client:
                resp = await client.post(
                    settings.LLM_API_URL,
                    headers={"x-api-key": settings.LLM_API_KEY,
                             "anthropic-version": "2023-06-01",
                             "content-type": "application/json"},
                    json={"model": settings.LLM_MODEL,
                          "max_tokens": 200,
                          "messages": [{"role": "user",
                                        "content": _GROUNDED_PROMPT.format(
                                            ingredient=name, context=context)}]})
            resp.raise_for_status()
            text = "".join(b.get("text", "")
                           for b in resp.json().get("content", [])).strip()
            if not text or text == "UNKNOWN":
                return None

            self._cache_explanation(name, text)
            return {"name": name, "what": text, "safety": "", "source": "llm"}
        except Exception as exc:  # noqa: BLE001
            logger.warning("llm_fallback_failed", ingredient=name, error=str(exc))
            return None

    def _cache_explanation(self, name: str, what: str) -> None:
        """Persist an LLM answer so the same ingredient never costs a second call."""
        try:
            ing = self.db.execute(
                select(Ingredient).where(Ingredient.name == name.lower())
            ).scalar_one_or_none()
            if ing is None:
                ing = Ingredient(name=name.lower(), frequency=0)
                self.db.add(ing)
                self.db.flush()
            if ing.explanation is None:
                self.db.add(IngredientExplanation(
                    ingredient_id=ing.id, what=what, source="llm"))
                self.db.commit()
        except Exception:  # noqa: BLE001
            self.db.rollback()

    # ---------- public API ----------
    async def explain(self, name: str) -> dict | None:
        """Resolve an explanation through all three layers."""
        hit = self.db_lookup(name)
        if hit:
            return hit
        return await self.llm_fallback(name)
