# llm service - langchain + ollama integration
# this service orchestrates langchain tools for oracle database queries
# and ollama for local llm inference (free, no api costs)
# it uses langchain's tool system to parse queries, execute database queries,
# format results, and generate natural language explanations

import os
import time
import logging
from typing import Dict, Any, List, Optional
import cx_Oracle
from langchain.tools import Tool
from langchain.agents import initialize_agent, AgentType
from langchain_community.llms import Ollama
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
from prometheus_client import Histogram, Counter

logger = logging.getLogger(__name__)

# prometheus metrics
LLM_QUERY_DURATION = Histogram(
    'llm_query_duration_seconds',
    'Duration of LLM query processing in seconds',
    ['query_type']
)

LLM_QUERIES_TOTAL = Counter(
    'llm_queries_total',
    'Total LLM queries processed',
    ['status']
)

# oracle database connection
def get_oracle_connection():
    """Get Oracle database connection"""
    # Connection string format: username/password@host:port/database
    db_url = os.getenv('DATABASE_URL', 'system/healthsignal123@oracle:1521/HEALTHSIGNAL')
    
    # Parse connection string
    # Format: oracle-enhanced://username:password@host:port/database
    if db_url.startswith('oracle-enhanced://'):
        db_url = db_url.replace('oracle-enhanced://', '')
    
    parts = db_url.split('@')
    if len(parts) == 2:
        user_pass = parts[0].split(':')
        host_db = parts[1].split('/')
        if len(host_db) == 2:
            host_port = host_db[0].split(':')
            username = user_pass[0]
            password = user_pass[1] if len(user_pass) > 1 else ''
            host = host_port[0]
            port = host_port[1] if len(host_port) > 1 else '1521'
            database = host_db[1]
            
            dsn = cx_Oracle.makedsn(host, port, service_name=database)
            return cx_Oracle.connect(username, password, dsn)
    
    raise ValueError(f"Invalid DATABASE_URL format: {db_url}")

# langchain tools for oracle queries
# these tools allow the llm to query the oracle database
# each tool represents a specific data source or query type

def query_air_quality(zip_code: str, days: int = 30) -> str:
    """
    Query air quality data (PM2.5, O3) for a ZIP code.
    
    Args:
        zip_code: 5-digit ZIP code
        days: Number of days to look back (default 30)
    
    Returns:
        JSON string with air quality data
    """
    try:
        conn = get_oracle_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT 
                measurement_date,
                AVG(pm25_value) as avg_pm25,
                AVG(o3_value) as avg_o3,
                MAX(pm25_value) as max_pm25,
                MAX(o3_value) as max_o3
            FROM openaq_hourly_rollups
            WHERE zip_code = :zip_code
            AND measurement_date >= SYSDATE - :days
            GROUP BY measurement_date
            ORDER BY measurement_date DESC
            FETCH FIRST 30 ROWS ONLY
        """
        
        cursor.execute(query, {'zip_code': zip_code, 'days': days})
        rows = cursor.fetchall()
        
        results = []
        for row in rows:
            results.append({
                'date': str(row[0]),
                'avg_pm25': float(row[1]) if row[1] else None,
                'avg_o3': float(row[2]) if row[2] else None,
                'max_pm25': float(row[3]) if row[3] else None,
                'max_o3': float(row[4]) if row[4] else None
            })
        
        cursor.close()
        conn.close()
        
        return str(results)
    except Exception as e:
        logger.error(f"Error querying air quality: {e}")
        return f"Error: {str(e)}"

def query_hospital_capacity(zip_code: str, days: int = 30) -> str:
    """
    Query hospital capacity data for a ZIP code.
    
    Args:
        zip_code: 5-digit ZIP code
        days: Number of days to look back (default 30)
    
    Returns:
        JSON string with hospital capacity data
    """
    try:
        conn = get_oracle_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT 
                collection_date,
                SUM(total_beds) as total_beds,
                SUM(occupied_beds) as occupied_beds,
                SUM(icu_beds) as icu_beds,
                SUM(covid_patients) as covid_patients
            FROM hospital_capacity_daily_rollups
            WHERE zip_code = :zip_code
            AND collection_date >= SYSDATE - :days
            GROUP BY collection_date
            ORDER BY collection_date DESC
            FETCH FIRST 30 ROWS ONLY
        """
        
        cursor.execute(query, {'zip_code': zip_code, 'days': days})
        rows = cursor.fetchall()
        
        results = []
        for row in rows:
            results.append({
                'date': str(row[0]),
                'total_beds': int(row[1]) if row[1] else 0,
                'occupied_beds': int(row[2]) if row[2] else 0,
                'icu_beds': int(row[3]) if row[3] else 0,
                'covid_patients': int(row[4]) if row[4] else 0
            })
        
        cursor.close()
        conn.close()
        
        return str(results)
    except Exception as e:
        logger.error(f"Error querying hospital capacity: {e}")
        return f"Error: {str(e)}"

def query_flu_data(weeks: int = 12) -> str:
    """
    Query flu data (national level).
    
    Args:
        weeks: Number of weeks to look back (default 12)
    
    Returns:
        JSON string with flu data
    """
    try:
        conn = get_oracle_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT 
                epiweek_start,
                wili,
                ili,
                num_patients
            FROM fluview_weekly_rollups
            WHERE region_code = 'nat'
            AND epiweek_start >= SYSDATE - (:weeks * 7)
            ORDER BY epiweek_start DESC
            FETCH FIRST 12 ROWS ONLY
        """
        
        cursor.execute(query, {'weeks': weeks})
        rows = cursor.fetchall()
        
        results = []
        for row in rows:
            results.append({
                'week': str(row[0]),
                'wili': float(row[1]) if row[1] else None,
                'ili': float(row[2]) if row[2] else None,
                'num_patients': int(row[3]) if row[3] else 0
            })
        
        cursor.close()
        conn.close()
        
        return str(results)
    except Exception as e:
        logger.error(f"Error querying flu data: {e}")
        return f"Error: {str(e)}"

def query_fda_enforcements(days: int = 30) -> str:
    """
    Query FDA enforcement/recall data.
    
    Args:
        days: Number of days to look back (default 30)
    
    Returns:
        JSON string with FDA enforcement data
    """
    try:
        conn = get_oracle_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT 
                report_date,
                classification,
                product_description,
                reason_for_recall
            FROM fda_enforcement_daily_rollups
            WHERE report_date >= SYSDATE - :days
            ORDER BY report_date DESC
            FETCH FIRST 50 ROWS ONLY
        """
        
        cursor.execute(query, {'days': days})
        rows = cursor.fetchall()
        
        results = []
        for row in rows:
            results.append({
                'date': str(row[0]),
                'classification': row[1],
                'product': row[2][:100] if row[2] else None,  # Truncate long descriptions
                'reason': row[3][:200] if row[3] else None
            })
        
        cursor.close()
        conn.close()
        
        return str(results)
    except Exception as e:
        logger.error(f"Error querying FDA enforcements: {e}")
        return f"Error: {str(e)}"

# langchain tools definition
# define tools that the llm can use to query the database
tools = [
    Tool(
        name="query_air_quality",
        func=query_air_quality,
        description="Query air quality data (PM2.5 and O3) for a specific ZIP code. Input should be 'zip_code,days' where days is optional (default 30)."
    ),
    Tool(
        name="query_hospital_capacity",
        func=query_hospital_capacity,
        description="Query hospital capacity data (beds, ICU, COVID patients) for a specific ZIP code. Input should be 'zip_code,days' where days is optional (default 30)."
    ),
    Tool(
        name="query_flu_data",
        func=query_flu_data,
        description="Query national flu/influenza data (ILI, WILI). Input should be 'weeks' (optional, default 12)."
    ),
    Tool(
        name="query_fda_enforcements",
        func=query_fda_enforcements,
        description="Query FDA drug enforcement and recall data. Input should be 'days' (optional, default 30)."
    )
]

# llm service class
# orchestrates langchain tools and ollama llm to answer health data queries
# pipeline: user asks question -> langchain determines tools -> tools query database -> ollama generates response -> return to user
class LLMService:
    
    def __init__(self):
        # Initialize Ollama LLM (local, free)
        # Make sure Ollama is running and has a model downloaded
        # Example: ollama pull llama2 (or mistral, etc.)
        ollama_base_url = os.getenv('OLLAMA_BASE_URL', 'http://ollama:11434')
        
        self.llm = Ollama(
            base_url=ollama_base_url,
            model="llama2",  # Default model - user can change this
            temperature=0.7
        )
        
        # Initialize LangChain agent with tools
        # The agent will decide which tools to use based on the query
        self.agent = initialize_agent(
            tools=tools,
            llm=self.llm,
            agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True,
            handle_parsing_errors=True
        )
        
        logger.info("LLM Service initialized")
    
    # process a natural language query using langchain tools and ollama
    # args: query (the question), context (optional zip_code, date_range)
    # returns: dictionary with response, sources, and timing info
    async def process_query(self, query: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        start_time = time.time()
        
        try:
            # enhance query with context (add zip code if provided)
            enhanced_query = query
            if context and context.get('zip_code'):
                enhanced_query = f"For ZIP code {context['zip_code']}: {query}"
            
            # run langchain agent
            # the agent will: parse query, determine which tools to use, execute database queries, generate response using ollama
            response = self.agent.run(enhanced_query)
            
            # record metrics
            duration = time.time() - start_time
            LLM_QUERY_DURATION.observe(duration, labels={'query_type': 'general'})
            LLM_QUERIES_TOTAL.inc(labels={'status': 'success'})
            
            return {
                "response": response,
                "sources": ["oracle_database"],  # Could track which tools were used
                "query_time_ms": duration * 1000
            }
            
        except Exception as e:
            logger.error(f"Error processing query: {e}")
            LLM_QUERIES_TOTAL.inc(labels={'status': 'error'})
            
            return {
                "response": f"I encountered an error processing your query: {str(e)}. Please try rephrasing your question.",
                "sources": [],
                "query_time_ms": (time.time() - start_time) * 1000
            }

