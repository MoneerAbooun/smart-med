from pathlib import Path
from uuid import uuid4

from app.core.config import _load_dotenv_file, _setting_value


def test_load_dotenv_file_parses_comments_and_quotes():
    dotenv_path = Path(__file__).resolve().parent / f".tmp-config-{uuid4().hex}.env"
    try:
        dotenv_path.write_text(
            "\n".join(
                [
                    "# comment",
                    "XAI_API_KEY=test-key",
                    "XAI_MODEL='grok-4.20-reasoning'",
                    'XAI_BASE_URL="https://api.x.ai/v1"',
                ]
            ),
            encoding="utf-8",
        )

        values = _load_dotenv_file(dotenv_path)

        assert values["XAI_API_KEY"] == "test-key"
        assert values["XAI_MODEL"] == "grok-4.20-reasoning"
        assert values["XAI_BASE_URL"] == "https://api.x.ai/v1"
    finally:
        dotenv_path.unlink(missing_ok=True)


def test_setting_value_prefers_process_environment(monkeypatch):
    monkeypatch.setenv("XAI_API_KEY", "from-env")

    assert (
        _setting_value(
            "XAI_API_KEY",
            {"XAI_API_KEY": "from-dotenv"},
            "fallback",
        )
        == "from-env"
    )
