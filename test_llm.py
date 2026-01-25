
import os
from openai import OpenAI
import sys

# Try to use the key from main.py
api_key = os.getenv("DASHSCOPE_API_KEY", "sk-341c8f4ad671494c84d12201dc2737cf")
base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1"

print(f"Testing LLM with Base URL: {base_url}")
# Mask key for printing
masked_key = api_key[:4] + "***" + api_key[-4:] if len(api_key) > 8 else "***"
print(f"Using API Key: {masked_key}")

client = OpenAI(
    api_key=api_key,
    base_url=base_url
)

try:
    completion = client.chat.completions.create(
        model="qwen-flash",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Hello, are you working?"}
        ],
        temperature=0.7,
        max_tokens=50
    )
    print("Success!")
    print(completion.choices[0].message.content)
except Exception as e:
    print("Error occurred:")
    print(e)
