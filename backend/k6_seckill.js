import http from 'k6/http';
import { check } from 'k6';

export const options = {
    vus: 2000,
    iterations: 10000,
};

export default function () {
    const url = 'http://order-api-svc:8889/v1/order/create';
    
    // 加入 Date.now() 確保每次壓測產生的 order_no 都是全球唯一
    const ts = new Date().getTime();
    const payload = JSON.stringify({
        user_id: __VU,
        order_no: `SEC-${ts}-${__VU}-${__ITER}`,
        amount: 100.50,
        status: "pending"
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
        },
    };

    const res = http.post(url, payload, params);
    
    check(res, {
        'status is 200': (r) => r.status === 200,
        'transaction processed': (r) => r.json('code') === 200 || r.json('code') === 400,
    });
}
