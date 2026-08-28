# SHOW Python AI service — FastAPI on uvicorn.
FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install deps first for layer caching.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# App code.
COPY app ./app

# Run as a non-root user.
RUN useradd -m -u 10001 app
USER app

EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)" || exit 1
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
