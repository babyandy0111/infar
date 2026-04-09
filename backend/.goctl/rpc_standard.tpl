syntax = "proto3";

package pb;
option go_package = "./pb";

// =======================
// INFAR_CAP_SERVICE_NAME 標準請求與回應結構
// =======================

message CreateReq {
    string data = 1; // TODO: 替換為實際新增欄位
}

message UpdateReq {
    int64 id = 1;
    string data = 2; // TODO: 替換為實際更新欄位
}

message DeleteReq {
    int64 id = 1;
}

message GetReq {
    int64 id = 1;
}

message ListReq {
    int64 page = 1;
    int64 pageSize = 2;
    string keyword = 3;
}

message UpdateStatusReq {
    int64 id = 1;
    int64 status = 2;
}

// 通用單一回應
message Response {
    string msg = 1;
    string data = 2; // TODO: 可替換為具體 Message
}

// 通用列表回應
message ListResponse {
    string msg = 1;
    int64 total = 2;
    repeated string list = 3; // TODO: 替換為具體列表結構
}

// =======================
// INFAR_CAP_SERVICE_NAME 服務定義
// =======================
service INFAR_CAP_SERVICE_NAME {
    // 1. 新增
    rpc Create(CreateReq) returns (Response);
    // 2. 更新
    rpc Update(UpdateReq) returns (Response);
    // 3. 刪除
    rpc Delete(DeleteReq) returns (Response);
    // 4. 取得單筆
    rpc Get(GetReq) returns (Response);
    // 5. 分頁列表
    rpc List(ListReq) returns (ListResponse);
    // 6. 狀態切換
    rpc UpdateStatus(UpdateStatusReq) returns (Response);
}
