"""
Parsers that turn raw OCR text into structured data.
Ported directly from the validated notebook pipeline.
"""
import re


def detect_panel_type(raw_text: str) -> str:
    """Classify OCR text as 'nutrition' | 'ingredients' | 'both' | 'unknown'."""
    text = raw_text.lower()

    nutrition_kw = ["nutrition facts", "calories", "total fat",
                    "serving size", "daily value", "amount per serving"]
    ingredient_kw = ["ingredients:", "ingredients :", "contains:", "may contain"]

    n_score = sum(1 for kw in nutrition_kw if kw in text)
    i_score = sum(1 for kw in ingredient_kw if kw in text)

    if n_score >= 2 and i_score >= 1:
        return "both"
    if n_score >= 2:
        return "nutrition"
    if i_score >= 1:
        return "ingredients"
    if text.count(",") > 3:
        return "ingredients"
    return "unknown"


def parse_ingredients(raw_text: str) -> tuple[list[str], list[str]]:
    """Return (ingredient_tokens, e_numbers) from OCR text."""
    text = raw_text.lower()

    for marker in ("ingredients:", "ingredients :", "contains:"):
        if marker in text:
            text = text[text.index(marker) + len(marker):]
            break

    e_numbers = [e.upper() for e in re.findall(r"E\d{3}[a-z]?", text, re.IGNORECASE)]

    text = re.sub(r"\(?\d+\.?\d*\s*%\)?", "", text)          # strip percentages
    text = re.sub(r"\[.*?\]|\(.*?\)", "", text)              # strip brackets

    cleaned: list[str] = []
    for part in re.split(r"[,;.]", text):
        part = part.strip(" :*-_/\\0123456789%")
        part = re.sub(r"^and\s+", "", part)
        if 2 < len(part) <= 50 and not part.replace(" ", "").isdigit():
            cleaned.append(part)

    return cleaned, e_numbers


# (column_name, [regex patterns in priority order])
_NUTRIENT_PATTERNS: dict[str, list[str]] = {
    "energy_100g":        [r"calories\s*(\d+)", r"energy\s*(\d+)"],
    "fat_100g":           [r"total\s*fat\s*(\d+\.?\d*)\s*g"],
    "saturated-fat_100g": [r"saturated\s*fat\s*(\d+\.?\d*)\s*g"],
    "carbohydrates_100g": [r"total\s*carbohydr?a?t?e?s?\s*(\d+\.?\d*)",
                           r"carbohydr?a?t?e?s?\s*(\d+\.?\d*)"],
    "sugars_100g":        [r"total\s*sugars?\s*(\d+\.?\d*)",
                           r"sugars?\s*(\d+\.?\d*)\s*g"],
    "fiber_100g":         [r"(?:dietary\s*)?fiber\s*(\d+\.?\d*)\s*g"],
    "proteins_100g":      [r"prote?a?in\s*(\d+\.?\d*)\s*g"],
    "salt_100g":          [r"salt\s*(\d+\.?\d*)\s*g"],
    "sodium_100g":        [r"sodium\s*(\d+\.?\d*)\s*m?g"],
}


def parse_nutrition(raw_text: str) -> dict[str, float]:
    """Extract nutrient values per 100g from Nutrition Facts OCR text."""
    text = raw_text.lower()
    extracted: dict[str, float] = {}

    for col, regexes in _NUTRIENT_PATTERNS.items():
        for pattern in regexes:
            match = re.search(pattern, text)
            if match:
                val = float(match.group(1))
                if col == "energy_100g" and val < 1000:
                    val *= 4.184                       # kcal → kJ
                if col == "sodium_100g" and val > 5:
                    val /= 1000                        # mg → g
                extracted[col] = val
                break

    if "sodium_100g" in extracted and "salt_100g" not in extracted:
        extracted["salt_100g"] = round(extracted["sodium_100g"] * 2.5, 3)

    return extracted
