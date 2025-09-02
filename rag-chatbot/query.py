import boto3, json, os, psycopg2, openai
from dotenv import load_dotenv  

load_dotenv()  # take environment variables from .env

session = boto3.session.Session()
client = session.client(service_name='secretsmanager')

def get_secret(secret_name):
    response = client.get_secret_value(SecretId=secret_name)
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
    client = session.client("secretsmanager")
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
print("Connected to the database2")


def search(query):
    # Get embedding for the query
    q_embed = openai.Embedding.create(
        input=query,
        model="text-embedding-ada-002"
    )["data"][0]["embedding"]

    # Search using cosine distance operator (<-> in pgvector)
    cur.execute("""
        SELECT content
        FROM documents
        ORDER BY embedding <-> %s
        LIMIT 3;
    """, (q_embed,))
    return cur.fetchall()

if __name__ == "__main__":
    results = search("Summarize the document")
    for r in results:
        print(r[0][:200], "...")

