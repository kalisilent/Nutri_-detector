"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-06-12
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255)),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("is_admin", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "scans",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("image_url", sa.String(1024)),
        sa.Column("panel_type", sa.String(20), server_default="unknown"),
        sa.Column("grade", sa.CHAR(1)),
        sa.Column("grade_confidence", sa.Float()),
        sa.Column("nutrients", postgresql.JSONB()),
        sa.Column("ingredients", postgresql.JSONB()),
        sa.Column("additives", postgresql.JSONB()),
        sa.Column("raw_ocr", sa.String()),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_scans_user_created", "scans", ["user_id", "created_at"])

    op.create_table(
        "ingredients",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("e_number", sa.String(10)),
        sa.Column("frequency", sa.Integer(), server_default="0"),
        sa.Column("embedding", postgresql.ARRAY(sa.Float()), nullable=True),
    )
    op.execute("ALTER TABLE ingredients ALTER COLUMN embedding TYPE vector(384) "
               "USING embedding::vector(384)")
    op.create_index("ix_ingredients_name", "ingredients", ["name"], unique=True)
    op.create_index("ix_ingredients_e_number", "ingredients", ["e_number"])

    op.create_table(
        "ingredient_explanations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("ingredient_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("ingredients.id", ondelete="CASCADE"),
                  nullable=False, unique=True),
        sa.Column("what", sa.Text(), nullable=False),
        sa.Column("safety", sa.Text()),
        sa.Column("source", sa.String(50), server_default="curated"),
    )

    op.create_table(
        "saved_products",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("scan_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("scans.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", sa.String(255)),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.text("now()")),
        sa.UniqueConstraint("user_id", "scan_id", name="uq_saved_user_scan"),
    )


def downgrade() -> None:
    op.drop_table("saved_products")
    op.drop_table("ingredient_explanations")
    op.drop_table("ingredients")
    op.drop_table("scans")
    op.drop_table("users")
