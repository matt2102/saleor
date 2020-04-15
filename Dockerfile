### Build and install packages
FROM python:3.8.0-alpine as builder

# set work directory
WORKDIR /usr/src/saleor

# set environment variables
ENV PYTHONUNBUFFERED 1 # prevents python from stdout and stderr
ENV PYTHONDONTWRITEBYTECODE 1 # prevents python from writing *.pyc


# install dependencies to build wheels
RUN apk update \
    && apk add  postgresql-dev libmagic libffi-dev gcc python3-dev musl-dev zlib-dev libxslt-dev libxml2-dev tiff-dev jpeg-dev freetype-dev lcms-dev tcl-dev tk-dev

# Install Python dependencies
COPY . /usr/src/saleor/

RUN pip install --upgrade pip

COPY ./requirements_dev.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/saleor/wheels -r requirements_dev.txt

### Final image
FROM python:3.8.0-alpine
RUN mkdir -p /home/saleor



# create the saleor user
RUN addgroup -S saleor && adduser -S saleor -G saleor


ARG STATIC_URL
ENV STATIC_URL ${STATIC_URL:-/static/}

ENV HOME=/home/saleor
ENV APP_HOME=/home/saleor/container
RUN mkdir $APP_HOME
WORKDIR $APP_HOME


# install dependencies
RUN apk update && apk add libpq uwsgi uwsgi-python3 libmagic libxslt-dev libxml2-dev tiff-dev jpeg-dev freetype-dev lcms-dev postgresql-dev gcc python3-dev musl-dev
COPY --from=builder /usr/src/saleor/wheels /wheels
COPY --from=builder /usr/src/saleor/requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache /wheels/*

COPY ./entrypoint.sh $APP_HOME

RUN mkdir -p /app/media /app/static \
  && chown -R saleor:saleor /app/

# copy project
COPY . $APP_HOME

# chown all the files to the saleor user
RUN chown -R saleor:saleor $APP_HOME

EXPOSE 8000
ENV PORT 8000 #dont delete used as env var in other files
ENV PYTHONUNBUFFERED 1
ENV PROCESSES 4
ENTRYPOINT ["/home/saleor/container/entrypoint.sh"]
# CMD ["uwsgi", "--ini", "/app/saleor/wsgi/uwsgi.ini"]