FROM vnoj/vnoj-base:latest

RUN curl --location -o pandoc.deb $(curl -s https://api.github.com/repos/jgm/pandoc/releases/latest | grep -o -m 1 "https://github\.com.*pandoc-.*-amd64\.deb") && \
    dpkg -i pandoc.deb && \
    rm pandoc.deb

EXPOSE 8000

ENTRYPOINT uwsgi --ini uwsgi.ini \
           >> /logs/site.stdout.log 2>> /logs/site.stderr.log
