FROM --platform=linux/amd64 python:3.10.11-slim-bullseye 

RUN apt update
RUN apt install -y default-jre
RUN apt install -y wget
RUN apt install -y gnupg
RUN apt install -y procps

# RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
# RUN sh -c 'echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
# RUN apt update
# RUN apt install -y google-chrome-stable

ARG CHROME_VERSION="134.0.6998.88"
RUN apt-get install -y wget zip
RUN wget -q https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}-1_amd64.deb
RUN apt-get install -y ./google-chrome-stable_${CHROME_VERSION}-1_amd64.deb

# # Need to match the Chrome version installed
# RUN wget -q https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip
# RUN unzip chromedriver_linux64.zip -d /usr/local/bin

RUN pip install chromedriver-autoinstaller minitrade -U
RUN python3 -c "import chromedriver_autoinstaller; chromedriver_autoinstaller.install()"
# RUN minitrade init

WORKDIR /root

COPY mtctl.sh /root/mtctl.sh

CMD /root/mtctl.sh start
EXPOSE 8501 6666 6667
