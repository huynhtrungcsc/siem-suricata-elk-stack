---
title: "Tạo Rules, Timelines và Cases từ Suricata Events bằng SIEM Apps của Kibana"
description: "Tạo custom Kibana detection rule, xây dựng investigation timeline theo community_id, và quản lý security case để theo dõi và xử lý alert từ Suricata."
author: "Jamon Camisso"
date: 2022-03-01
category: Bảo mật
series: "SIEM với Suricata và Elastic Stack"
part: 5
tags:
  - suricata
  - kibana
  - siem
  - detection-rules
  - timelines
  - cases
  - elasticsearch
  - security-operations
---

# Phần 5 — Kibana SIEM: Rules, Timelines và Cases

| | |
|---|---|
| **Chuỗi hướng dẫn** | SIEM với Suricata và Elastic Stack |
| **Phần** | 5 / 5 |
| **Độ khó** | Trung bình |
| **Thời gian** | ~30 phút |
| **Hệ điều hành** | Ubuntu 20.04 LTS |

---

## Mục lục

- [Giới thiệu](#giới-thiệu)
- [Yêu cầu](#yêu-cầu)
- [Bước 1 — Bật API Keys trong Elasticsearch](#bước-1--bật-api-keys-trong-elasticsearch)
- [Bước 2 — Tạo Detection Rules trong Kibana](#bước-2--tạo-detection-rules-trong-kibana)
  - [Truy cập Rules Dashboard](#truy-cập-rules-dashboard)
  - [Cấu hình Custom Query Rule](#cấu-hình-custom-query-rule)
  - [Xác định Rule Metadata](#xác-định-rule-metadata)
- [Bước 3 — Tạo Timeline để điều tra Alerts](#bước-3--tạo-timeline-để-điều-tra-alerts)
  - [Tạo traffic test](#tạo-traffic-test)
  - [Thêm community_id vào bảng Alerts](#thêm-community_id-vào-bảng-alerts)
  - [Thêm Alerts vào Timeline](#thêm-alerts-vào-timeline)
  - [Cấu hình và lưu Timeline](#cấu-hình-và-lưu-timeline)
- [Bước 4 — Tạo và Quản lý SIEM Cases](#bước-4--tạo-và-quản-lý-siem-cases)
- [Quy trình điều tra](#quy-trình-điều-tra)
- [Tóm tắt](#tóm-tắt)

---

## Giới thiệu

[Hướng dẫn trước](04-xay-dung-siem.md) đã thiết lập pipeline SIEM hoàn chỉnh — Suricata → Filebeat → Elasticsearch → Kibana. Hướng dẫn cuối cùng này sử dụng Security apps tích hợp của Kibana để:

1. **Tạo detection rule** sinh alert có cấu trúc từ sự kiện Suricata
2. **Xây dựng timeline** nhóm và điều tra các alert tương quan
3. **Quản lý case** theo dõi sự cố từ phát hiện đến giải quyết

---

## Yêu cầu

- SIEM stack hoạt động đầy đủ (Suricata + Elastic Stack) như cấu hình trong [Phần 1–4](README.md)
- Kibana truy cập được qua SSH tunnel tại `http://127.0.0.1:5601`
- Có sự kiện Suricata hiển thị trong các Suricata dashboard

### Ví dụ Suricata Signatures dùng trong hướng dẫn này

```
alert ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000000;)
alert ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000001;)
alert http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000002;)
alert tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS port"; classtype:misc-activity; sid:1000004;)
```

---

## Bước 1 — Bật API Keys trong Elasticsearch

SIEM rules của Kibana yêu cầu tính năng API key authentication của Elasticsearch. Bật trên **Elasticsearch server**:

```bash
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Thêm dòng sau vào cuối file:

```yaml
xpack.security.authc.api_key.enabled: true
```

Khởi động lại Elasticsearch:

```bash
sudo systemctl restart elasticsearch.service
```

---

## Bước 2 — Tạo Detection Rules trong Kibana

Detection rule liên tục truy vấn dữ liệu sự kiện Elasticsearch và tạo alert có cấu trúc khi tìm thấy pattern khớp.

### Truy cập Rules Dashboard

Điều hướng đến: `http://localhost:5601/app/security/rules/`

Click **Create new rule** ở góc trên phải.

### Cấu hình Custom Query Rule

1. Đảm bảo card loại rule **Custom query** đang được chọn.

2. Trong ô **Custom query**, nhập KQL query nhắm vào Suricata SID. Đảm bảo giá trị `rule.id` tương ứng với `sid` trong Suricata signature:

   ```
   rule.id: "1000000" or rule.id: "1000001"
   ```

3. Đặt dropdown **Query quick preview** thành **Last Month**.

4. Click **Preview Results** để xác nhận sự kiện khớp xuất hiện trong biểu đồ.

5. Click **Continue**.

### Xác định Rule Metadata

| Trường | Ví dụ giá trị |
|---|---|
| **Rule Name** | `SSH TRAFFIC on non-SSH port` |
| **Description** | `Phát hiện kết nối SSH hướng đến port không chuẩn, có thể chỉ ra hoạt động port scanning hoặc service enumeration.` |
| **Severity** | `Medium` |
| **Risk Score** | `47` |

Mở rộng **Advanced Settings** để tùy chọn thêm:
- Ghi chú điều tra hoặc bước khắc phục
- Tham chiếu đến bài viết threat intelligence
- Mapping MITRE ATT&CK technique

6. Click **Continue** → để **Schedule rule** với giá trị mặc định (chạy mỗi 5 phút) → Click **Continue**.

7. Ở bước **Rule actions**, click **Create & activate rule**.

> **Lưu ý:** Chờ đến 5 phút để alert đầu tiên xuất hiện sau khi kích hoạt rule.

> **Tại sao detection rule chạy theo lịch (không phải thời gian thực):** Detection engine của Kibana không phải là bộ xử lý stream — nó hoạt động như một scheduled job định kỳ. Tại mỗi interval (mặc định: 5 phút), nó chạy KQL hoặc EQL query đã được định nghĩa trên Elasticsearch index, thu thập các document khớp trong cửa sổ lookback, và tạo alert có cấu trúc. Thiết kế này cho phép các query tương quan đa trường phức tạp mà sẽ quá tốn kém nếu đánh giá trên từng sự kiện đến. Sự đánh đổi là độ trễ vốn có lên đến một interval lịch đầy đủ giữa thời điểm sự kiện xảy ra và alert tương ứng xuất hiện. Với các phát hiện quan trọng về thời gian, interval có thể giảm xuống còn 1 phút.

Lặp lại quy trình này cho từng SID Suricata khác muốn giám sát.

---

## Bước 3 — Tạo Timeline để điều tra Alerts

Timeline nhóm các alert liên quan vào một chế độ điều tra tập trung dựa trên định danh network flow chung.

### Tạo traffic test

Từ máy local, thử kết nối SSH trên port không chuẩn để kích hoạt `sid:1000000`:

```bash
ssh -p 80 your_server_ip
```

Chờ vài phút để alert được xử lý qua Elasticsearch và xuất hiện trong Kibana.

### Thêm `community_id` vào bảng Alerts

1. Điều hướng đến Alerts dashboard: `http://127.0.0.1:5601/app/security/alerts`
2. Click nút **Fields**.
3. Tìm `network.community_id` và tick checkbox.
4. Đóng modal.

Cột Community Flow ID xuất hiện trong bảng alert.

> **Tại sao `community_id` là trường tương quan quan trọng nhất:** Một sự kiện tấn công đơn lẻ — một lần quét port, một lần khai thác — thường tạo ra nhiều alert riêng biệt từ các rule Suricata khác nhau (ví dụ: alert TCP SYN, sau đó alert application-layer, rồi alert C2 callback). Nếu không có định danh chung, mỗi alert xuất hiện như một sự kiện độc lập. Community Flow ID liên kết tất cả alert thuộc cùng một network flow, cho phép bạn thấy toàn bộ chuỗi sự kiện trong timeline. Điều này đặc biệt có giá trị khi một chuỗi xâm nhập span nhiều giao thức hoặc kích hoạt rule từ cả `local.rules` và `suricata.rules`.

### Thêm Alerts vào Timeline

1. Hover chuột vào hàng alert có `community_id` cụ thể.
2. Click icon **Add to timeline investigation**.

Thao tác này thêm tất cả alert chia sẻ `community_id` đó vào timeline mới, cho phép điều tra toàn bộ network flow.

### Cấu hình và lưu Timeline

1. Click link **Untitled Timeline** ở góc dưới trái browser.
2. Trong giao diện timeline, click **All data sources** → chọn **Detection Alerts** → click **Save**.

   > Tùy chọn này giới hạn timeline chỉ hiển thị alert từ Kibana detection rule, loại trừ sự kiện thô từ Suricata.

3. Click **pencil icon** (trên trái) để đổi tên timeline.
4. Đặt **Name** có ý nghĩa và **Description** tùy chọn.
5. Click **Save**.

**Quy tắc đặt tên đề xuất:** `<Loại alert> — <IP nguồn> — <Ngày>`
Ví dụ: `SSH on non-SSH port — 198.51.100.10 — 2022-03-01`

---

## Bước 4 — Tạo và Quản lý SIEM Cases

Case cung cấp vị trí tập trung để theo dõi toàn bộ vòng đời sự cố bảo mật — từ phát hiện ban đầu qua điều tra đến giải quyết.

### Tạo Case từ Timeline

1. Đảm bảo đang ở trang timeline đã lưu.
2. Click **Attach to case** (trên phải) → **Attach to new case**.

### Điền thông tin Case

| Trường | Ví dụ giá trị |
|---|---|
| **Name** | `SSH TRAFFIC on non-SSH port from 198.51.100.10` |
| **Tags** | `ssh`, `port-scan`, `intrusion-attempt` |
| **Description** | Link đến timeline liên quan; ghi chú phát hiện ban đầu |
| **Severity** | `Medium` |

> **Quy tắc đặt tên:** Dùng format `<loại tấn công> from <IP nguồn>` để duy trì nhất quán với Suricata signature message và thuận tiện tham chiếu chéo giữa rule, timeline và case.

Click **Create case**.

### Thêm Alerts vào Case

1. Quay lại timeline liên quan đến case.
2. Với mỗi alert liên quan, click icon **More actions** (⋮).
3. Chọn **Add to existing case**.
4. Chọn case tương ứng từ modal.

### Ghi chép tiến độ điều tra

Điều hướng đến **Security → Cases** từ menu bên trái. Mở case và thêm comment định dạng Markdown cho:

- Các bước điều tra đã thực hiện
- Thay đổi Suricata rule phản hồi với alert
- IOC (Indicators of Compromise) đã xác định
- Ghi chú escalation hoặc phân công thành viên team
- Hành động giải quyết và khắc phục

---

## Quy trình điều tra

```
Alert xuất hiện trong Kibana
        │
        ▼
Xem chi tiết alert
(signature, src_ip, dst_ip, community_id, timestamp)
        │
        ▼
Nhóm alert liên quan theo community_id → Tạo Timeline
        │
        ▼
Phân tích Timeline
(chuỗi packet, thời gian flow, bất thường protocol)
        │
        ▼
Tạo Case → Attach Timeline
        │
        ▼
Thêm các alert riêng lẻ vào Case
        │
        ▼
Ghi chép phát hiện, bước khắc phục và giải quyết
        │
        ▼
Đóng Case
```

---

## Tóm tắt

Trong hướng dẫn cuối cùng này, bạn đã:

- Bật xác thực API key Elasticsearch cho các chức năng SIEM của Kibana
- Tạo custom detection rule bằng Kibana Query Language (KQL)
- Thêm trường `community_id` vào bảng alert để tương quan network flow
- Xây dựng timeline nhóm alert theo network flow
- Tạo security case và liên kết với timeline và các alert riêng lẻ
- Thiết lập quy trình điều tra sự cố có cấu trúc

---

## Tài liệu tham khảo

- [Tài liệu Elastic Security](https://www.elastic.co/guide/en/security/current/)
- [Kibana Detection Rules](https://www.elastic.co/guide/en/security/current/rules-ui-create.html)
- [Kibana Timelines](https://www.elastic.co/guide/en/security/current/timelines-ui.html)
- [Kibana Cases](https://www.elastic.co/guide/en/security/current/cases-overview.html)

---

## Điều hướng

| | |
|---|---|
| **← Trước** | [Phần 4: Xây dựng SIEM với Elastic Stack](04-xay-dung-siem.md) |
| **↑ Tổng quan** | [README — Tổng quan chuỗi](README.md) |
