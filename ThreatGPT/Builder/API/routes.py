"""
Here the URL endpoints are defined.

Accepts the input defined in ThreatRequest
Runs 'analyze_threat()' from ai_core.py
Returns output in JSON structure
"""

from fastapi import APIRouter, UploadFile, File, Form
from models import ThreatRequest, ThreatResponse
from ai_core import analyze_threat

router = APIRouter()

# Python decorator: It is how a POST API endpoint is defined in FastAPI
@router.post("/analyze", response_model = ThreatResponse)
async def analyze(    
    input_type: str = Form(...),    # Mandatory, receives in string format input type
    content: str = Form(None),      # Optionally, receives in string format additional info
    file: UploadFile = File(None)   # Optionally receives a file upload
):

    """
    It tells FastAPI this function is triggred (analyze) when someone sends POST to '/analyze' route
    'async' makes functions asynchronous: Allows the server to handle many requests at once without blocking.
    'request: ThreatRequest' data sent by the user, previously validated by Pydantic
    """

    if file:
        # If a file is provided, read its contents and decode it to a string to store it in content variable
        content_bytes = await file.read()
        content = content_bytes.decode("utf-8")

    request = ThreatRequest(input_type = input_type, content = content)
    return analyze_threat(request)
