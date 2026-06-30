FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py .

RUN mkdir -p /memories
VOLUME /memories

ENV MEMORY_ROOT=/memories

CMD ["python", "server.py"]
