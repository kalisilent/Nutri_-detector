"""Unit tests for the OCR text parsers — pure functions, no infra needed."""
from app.services.ocr.parsers import (detect_panel_type, parse_ingredients,
                                      parse_nutrition)


class TestPanelDetection:
    def test_nutrition_panel(self):
        text = "Nutrition Facts Serving size 30g Calories 150 Total Fat 8g daily value"
        assert detect_panel_type(text) == "nutrition"

    def test_ingredients_panel(self):
        text = "INGREDIENTS: wheat flour, sugar, palm oil, salt"
        assert detect_panel_type(text) == "ingredients"

    def test_both(self):
        text = ("Nutrition Facts Calories 150 Total Fat 8g serving size "
                "INGREDIENTS: wheat flour, sugar")
        assert detect_panel_type(text) == "both"

    def test_comma_fallback(self):
        text = "wheat flour, sugar, palm oil, cocoa, salt"
        assert detect_panel_type(text) == "ingredients"

    def test_unknown(self):
        assert detect_panel_type("hello world") == "unknown"


class TestIngredientParsing:
    def test_basic_split(self):
        tokens, e_nums = parse_ingredients(
            "INGREDIENTS: WHEAT FLOUR, SUGAR, PALM OIL, SALT")
        assert "wheat flour" in tokens
        assert "sugar" in tokens
        assert e_nums == []

    def test_e_number_extraction(self):
        tokens, e_nums = parse_ingredients(
            "INGREDIENTS: SUGAR, RAISING AGENTS (E500, E503), LECITHIN (E322)")
        assert set(e_nums) == {"E500", "E503", "E322"}

    def test_percentage_removal(self):
        tokens, _ = parse_ingredients("INGREDIENTS: COCOA POWDER (10%), SUGAR")
        assert "cocoa powder" in tokens

    def test_no_numeric_tokens(self):
        tokens, _ = parse_ingredients("INGREDIENTS: SUGAR, 12345, SALT")
        assert "12345" not in tokens


class TestNutritionParsing:
    SAMPLE = ("Nutrition Facts Calories 245 Total Fat 12g Saturated Fat 2g "
              "Total Carbohydrate 37 Dietary Fiber 7g Total Sugars 5g "
              "Protein 11g Sodium 210mg")

    def test_extracts_core_nutrients(self):
        n = parse_nutrition(self.SAMPLE)
        assert n["fat_100g"] == 12
        assert n["saturated-fat_100g"] == 2
        assert n["fiber_100g"] == 7
        assert n["proteins_100g"] == 11

    def test_kcal_to_kj(self):
        n = parse_nutrition(self.SAMPLE)
        assert abs(n["energy_100g"] - 245 * 4.184) < 0.1

    def test_sodium_mg_to_g_and_salt_derived(self):
        n = parse_nutrition(self.SAMPLE)
        assert n["sodium_100g"] == 0.21
        assert n["salt_100g"] == round(0.21 * 2.5, 3)

    def test_empty_text(self):
        assert parse_nutrition("hello") == {}
