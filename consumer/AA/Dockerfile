FROM python:3.8-slim

COPY consumer.py .

RUN python -m pip install --upgrade pip
RUN python -m pip install kafka-python kubernetes

CMD ["python", "consumer.py"]

