from fastapi import FastAPI
from pydantic import BaseModel
import os, psycopg2, openai, boto3, json
from dotenv import load_dotenv
from typing import Optional, Dict 

app = FastAPI()

load_dotenv()  # take environment variables from .env

session = boto3.session.Session()
sm_client = session.client(service_name='secretsmanager')

def get_secret(secret_name):
    response = sm_client.get_secret_value(SecretId=secret_name)
    secret = response["SecretString"]
    try:
        return json.loads(secret)  # for JSON secrets
    except json.JSONDecodeError:
        return secret 
   
def get_secret_json(secret_name: str, region: Optional[str] = None) -> Dict:
    """
    Fetches a secret from AWS Secrets Manager and always parses JSON.
    Raises if the secret is not valid JSON.
    """
    session = boto3.session.Session(region_name=region or os.getenv("AWS_REGION"))
    sm_client = session.client("secretsmanager")
    resp = client.get_secret_value(SecretId=secret_name)

    secret_str = resp.get("SecretString")
    if not secret_str:
        raise ValueError(f"Secret {secret_name} has no SecretString")

    try:
        return json.loads(secret_str)
    except json.JSONDecodeError as e:
        raise ValueError(f"Secret {secret_name} is not valid JSON: {e}")
    
# Load secrets
db_secret = get_secret("rds-master-password")

openai_secret = get_secret_json("openai-api-key")
openai_api_key = openai_secret["openai-api-key"]
openai.api_key = openai_api_key

print("after api keys")
# DB connection
conn = psycopg2.connect(
    host=os.getenv("PGHOST"),
    dbname=os.getenv("PGDATABASE"),
    user=os.getenv("PGUSER"),
    password=db_secret,
    sslmode="require"
)
print("Connected to the database1")
cur = conn.cursor()


class Query(BaseModel):
    question: str

# ---------- Helper Functions ----------
def embed_text(text: str):
    resp = client.embeddings.create(
        input=text,
        model="text-embedding-ada-002"   # or text-embedding-3-small/large
    )
    return resp.data[0].embedding

def retrieve_context(query_embedding, top_k: int = 5):
    cur.execute(
        """
        SELECT content
        FROM documents
        ORDER BY embedding <-> %s::vector
        LIMIT %s
        """,
        (query_embedding, top_k)
    )
    results = [row[0] for row in cur.fetchall()]
    return results



@app.post("/chat")
def chat(query: Query):
    # 1. Embed the user question
    q_embedding = embed_text(query.question)

    # 2. Retrieve similar documents
    context = retrieve_context(q_embedding, top_k=3)
    combined_context = "\n".join(context)

    # 3. Call OpenAI with context + question
    completion = client.chat.completions.create(
        model="gpt-4o-mini",   # or gpt-4o, gpt-3.5-turbo
        messages=[
            {"role": "system", "content": "You are a helpful assistant that answers based on provided context."},
            {"role": "user", "content": f"Context:\n{combined_context}\n\nQuestion: {query.question}"}
        ]
    )
    answer = completion.choices[0].message.content
    return {"question": query.question, "answer": answer, "context": context}