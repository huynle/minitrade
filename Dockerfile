FROM --platform=linux/amd64 python:3.10.11-slim-bullseye 

RUN apt update
RUN apt install -y default-jre
RUN apt install -y wget
RUN apt install -y gnupg
RUN apt install -y procps

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
RUN apt update
RUN apt install -y google-chrome-stable

# RUN apt install -y zip
# # Need to match the Chrome version installed
# RUN wget https://chromedriver.storage.googleapis.com/114.0.5735.90/chromedriver_linux64.zip
# RUN unzip chromedriver_linux64.zip -d /usr/local/bin

RUN pip install chromedriver-autoinstaller minitrade -U
RUN python3 -c "import chromedriver_autoinstaller; chromedriver_autoinstaller.install()"
# RUN minitrade init

RUN pip install minitrade -U
# RUN minitrade init

WORKDIR /root

COPY mtctl.sh /root/mtctl.sh

CMD /root/mtctl.sh start
EXPOSE 8501 6666 6667
