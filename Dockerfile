# Roof material classification API with the Production model baked in.
#   docker build -t roof-api .
#   docker run --rm -p 8000:8000 roof-api
# Optional: -v /path/to/orthophotos:/rasters:ro -e RASTER_DIR=/rasters
#           -v roof-logs:/app/logs   (keep the prediction log for monitoring)
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DEFAULT_TIMEOUT=1000 \
    MODEL_DIR=/app/models/production \
    PREDICTION_LOG=/app/logs/predictions.jsonl

# libgomp1 is needed by LightGBM and CatBoost; libexpat1 is needed by rasterio.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 \
        libexpat1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Stage 1: Fast & lightweight Web / API dependencies
RUN pip install --no-cache-dir --default-timeout=1000 --retries 10 \
    fastapi==0.162.0 \
    uvicorn==0.54.0 \
    pydantic==2.14.1 \
    python-multipart==0.0.32 \
    PyYAML==6.0.3 \
    joblib==1.6.0 \
    affine==3.0.1 \
    pillow==13.0.0

# Stage 2: GIS & Geometry
RUN pip install --no-cache-dir --default-timeout=1000 --retries 10 \
    shapely==2.2.0 \
    rasterio==1.5.2

# Stage 3: Data & ML frameworks
RUN pip install --no-cache-dir --default-timeout=1000 --retries 10 \
    numpy==2.4.6 \
    pandas==3.1.0 \
    scipy \
    scikit-learn==1.9.1 \
    scikit-image==0.26.0

# Stage 4: Gradient boosting models
RUN pip install --no-cache-dir --default-timeout=1000 --retries 10 \
    lightgbm==4.7.0 \
    catboost==1.2.10

COPY params.yaml .
COPY src/ src/
COPY api/ api/
COPY web/ web/
COPY models/ models/

RUN useradd --create-home --uid 1000 app && mkdir -p /app/logs && chown -R app /app/logs
USER app

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(urllib.request.urlopen('http://localhost:8000/health').status != 200)"

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
