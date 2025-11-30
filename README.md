# 📚 Bookstore - Website Bán Sách Trực Tuyến

## 🚀 Hướng Dẫn Cài Đặt

### Bước 1: Clone Repository

Mở **Command Prompt** hoặc **Git Bash** và chạy lệnh:

```bash
git clone https://github.com/OXplakhoa/Bookstorev2.git
cd Bookstorev2
```

### Bước 2: Restore NuGet Packages

1. Mở file `Bookstore.sln` bằng **Visual Studio 2022**
2. Nhấn chuột phải vào **Solution** trong Solution Explorer
3. Chọn **"Restore NuGet Packages"**

Hoặc mở **Package Manager Console** (`Tools > NuGet Package Manager > Package Manager Console`) và chạy:

```powershell
Update-Package -reinstall
```

---

## 🗄️ Cấu Hình Database

### Bước 1: Tạo Database

1. Mở **SQL Server Management Studio (SSMS)**
2. Kết nối đến SQL Server của bạn
3. Tạo database mới:

```sql
CREATE DATABASE BookstoreDb;
GO
```

### Bước 2: Chạy các Script SQL

Mở và chạy các file SQL theo **đúng thứ tự** sau trong thư mục `Bookstore/Db/`:

| Thứ tự | File | Mô tả |
|--------|------|-------|
| 1️⃣ | `Bookstoredb.sql` | Tạo bảng và cấu trúc database |
| 2️⃣ | `StoreProcedures.sql` | Tạo các Stored Procedures |
| 3️⃣ | `Functions.sql` | Tạo các Functions |
| 4️⃣ | `Triggers.sql` | Tạo các Triggers |
| 5️⃣ | `UserRoleManagement.sql` | Tạo các roles cho người dùng |

> ⚠️ **Lưu ý:** Nhớ chọn database `BookstoreDb` trước khi chạy mỗi script:
> ```sql
> USE BookstoreDb;
> GO
> ```

### Bước 3: Cấu Hình Connection String (ADO.NET Entity Data Model)

> ℹ️ **Lưu ý:** Project này sử dụng **ADO.NET Entity Data Model (Database-First)** với Entity Framework 6. Connection string có định dạng đặc biệt bao gồm metadata của EDMX.

#### Cách 1: Chỉnh sửa trực tiếp Web.config

1. Mở file `Bookstore/Web.config`
2. Tìm phần `<connectionStrings>` và thay đổi `data source` thành tên SQL Server của bạn:

```xml
<connectionStrings>
    <add name="BookstoreDbEntities" 
         connectionString="metadata=res://*/Models.Bookstore.csdl|res://*/Models.Bookstore.ssdl|res://*/Models.Bookstore.msl;provider=System.Data.SqlClient;provider connection string=&quot;data source=TÊN_SERVER_CỦA_BẠN;initial catalog=BookstoreDb;integrated security=True;trustservercertificate=True;MultipleActiveResultSets=True;App=EntityFramework&quot;" 
         providerName="System.Data.EntityClient" />
</connectionStrings>
```

#### Cách 2: Cập nhật qua EDMX Designer (Khuyến nghị)

Nếu muốn Visual Studio tự động cập nhật connection string:

1. Trong **Solution Explorer**, mở thư mục `Models`
2. Double-click vào file `Bookstore.edmx` để mở Designer
3. Nhấn chuột phải vào vùng trống trong Designer → chọn **"Update Model from Database..."**
4. Nếu connection chưa đúng, nhấn **"New Connection..."**
5. Điền thông tin:
   - **Server name:** Tên SQL Server của bạn
   - **Authentication:** Windows Authentication (hoặc SQL Server Authentication)
   - **Database:** Chọn `BookstoreDb`
6. Nhấn **Test Connection** để kiểm tra → **OK**
7. Chọn **"Yes, include the sensitive data in the connection string"**
8. Nhấn **Finish**