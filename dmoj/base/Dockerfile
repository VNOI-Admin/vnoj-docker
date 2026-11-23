FROM python:3.11-slim-bookworm

RUN apt-get update && \
    apt-get install -y \
        git gcc g++ make curl gettext wget \
        libxml2-dev libxslt1-dev zlib1g-dev \
        mariadb-client libmariadb-dev \
        libjpeg-dev debconf-utils pkg-config && \
    curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /
COPY repo/requirements.txt .
COPY repo/additional_requirements.txt .
COPY repo/package.json .
COPY repo/package-lock.json .
RUN npm install && \
    pip3 install -r requirements.txt && \
    pip3 install --use-pep517 -r additional_requirements.txt && \
    pip3 install --use-pep517 lxml_html_clean \
        "markdown2 @ git+https://github.com/VNOI-Admin/python-markdown2.git@2ef56536045fc4eefe63bc5ee396cfa509b98a1a"
