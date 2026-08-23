"""Runtime configuration for the SHOW AI service.

All values come from the environment (see .env.example). Never hardcode the
OpenRouter key.
"""
from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    openrouter_api_key: str = ""
    openrouter_base_url: str = "https://openrouter.ai/api/v1"

    # Text model used by the Prompt Generator mode.
    prompt_model: str = "openai/gpt-4o-mini"

    # Image model ids. NOTE: confirm exact OpenRouter ids (PROJECT_OVERVIEW §8).
    #   "nano_banana_pro" -> Gemini 3.1 Flash "Nano Banana Pro"
    #   "gpt_image"       -> GPT image model ("GPT 2 image")
    image_model_nano_banana_pro: str = "google/gemini-3.1-flash-image"
    image_model_gpt_image: str = "openai/gpt-image-1"

    app_env: str = "development"


settings = Settings()
