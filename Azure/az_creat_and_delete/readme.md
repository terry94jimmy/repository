## 新增與移除域名及注意事項

### 範例業務
- [業務連結 IN-53790](https://innotech.atlassian.net/browse/IN-53790)

可選擇的路由如下：
- `fevaop1` 及 `vd003op1` 可以選擇：
  - `passgfw-middle-page-prod`
  - `passgfw-middle-page-prod-2`
- `fix01` 選擇 `passgfw-middle-page-fix01`
- `fix02` 選擇 `passgfw-middle-page-fix02`

---

### 操作項目

- **新增域名並關聯 Route**
- **解除關聯 Route 並移除域名**
- **健康檢查**

---

### 注意事項

#### 手動在 Azure 中添加時，ID 格式的變化

手動添加的域名在 Azure 中會生成不同的 ID 格式。示例如下：

**正常格式：**
- `tcfwfwhc05172-app`
- `ceqkwjxa05173-app`
- `vegmhjyr05174-app`

**手動添加格式：**
- `f1p5grm8dfzashyc-app-291d`
- `n5x7m6zfkpvkeljz-app-c2cd`
- `fz8k6y9xouf6nsuc-app-506d`
- `qnqlvbfz60155-app-9375`

如遇上述格式的 ID 導致腳本無法正常識別，請將完整 ID（例如 `f1p5grm8dfzashyc-app-291d`）添加到 `az_domains.txt` 中，再執行 `az_delete_domain.sh`。

---


#### 使用方法

1. **檢查資源群組位置**
   - 常用資源群組為 `devops` 或 `ops-proxy`。請根據需求手動設置：
     ```bash
     AZJSON="az.json"
     GROUP="ops-proxy"
     #GROUP="devops"
     DOMAIN_LIST="az_domains.txt"
     ```

2. **新增和刪除域名以及健康檢查工具**
   - `az_creat_domain.sh`：新增域名並關聯路由
   - `az_delete_domain.sh`：(需先手動解除關聯後)刪除域名
     - [也能使用paul哥腳本](https://gitlab.service-hub.tech/devops/cronjob/-/tree/master/delete_azure_afd?ref_type=heads)   
   - `health_check.sh` ：檢查創建完成後是否生效

3. **域名配置**
   - 在 `az_domains.txt` 中貼上所需的域名。

4. **選擇路由**
   - 執行腳本後選擇所需的路由：
     - `passgfw-middle-page-prod`
     - `passgfw-middle-page-prod-2`
     - `passgfw-middle-page-fix01`
     - `passgfw-middle-page-fix02`

5. **新增完成後的操作**
   - 將 `validationToken.txt` 發送給業主作為 TXT 驗證解析的文件。格式範例如下：
     ```plaintext
     域名 $domain
     主機紀錄:_dnsauth
     TXT 紀錄值：$azdomain
     主機紀錄: @
     CNAME : $chosen_endpoint
     -------------------------------
     ```

6. **執行健康檢查**
   - 將所有域名加入 `health_check.txt`，然後執行 `health_check.sh` 以檢查域名狀態。
   - 範例輸出：
     ```plaintext
     domain: n1r75hr0fzmjl377.app response: {"hash":"1045136ce4272722d42af5c980f055cd261d33d6","status":"OK","timestamp":1731201086959}
     domain: m9hs710cutyretco.app response: {"hash":"1045136ce4272722d42af5c980f055cd261d33d6","status":"OK","timestamp":1731201086959}
     domain: oum86sgtuqso87vc.app response: {"hash":"1045136ce4272722d42af5c980f055cd261d33d6","status":"OK","timestamp":1731201089046}
     ```

7. **至 Passgfw 更換域名**
   - 根據健康檢查結果更換並移除替換下來的舊域名


