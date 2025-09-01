import boto3, json, os, psycopg2, openai
from pypdf import PdfReader
from dotenv import load_dotenv  
load_dotenv()  # take environment variables from .env

openai.api_key = os.getenv("OPENAI_API_KEY")

session = boto3.session.Session()
client = session.client(service_name='secretsmanager')

def get_secret(secret_name):
    response = client.get_secret_value(SecretId=secret_name)
    return response['SecretString']

# Load DB creds
db_secret = get_secret("rds-master-password")

# Load OpenAI API key
openai_secret = get_secret("openai_api_key")

# DB connection
conn = psycopg2.connect(
    host=os.getenv("PGHOST"),
    dbname=os.getenv("PGDATABASE"),
    user=os.getenv("PGUSER"),
    password=os.getenv("PGPASSWORD"),
    sslmode="require"
)
cur = conn.cursor()

openai.api_key = openai_secret['openai_api_key']


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