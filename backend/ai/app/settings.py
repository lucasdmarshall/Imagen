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

    # Text models selectable in the Prompt Generator mode.
    prompt_model_gemini_flash: str = "google/gemini-3.7-flash"
    prompt_model_gpt_luna: str = "openai/gpt-5.6-luna"
    prompt_model_gpt_mini: str = "openai/gpt-5-mini"
    # Default when the client doesn't specify one.
    prompt_model_default: str = "google/gemini-3.7-flash"

    # Image model ids.
    #   "nano_banana_pro" -> Gemini 3 Pro Image "Nano Banana Pro"
    #   "gpt_image"       -> GPT Image 2
    image_model_nano_banana_pro: str = "google/gemini-3-pro-image-preview"
    image_model_gpt_image: str = "openai/gpt-image-2"

    app_env: str = "development"


settings = Settings()
