# DriveNow frontend

Phần frontend Next.js của Hiệp. Ứng dụng chạy trên cổng 3000 và chuyển các request `/api/*` tới API Gateway (mặc định `http://127.0.0.1:8080`).

```bash
cd car-rental-frontend
npm ci
npm run dev
```

Mở `http://localhost:3000`. Để dùng đủ chức năng, nhóm cần chạy thêm API Gateway và các service auth, car, booking cùng cơ sở dữ liệu. Có thể đặt `BACKEND_URL` khi Gateway chạy ở địa chỉ khác; giá trị này chỉ dùng ở server Next.js.

Kiểm tra bản production bằng `npm run build`. Không cần chạy ứng dụng qua IntelliJ; có thể dùng terminal, còn IntelliJ chỉ là lựa chọn để mở và chạy dự án.
