"""Thin async client for OpenRouter.ai.

Keeps all outbound AI traffic in one place. The Go API is the public gateway;
this service is called internally by it.
"""
from __future__ import annotations

import httpx

from .settings import settings


class OpenRouterError(RuntimeError):
    pass


def _headers() -> dict[str, str]:
    if not settings.openrouter_api_key:
        raise OpenRouterError("OPENROUTER_API_KEY is not set")
    return {
        "Authorization": f"Bearer {settings.openrouter_api_key}",
        "Content-Type": "application/json",
        # Optional attribution headers recommended by OpenRouter.
        "X-Title": "SHOW",
    }


async def chat_completion(model: str, messages: list[dict]) -> dict:
    """Call the chat/completions endpoint (used by Prompt Generator)."""
    url = f"{settings.openrouter_base_url}/chat/completions"
    payload = {"model": model, "messages": messages}
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(url, headers=_headers(), json=payload)
    if resp.status_code >= 400:
        raise OpenRouterError(f"{resp.status_code}: {resp.text}")
    return resp.json()


async def generate_image(model: str, prompt: str, images: list[str] | None = None) -> dict:
    """Text-to-image, or image-to-image when [images] (data URLs / https) are set.

    Uses OpenRouter's Image API (`POST /images`). Chat completions + modalities
    404s for these models: "No endpoints found that support the requested
    output modalities: image, text".
    """
    url = f"{settings.openrouter_base_url}/images"
    payload: dict = {"model": model, "prompt": prompt}
    if images:
        payload["input_references"] = [
            {"type": "image_url", "image_url": {"url": img}} for img in images
        ]
    async with httpx.AsyncClient(timeout=180) as client:
        resp = await client.post(url, headers=_headers(), json=payload)
    if resp.status_code >= 400:
        raise OpenRouterError(f"{resp.status_code}: {resp.text}")
    return resp.json()
