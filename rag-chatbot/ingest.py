import boto3, json, os, psycopg2, openai
from pypdf import PdfReader
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

# Load secrets
db_secret = get_secret("rds-master-password")
openai.api_key = get_secret("openai-api-key")

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


def embed_text(text):
    response = openai.Embedding.create(
        input=text,
        model="text-embedding-ada-002"
    )
    return response["data"][0]["embedding"]

def store_document(content):
    embedding = embed_text(content)
    cur.execute(
        "INSERT INTO documents (content, embedding) VALUES (%s, %s)",
        (content, embedding)
    )
    conn.commit()

# Example: load a PDF
reader = PdfReader("example.pdf")
for page in reader.pages:
    text = page.extract_text()
    if text.strip():
        store_document(text[:2000])  # truncate if needed