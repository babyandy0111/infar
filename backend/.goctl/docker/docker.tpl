FROM golang:alpine AS builder
LABEL stage=gobuilder
ENV CGO_ENABLED 0
ENV GOPROXY https://goproxy.cn,direct
RUN apk update --no-cache && apk add --no-cache tzdata
WORKDIR /build
ADD go.mod .
ADD go.sum .
RUN go mod download
COPY . .
RUN go build -ldflags="-s -w" -o /app/{{.ExeFile}} {{.GoMainFrom}}

FROM alpine:latest
RUN apk update --no-cache && apk add --no-cache ca-certificates tzdata
ENV TZ Asia/Taipei
WORKDIR /app
COPY --from=builder /app/{{.ExeFile}} /app/{{.ExeFile}}
RUN mkdir -p etc
EXPOSE {{.Port}}
CMD ["./{{.ExeFile}}", "-f", "etc/{{.ExeFile}}.yaml"]
