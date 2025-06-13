"""
AI core logic.

Data is sent to an AI model.
"""

import re, os
from openai import OpenAI
from models import ThreatRequest, ThreatResponse
from dotenv import load_dotenv

load_dotenv() # Load variables from .env
client = OpenAI()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def analyze_threat(request: ThreatRequest) -> ThreatResponse:

    """
    Creates a prompt from the user's data

    'request': input of funtion
    'ThreatResponse': output (another model)
    """

    prompt = f"""
    You are a cybersecurity expert.
    Analyze the following {request.input_type} for security threats and output the result in this format:

    Threat Level: [High | Medium | Low | None]
    Explanation: <Explain the Threat>
    Prediction: <Explain what can happen next>
    Patch: <Specific code sugestion to fix the issue>

    Input:
    {request.content}
    """

    completion = client.chat.completions.create(
        model = "gpt-4o",
        messages = [
            {"role": "system", "content": "You are a cybersecurity expert."},
            {"role": "user", "content": prompt}
        ]
    )

    gpt_text = completion.choices[0].message.content
    parsed = parse_gpt_response(gpt_text)

    return ThreatResponse(
        threat_level = parsed['threat_level'],
        explanation = parsed['explanation'],
        prediction = parsed['prediction'],
        patch_suggestion = {
            "type": request.input_type,
            "snippet": parsed['patch_snippet']
        }
    )

def parse_gpt_response(text):

    """
    Meaning of keywords:

    r'': Raw string in between. Don't interpret \ as an escape
    \s*: Match zero or more whitespaces/tabs/newlines
    (/\+): Match words/digits/underscores and capture it
    .group(1): Get the first captured match

    """
    
    level_match = re.search(r'Threat Level:\s*(\w+)', text)
    explanation_match = re.search(r'Explanation:\s*(.*)', text)
    prediction_match = re.search(r'Prediction:\s*(.*)', text)
    patch_match = re.search(r'Patch:\s*(.*)', text)

    return {
        "threat_level": level_match.group(1) if level_match else None,
        "explanation": explanation_match.group(1) if explanation_match else "No explanation possible",
        "prediction": prediction_match.group(1) if prediction_match else "No prediction possible",
        "patch_snippet": patch_match.group(1) if patch_match else "No patch possible" 
    }