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
RUN go build -ldflags="-s -w" -o /app/order-rpc Users/andywang/GolandProjects/infar/backend/services/order/rpc/order.go

FROM alpine:latest
RUN apk update --no-cache && apk add --no-cache ca-certificates tzdata
ENV TZ Asia/Taipei
WORKDIR /app
COPY --from=builder /app/order-rpc /app/order-rpc
RUN mkdir -p etc
EXPOSE 9889
CMD ["./order-rpc", "-f", "etc/order-rpc.yaml"]
