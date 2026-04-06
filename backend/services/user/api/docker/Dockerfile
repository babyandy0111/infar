FROM golang:alpine AS builder

LABEL stage=gobuilder

ENV CGO_ENABLED=0
ENV GOPROXY=https://goproxy.cn,direct
RUN apk update --no-cache && apk add --no-cache tzdata

WORKDIR /build

COPY go.mod .
COPY go.sum .
RUN go mod download

COPY . .

RUN go build -ldflags="-s -w" -o /app/user-api services/user/api/user.go

FROM alpine:latest

RUN apk update --no-cache && apk add --no-cache ca-certificates tzdata
ENV TZ=Asia/Taipei

WORKDIR /app
COPY --from=builder /app/user-api /app/user-api
RUN mkdir -p etc

EXPOSE 8888

CMD ["./user-api", "-f", "etc/user-api.yaml"]
