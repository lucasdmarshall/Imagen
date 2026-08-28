"""SHOW AI service — FastAPI.

Handles the two AI-backed operations behind the app's two modes:
  - Prompt Generator  -> POST /prompts/generate
  - Image Generator   -> POST /images/generate  (model: nano_banana_pro | gpt_image)

All model calls go through OpenRouter.ai. This service is internal; the Go API
is the public gateway.
"""
from __future__ import annotations

from enum import Enum

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from . import openrouter
from .settings import settings

app = FastAPI(title="SHOW AI Service", version="0.1.0")


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "env": settings.app_env,
        "openrouter_key_configured": bool(settings.openrouter_api_key),
    }


# --- Prompt Generator ---------------------------------------------------------


class Perimeter(BaseModel):
    """A pixel-perfect region the user assigns a sub-prompt to."""

    label: str
    x: float
    y: float
    width: float
    height: float
    prompt: str


class PromptModel(str, Enum):
    gemini_flash = "gemini_flash"  # google/gemini-3.7-flash
    gpt_luna = "gpt_luna"  # openai/gpt-5.6-luna
    gpt_mini = "gpt_mini"  # openai/gpt-5-mini


class PromptRequest(BaseModel):
    base_prompt: str = Field(..., description="Global prompt for the whole image.")
    perimeters: list[Perimeter] = Field(default_factory=list)
    model: PromptModel | None = Field(
        default=None, description="Text model; defaults to server default."
    )


@app.post("/prompts/generate")
async def generate_prompt(req: PromptRequest) -> dict:
    """Compose a structured, perimeter-aware prompt via the chosen text model."""
    model_id = {
        PromptModel.gemini_flash: settings.prompt_model_gemini_flash,
        PromptModel.gpt_luna: settings.prompt_model_gpt_luna,
        PromptModel.gpt_mini: settings.prompt_model_gpt_mini,
    }.get(req.model, settings.prompt_model_default)
    system = (
        "You are SHOW's prompt engine. Compose one precise image prompt that "
        "respects each labeled perimeter region and its per-region instruction."
    )
    regions = "\n".join(
        f"- {p.label} @({p.x},{p.y},{p.width}x{p.height}): {p.prompt}"
        for p in req.perimeters
    )
    user = f"Base prompt: {req.base_prompt}\nPerimeters:\n{regions or '(none)'}"

    try:
        result = await openrouter.chat_completion(
            model_id,
            [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
    except openrouter.OpenRouterError as e:
        raise HTTPException(status_code=502, detail=str(e)) from e
    return result


# --- Image Generator ----------------------------------------------------------


class ImageModel(str, Enum):
    nano_banana_pro = "nano_banana_pro"  # Gemini 3.1 Flash
    gpt_image = "gpt_image"  # GPT image model


class ImageRequest(BaseModel):
    prompt: str
    model: ImageModel = ImageModel.nano_banana_pro
    # Data URLs (data:<mime>;base64,…) of input photos. When present the request
    # is an image EDIT (effect pages); otherwise plain text-to-image.
    images: list[str] = Field(default_factory=list)


def _normalize_image(raw: dict) -> dict:
    """Reduce a chat-completions image response to {"data": [{"url": …}]} so the
    client parses edit and text-to-image results the same way."""
    try:
        msg = raw["choices"][0]["message"]
    except (KeyError, IndexError, TypeError):
        return raw
    if isinstance(msg, dict):
        for img in msg.get("images") or []:
            u = (img.get("image_url") or {}).get("url") or img.get("url")
            if u:
                return {"data": [{"url": u}]}
        content = msg.get("content")
        if isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "image_url":
                    u = (part.get("image_url") or {}).get("url")
                    if u:
                        return {"data": [{"url": u}]}
    return raw


@app.post("/images/generate")
async def generate_image(req: ImageRequest) -> dict:
    model_id = {
        ImageModel.nano_banana_pro: settings.image_model_nano_banana_pro,
        ImageModel.gpt_image: settings.image_model_gpt_image,
    }[req.model]

    try:
        if req.images:
            raw = await openrouter.generate_image_edit(
                model_id, req.prompt, req.images
            )
            return _normalize_image(raw)
        result = await openrouter.generate_image(model_id, req.prompt)
    except openrouter.OpenRouterError as e:
        raise HTTPException(status_code=502, detail=str(e)) from e
    return result
