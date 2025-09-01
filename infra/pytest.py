import boto3
s3 = boto3.client('s3')
print(s3.list_buckets())

print("This line will be printed.")
import boto3
s3 = boto3.client('s3')
print(s3.list_buckets())

import psycopg2
conn = psycopg2.connect(
    host="mlops-rag-pg.c6jao84c4tiv.us-east-1.rds.amazonaws.com",
    database="ragdb",
    user="raguser",
    

)
print("Connected to Postgres!")
conn.close()