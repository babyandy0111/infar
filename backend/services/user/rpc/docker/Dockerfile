FROM golang:alpine AS builder

LABEL stage=gobuilder

ENV CGO_ENABLED=0
ENV GOPROXY=https://goproxy.cn,direct
RUN apk update --no-cache && apk add --no-cache tzdata

WORKDIR /build

# 改進：直接複製 backend 下的 go.mod 和 go.sum
COPY go.mod .
COPY go.sum .
RUN go mod download

# 複製整個 backend 代碼
COPY . .

# 編譯路徑對齊
RUN go build -ldflags="-s -w" -o /app/user-rpc services/user/rpc/user.go

FROM alpine:latest

RUN apk update --no-cache && apk add --no-cache ca-certificates tzdata
ENV TZ=Asia/Taipei

WORKDIR /app
COPY --from=builder /app/user-rpc /app/user-rpc
# 重要：我們在 K8s 會用 ConfigMap 掛載 etc，所以這裡只要確保目錄存在即可
RUN mkdir -p etc

EXPOSE 9090

CMD ["./user-rpc", "-f", "etc/user.yaml"]
