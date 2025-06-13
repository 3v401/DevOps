"""
Web Server and App entry point

1. Create a web API with FastAPI
2. Connect all defined endpoints (routes)
3. Run server
"""

from fastapi import FastAPI
from routes import router

app = FastAPI(
    title = "ThreatGPT",
    description = "Patch threats, predict behaviors and explain inputs using AI",
    version = "0.1"
)

app.include_router(router)