FROM vnoj/vnoj-base:latest

RUN ARCH=$([ $(uname -m) = "x86_64" ] && echo "amd64" || echo "arm64") && \
    curl --location -o pandoc.deb $(curl -s https://api.github.com/repos/jgm/pandoc/releases/latest | grep -o -m 1 "https://github\.com.*pandoc-.*-$ARCH\.deb") && \
    dpkg -i pandoc.deb && \
    rm pandoc.deb

RUN apt-get update && \
    apt-get install -y chromium-driver && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install selenium

COPY site/wrap_chromium_binary /opt/bin/wrap_chromium_binary
RUN /opt/bin/wrap_chromium_binary && rm /opt/bin/wrap_chromium_binary

EXPOSE 8000

ENTRYPOINT uwsgi --ini uwsgi.ini
