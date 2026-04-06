# Phần 5: Tạo Rules, Timelines và Cases từ Suricata Events sử dụng SIEM Apps của Kibana

> **Tác giả:** Jamon Camisso | **Ngày xuất bản:** March 1, 2022

---

## Giới thiệu

Các phần trước đã hướng dẫn cài đặt, cấu hình Suricata và tích hợp với Elastic Stack. Trong phần cuối này, bạn sẽ học cách sử dụng các công cụ SIEM tích hợp trong Kibana để:

- Tạo **custom rules** sinh alerts về traffic cụ thể
- Tạo **timelines** để nhóm và điều tra alerts
- Tạo và quản lý **cases** để theo dõi các sự cố bảo mật

---

## Yêu cầu

- Server với ít nhất 4GB RAM và 2 CPU
- Suricata đã cài đặt và chạy ([Phần 1](part1-install-suricata.md))
- Elastic Stack đã được cấu hình với Filebeat ([Phần 4](part4-siem-elastic-stack.md))
- Có thể đăng nhập Kibana và nhìn thấy dữ liệu trong Suricata Alerts/Events dashboards

### Ví dụ Suricata Signatures dùng trong phần này

```
alert ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype: misc-attack; target: dest_ip; sid:1000000;)
alert ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype: misc-attack; target: dest_ip; sid:1000001;)

alert http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000002;)
alert http any any -> 2001:DB8::1/32 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000003;)

alert tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS HTTP port"; classtype:misc-activity; sid:1000004;)
alert tls any any -> 2001:DB8::1/32 !443 (msg:"TLS TRAFFIC on non-TLS HTTP port"; classtype:misc-activity; sid:1000005;)
```

---

## Bước 1 — Bật API Keys trong Elasticsearch

Trước khi tạo rules và timelines trong Kibana, cần bật module xpack security API key.

Mở file cấu hình Elasticsearch:

```bash
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Thêm dòng sau vào cuối file:

```yaml
# /etc/elasticsearch/elasticsearch.yml

discovery.type: single-node
xpack.security.enabled: true
xpack.security.authc.api_key.enabled: true
```

Lưu và đóng file, sau đó restart Elasticsearch:

```bash
sudo systemctl restart elasticsearch.service
```

---

## Bước 2 — Tạo Rules trong Kibana

Rules trong Kibana sẽ phân tích dữ liệu từ Elasticsearch và sinh alerts khi phát hiện pattern phù hợp.

### Truy cập Rules Dashboard

Mở SSH tunnel (nếu chưa mở) và đăng nhập Kibana. Truy cập:

```
http://localhost:5601/app/security/rules/
```

Click nút **Create new rule** ở góc trên phải.

### Cấu hình rule với Custom Query

Đảm bảo card **Custom query** đang được chọn. Trong ô **Custom query**, nhập:

```
rule.id: "1000000" or rule.id: "1000001"
```

> **Lưu ý:** Giá trị `rule.id` phải khớp với `sid` trong Suricata signature.

Đổi **Query quick preview** thành **Last Month**, sau đó click **Preview Results**. Biểu đồ alerts sẽ hiển thị nếu có dữ liệu phù hợp.

Click **Continue** để tiếp tục.

### Đặt tên và mô tả Rule

Điền vào các trường:
- **Rule Name:** `SSH TRAFFIC on non-SSH port` (tên rule, bắt buộc)
- **Description:** `Check for SSH connection attempts on non-standard ports`

Có thể mở rộng phần **Advanced Settings** để thêm:
- Hướng dẫn xử lý alert
- Link đến tài liệu về loại tấn công tương ứng

Click **Continue** → giữ nguyên **Schedule rule** với giá trị mặc định → click **Continue**.

### Kích hoạt Rule

Ở bước **Rule actions**, click **Create & activate rule**.

Bạn sẽ được chuyển đến trang chi tiết của rule.

> **Lưu ý:** Alert data có thể mất vài phút để xuất hiện do rule mặc định chạy mỗi 5 phút.

Lặp lại các bước trên cho các signature khác, thay `rule.id` tương ứng với SID của signature muốn alert.

---

## Bước 3 — Tạo Timeline để theo dõi SSH Traffic Alerts

Timeline giúp nhóm và phân tích các alerts liên quan đến cùng một network flow.

### Sinh traffic test

Từ máy local, tạo SSH connection đến port 80 (không chuẩn) để kích hoạt rule:

```bash
ssh -p 80 your_server_ip
```

Lệnh này sẽ kích hoạt rule `sid:1000000`. Chờ vài phút để alert xuất hiện trong Kibana.

### Xem Alerts Dashboard

Truy cập: `http://127.0.0.1:5601/app/security/alerts`

### Thêm trường community_id vào bảng alerts

Click nút **Fields** và trong modal dialog, tìm và tick vào:

```
network.community_id
```

Đóng modal. Trường `community_id` sẽ xuất hiện trong bảng alerts.

### Thêm alerts vào Timeline

Hover chuột vào một alert có `community_id` cụ thể → click icon **Add to timeline investigation**.

Thao tác này sẽ thêm tất cả alerts cùng `community_id` vào một timeline để điều tra.

### Làm việc với Timeline

Click link **Untitled Timeline** ở góc dưới trái browser để mở trang Timeline.

Trang Timeline hiển thị chi tiết các packet liên quan đến alert hoặc network flow, giúp bạn biết:
- Thời điểm bắt đầu flow
- Nguồn gốc traffic
- Thời gian kéo dài

Click **All data sources** ở phải trang → chọn **Detection Alerts** → click **Save**. Tùy chọn này giới hạn timeline chỉ hiển thị alerts từ Kibana rules (không lẫn alerts thô từ Suricata).

### Lưu Timeline

Click icon **bút chì (pencil)** ở góc trên trái trang Timeline để đặt tên và mô tả:
- **Name:** Tên có ý nghĩa (ví dụ: `SSH on non-SSH port - 203.0.113.5`)
- **Description:** Mô tả thêm thông tin về điều tra

Click **Save** để lưu.

---

## Bước 4 — Tạo và Quản lý SIEM Cases

Cases là nơi tổ chức và theo dõi việc điều tra các alerts. Mỗi case có thể chứa nhiều timelines và alerts liên quan.

### Tạo Case từ Timeline

Đảm bảo đang ở trang Timeline, click **Attach to case** ở góc trên phải → chọn **Attach to new case**.

Điền thông tin case:

| Trường | Ví dụ |
|---|---|
| **Name** | `SSH TRAFFIC on non-SSH port from 203.0.113.5` |
| **Tags** | `ssh`, `intrusion-attempt`, `non-standard-port` |
| **Description** | Mô tả sự cố, có thể dùng Markdown. Nên thêm link đến timeline |

> **Quy tắc đặt tên case:** Dùng format `<loại attack> from <IP nguồn>` để dễ tìm kiếm và đối chiếu với Suricata signature message.

Click **Create case** ở cuối trang.

### Thêm Alerts vào Case từ Timeline

Quay lại Timeline của case này. Với mỗi alert muốn thêm vào case:

1. Click icon **More actions** trên alert
2. Chọn **Add to existing case**
3. Click tên case tương ứng trong modal

Lặp lại cho tất cả alerts liên quan.

### Xem Case Dashboard

Truy cập Cases app: `http://localhost:5601/app/security/cases`

Click vào case vừa tạo để xem:
- Danh sách alerts đã thêm vào case
- Timeline link
- Comments và ghi chú

### Thêm thông tin vào Case

Ở cuối trang case, có thể thêm comments theo format Markdown:
- Các bước điều tra đã thực hiện
- Thay đổi cấu hình Suricata
- Ghi chú về rule mới hoặc đã chỉnh sửa
- Thông tin về escalation lên team khác
- Bất kỳ thông tin liên quan nào

---

## Luồng điều tra đề xuất

```
Alert xuất hiện trong Kibana
        │
        ▼
Xem chi tiết alert (src_ip, dest_ip, signature, community_id)
        │
        ▼
Nhóm alerts theo community_id → Tạo Timeline
        │
        ▼
Phân tích Timeline (packet details, thời gian, flow pattern)
        │
        ▼
Tạo Case, attach Timeline
        │
        ▼
Thêm các alerts liên quan vào Case
        │
        ▼
Thêm ghi chú điều tra và hành động đã thực hiện
        │
        ▼
Theo dõi và đóng Case khi hoàn tất điều tra
```

---

## Kết luận

Bạn đã hoàn thiện hệ thống SIEM đầy đủ với khả năng:

- Tạo **custom rules** trong Kibana để sinh alerts về traffic cụ thể
- Sử dụng `community_id` để nhóm alerts liên quan thành **timelines**
- Tạo **cases** để quản lý, theo dõi và điều tra sự cố bảo mật
- Kết hợp Suricata signatures, Kibana rules và Case management để vận hành SIEM

Khi ngày càng quen với Suricata và theo dõi các alerts trong Kibana, bạn có thể tinh chỉnh các signature và hành động mặc định của Suricata phù hợp với môi trường mạng riêng.

---

## Tham khảo

- [Elastic Security Documentation](https://www.elastic.co/guide/en/security/current/index.html)
- [Kibana Alerting Rules](https://www.elastic.co/guide/en/kibana/current/alerting-getting-started.html)
- [Kibana Cases](https://www.elastic.co/guide/en/security/current/cases-overview.html)
- [Kibana Timelines](https://www.elastic.co/guide/en/security/current/timelines-ui.html)

---

## Điều hướng

| | |
|---|---|
| **Trước đó:** | [← Phần 4: Xây dựng SIEM với Elastic Stack](part4-siem-elastic-stack.md) |
| **Tổng quan:** | [← README](README.md) |
