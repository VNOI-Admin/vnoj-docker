FROM python:3.8-slim-buster

RUN apt-get update && \
    apt-get install -y \
        git gcc g++ make curl gettext wget \
        libxml2-dev libxslt1-dev zlib1g-dev \
        mariadb-client libmariadbclient-dev \
        libjpeg-dev debconf-utils && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get install -y nodejs && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

COPY repo/requirements.txt .
RUN npm install -g sass postcss-cli postcss autoprefixer && \
    pip3 install -r requirements.txt && \
    pip3 install mysqlclient uwsgi websocket-client && \
    rm requirements.txt
