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


async def generate_image(model: str, prompt: str) -> dict:
    """Call the image generation endpoint (used by Image Generator)."""
    url = f"{settings.openrouter_base_url}/images/generations"
    payload = {"model": model, "prompt": prompt}
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(url, headers=_headers(), json=payload)
    if resp.status_code >= 400:
        raise OpenRouterError(f"{resp.status_code}: {resp.text}")
    return resp.json()
