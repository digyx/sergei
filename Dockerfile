FROM python:3

# Install dependencies
RUN pip3 install python-dotenv
RUN pip3 install discord.py
RUN pip3 install pynacl
RUN pip3 install youtube_dl
RUN pip3 install git+https://github.com/Cupcakus/pafy

WORKDIR /usr/src/app
COPY . .

RUN apt update
RUN apt install -y ffmpeg

CMD ["python3", "main.py"]
