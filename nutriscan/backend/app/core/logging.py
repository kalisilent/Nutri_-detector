"""Structured JSON logging — Cloud Logging parses JSON automatically."""
import logging
import sys

import structlog

from app.core.config import settings


def setup_logging() -> None:
    logging.basicConfig(stream=sys.stdout,
                        level=logging.DEBUG if settings.DEBUG else logging.INFO,
                        format="%(message)s")
    structlog.configure(
        processors=[
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.add_log_level,
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.DEBUG if settings.DEBUG else logging.INFO),
    )


def get_logger(name: str):
    return structlog.get_logger(name)
