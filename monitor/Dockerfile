FROM python:3.14-slim

WORKDIR /app

COPY monitor/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY monitor/ ./monitor/

ENTRYPOINT ["python", "-m", "monitor.monitor"]