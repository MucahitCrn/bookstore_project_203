FROM python:alpine
COPY . /app
WORKDIR /app
RUN pip install -r requirement.txt
EXPOSE 80
CMD python ./bookstore-api.py