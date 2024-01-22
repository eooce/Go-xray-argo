FROM golang:1.20-alpine

WORKDIR /app

COPY go.mod ./

RUN go mod download

COPY main.go start.sh ./app

RUN apk update &&\
    apk --no-cache add openssl curl gcompat iproute2 coreutils &&\
    go build -o app main.go

CMD ["./app"]
