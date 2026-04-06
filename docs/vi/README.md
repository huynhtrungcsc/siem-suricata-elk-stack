<div align="center">

# Tài liệu Tiếng Việt

**SIEM với Suricata và Elastic Stack — Series 5 Phần**

[← Về trang chính](../../README.md) · [🇬🇧 Read in English](../en/README.md)

</div>

---

Bộ tài liệu này hướng dẫn bạn xây dựng một hệ thống SIEM hoàn chỉnh, sẵn sàng cho production — bắt đầu từ một server Ubuntu 20.04 trống và kết thúc với một nền tảng phát hiện mối đe dọa, ngăn chặn xâm nhập và quản lý sự cố đang vận hành đầy đủ.

Mỗi phần được xây dựng trực tiếp trên phần trước. Đọc theo thứ tự khi lần đầu tiếp cận.

---

## Yêu cầu hệ thống

Trước khi bắt đầu Phần 1, hãy đảm bảo cả hai server đáp ứng các yêu cầu sau.

### Suricata Server

| Yêu cầu | Thông số |
|---|---|
| Hệ điều hành | Ubuntu 20.04 LTS |
| CPU | Tối thiểu 2 nhân |
| RAM | Tối thiểu 4 GB |
| Disk | Tối thiểu 20 GB (để lưu trữ EVE log) |
| Quyền truy cập | Người dùng non-root có quyền `sudo` |
| Tường lửa | UFW đã cài đặt và bật |
| Network interface | Đã xác định — chạy `ip link show` để kiểm tra |

### Elasticsearch Server

| Yêu cầu | Thông số |
|---|---|
| Hệ điều hành | Ubuntu 20.04 LTS |
| CPU | Tối thiểu 2 nhân |
| RAM | **Tối thiểu 4 GB** (khuyến nghị 8 GB) |
| Disk | Tối thiểu 50 GB (để lưu trữ event index) |
| Quyền truy cập | Người dùng non-root có quyền `sudo` |
| Mạng | Private IP có thể kết nối từ Suricata server |

> Có thể dùng cùng một máy cho môi trường lab và thử nghiệm. Với production, nên tách riêng: khối lượng kiểm tra packet của Suricata và JVM heap của Elasticsearch đều cần tối thiểu 4 GB RAM và cạnh tranh trực tiếp với nhau.

---

## Nội dung tài liệu

| Phần | Tiêu đề | Thời gian | Kết quả sau khi hoàn thành |
|---|---|---|---|
| [Phần 1](01-cai-dat-suricata.md) | **Cài đặt Suricata trên Ubuntu 20.04** | ~30 phút | Suricata chạy ở IDS mode, ruleset ET Open kích hoạt, alert đầu tiên được xác minh |
| [Phần 2](02-hieu-ve-signatures.md) | **Hiểu về Suricata Signatures** | ~20 phút | Custom rule phát hiện SSH brute-force, HTTP và TLS đã viết và kiểm tra |
| [Phần 3](03-cau-hinh-ips.md) | **Cấu hình Suricata như một IPS** | ~30 phút | Suricata ở IPS mode — rule khớp sẽ chủ động chặn traffic |
| [Phần 4](04-xay-dung-siem.md) | **Xây dựng SIEM với Elastic Stack** | ~45 phút | Elasticsearch + Kibana bảo mật bằng xpack; EVE log của Suricata chảy qua Filebeat |
| [Phần 5](05-kibana-siem.md) | **Kibana SIEM: Rules, Timelines và Cases** | ~30 phút | Detection rule theo lịch, timeline điều tra tương quan và security case được quản lý |

**Tổng thời gian đọc và thực hành ước tính:** khoảng 2,5 giờ

---

## Tham chiếu nhanh

Các lệnh bạn sẽ dùng xuyên suốt series này và trong vận hành hàng ngày.

```bash
# Kiểm tra cấu hình trước khi restart
sudo suricata -T -c /etc/suricata/suricata.yaml -v

# Tải ruleset threat intelligence mới nhất
sudo suricata-update

# Tải lại rule mà không dừng daemon
sudo kill -usr2 $(pidof suricata)

# Kiểm tra trạng thái dịch vụ
sudo systemctl status suricata.service

# Theo dõi log vận hành trong thời gian thực
sudo tail -f /var/log/suricata/suricata.log

# Tìm tất cả alert theo signature cụ thể
jq 'select(.event_type=="alert") | {ts: .timestamp, src: .src_ip, sig: .alert.signature}' \
  /var/log/suricata/eve.json

# Kích hoạt alert test chuẩn (SID 2100498)
curl http://testmynids.org/uid/index.html
grep 2100498 /var/log/suricata/fast.log

# Kiểm tra trạng thái Elasticsearch cluster
curl -s -u elastic:<password> http://localhost:9200/_cluster/health | jq .

# Liệt kê Filebeat modules đang kích hoạt
sudo filebeat modules list
```

---

## Thứ tự đọc

Nếu đây là lần đầu bạn làm việc với Suricata hoặc Elastic Stack, hãy đọc tuần tự từ Phần 1 đến Phần 5. Mỗi phần giả định rằng hạ tầng từ phần trước đã được thiết lập.

Nếu bạn đang tìm kiếm một chủ đề cụ thể:

- **Cài đặt Suricata, cấu hình interface và ruleset** → [Phần 1](01-cai-dat-suricata.md)
- **Cú pháp signature và viết custom rule** → [Phần 2](02-hieu-ve-signatures.md)
- **Chuyển từ chỉ phát hiện sang chặn chủ động** → [Phần 3](03-cau-hinh-ips.md)
- **Cài đặt và bảo mật Elasticsearch và Kibana** → [Phần 4](04-xay-dung-siem.md)
- **Detection rule, timeline điều tra, quản lý case** → [Phần 5](05-kibana-siem.md)

---

**[→ Bắt đầu từ Phần 1: Cài đặt Suricata trên Ubuntu 20.04](01-cai-dat-suricata.md)**
