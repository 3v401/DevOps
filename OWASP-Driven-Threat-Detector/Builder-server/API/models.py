"""
Data models with Pydantic.

Defines the structure of input and output.
This ensures the incoming data is correct before AI receives it.
This way the AI model will receive structured input and return predictable output.
"""

from pydantic import BaseModel

class ThreatRequest(BaseModel):
    input_type: str
    content: str

class ThreatResponse(BaseModel):
    threat_level: str
    explanation: str
    prediction: str
    patch_suggestion: dict