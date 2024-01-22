FROM golang:1.20-alpine

WORKDIR /app

COPY . .

RUN apk update &&\
    apk --no-cache add openssl curl gcompat iproute2 coreutils &&\
    go build -o app main.go

CMD ["./app"]
