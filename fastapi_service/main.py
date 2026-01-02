# this is the fastapi service that provides ai chat functionality
# when you ask a question in the dashboard, rails calls this service
# this service uses ollama (local ai) to answer questions about health data
# it uses langchain to query the oracle database and generate answers

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import os
from dotenv import load_dotenv
import logging

# import our llm service (handles ai and database queries)
from llm_service import LLMService

# load environment variables from .env file
load_dotenv()

# set up logging so we can see what's happening
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# create the fastapi web application
app = FastAPI(
    title="Health Radar LLM Service",
    description="LLM-powered chat service for health data queries",
    version="1.0.0"
)

# allow rails app to call this service (cors = cross-origin resource sharing)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # in production, you'd restrict this to specific domains
    allow_credentials=True,
    allow_methods=["*"],  # allow all http methods
    allow_headers=["*"],  # allow all headers
)

# initialize the llm service (this connects to ollama and sets up langchain tools)
llm_service = LLMService()

# define what the request and response look like
class ChatRequest(BaseModel):
    query: str  # the question the user asked
    context: Optional[Dict[str, Any]] = None  # optional context like zip_code or date_range

class ChatResponse(BaseModel):
    response: str  # the ai's answer
    sources: Optional[list] = None  # which data sources were used
    query_time_ms: Optional[float] = None  # how long it took to answer

# endpoint to check if service is running
@app.get("/health")
async def health():
    """check if service is healthy"""
    return {"status": "healthy", "service": "llm-service"}

# main endpoint: receives questions and returns ai answers
@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    this is the main chat endpoint
    when rails sends a question, this method:
    1. receives the question
    2. uses langchain to figure out which database tables to query
    3. queries oracle database to get real data
    4. uses ollama (local ai) to generate a natural language answer
    5. returns the answer with the data
    """
    try:
        logger.info(f"Received chat query: {request.query}")
        
        # send the question to the llm service
        # the llm service will:
        # - parse the question to understand what data is needed
        # - query the oracle database using langchain tools
        # - use ollama to generate a natural language response
        result = await llm_service.process_query(
            query=request.query,  # the user's question
            context=request.context or {}  # any additional context
        )
        
        # return the answer
        return ChatResponse(
            response=result["response"],  # the ai's answer
            sources=result.get("sources", []),  # which data sources were used
            query_time_ms=result.get("query_time_ms")  # how long it took
        )
        
    except Exception as e:
        # if something goes wrong, log the error and return error message
        logger.error(f"Error processing chat query: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing query: {str(e)}")

# metrics endpoint (for prometheus)
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

