FROM python:3.11-slim-bullseye

RUN apt-get update && \
    apt-get install -y \
        git gcc g++ make curl gettext wget \
        libxml2-dev libxslt1-dev zlib1g-dev \
        mariadb-client libmariadb-dev \
        libjpeg-dev debconf-utils && \
    curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

COPY repo/requirements.txt .
COPY repo/additional_requirements.txt .
RUN npm install -g sass postcss-cli postcss autoprefixer && \
    pip3 install -r requirements.txt && \
    pip3 install -r additional_requirements.txt
