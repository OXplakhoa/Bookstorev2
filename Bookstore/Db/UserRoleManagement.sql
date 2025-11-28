/*
=============================================
QUẢN LÝ NGƯỜI DÙNG VÀ PHÂN QUYỀN - BOOKSTORE
=============================================

LƯU Ý QUAN TRỌNG:
1. Đây là file tham khảo các câu lệnh SQL để quản lý người dùng
2. ASP.NET Identity đã tự động xử lý hầu hết các chức năng này
3. Các truy vấn dưới đây giúp hiểu cấu trúc bảng và cách query
4. Trong thực tế, nên dùng UserManager<T> và RoleManager<T> trong C#

CẤU TRÚC BẢNG ASP.NET IDENTITY:
- AspNetUsers: Thông tin người dùng
- AspNetRoles: Các vai trò (Admin, Seller, Customer)
- AspNetUserRoles: Liên kết người dùng với vai trò (many-to-many)
=============================================
*/

USE BookstoreDb;
GO

-- =============================================
-- PHẦN 1: XEM THÔNG TIN VAI TRÒ VÀ NGƯỜI DÙNG
-- =============================================

-- 1.1. Xem tất cả vai trò trong hệ thống
SELECT 
    Id AS [Mã Vai Trò],
    Name AS [Tên Vai Trò],
    NormalizedName AS [Tên Chuẩn Hóa]
FROM dbo.AspNetRoles
ORDER BY Name;
GO

-- 1.2. Đếm số lượng người dùng theo từng vai trò
SELECT 
    r.Name AS [Vai Trò],
    COUNT(ur.UserId) AS [Số Lượng User]
FROM dbo.AspNetRoles r
LEFT JOIN dbo.AspNetUserRoles ur ON r.Id = ur.RoleId
GROUP BY r.Name
ORDER BY COUNT(ur.UserId) DESC;
GO

-- 1.3. Xem danh sách tất cả Admin
SELECT 
    u.Id,
    u.Email,
    u.FullName AS [Họ Tên],
    u.PhoneNumber AS [Số Điện Thoại],
    u.CreatedAt AS [Ngày Tạo],
    u.IsActive AS [Đang Hoạt Động]
FROM dbo.AspNetUsers u
INNER JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
WHERE r.Name = 'Admin'
ORDER BY u.CreatedAt DESC;
GO

-- 1.4. Xem danh sách tất cả Seller
SELECT 
    u.Id,
    u.Email,
    u.FullName AS [Họ Tên],
    u.PhoneNumber AS [Số Điện Thoại],
    u.CreatedAt AS [Ngày Tạo],
    u.IsActive AS [Đang Hoạt Động]
FROM dbo.AspNetUsers u
INNER JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
WHERE r.Name = 'Seller'
ORDER BY u.CreatedAt DESC;
GO

-- 1.5. Xem danh sách tất cả Customer
SELECT 
    u.Id,
    u.Email,
    u.FullName AS [Họ Tên],
    u.PhoneNumber AS [Số Điện Thoại],
    u.CreatedAt AS [Ngày Tạo],
    u.IsActive AS [Đang Hoạt Động]
FROM dbo.AspNetUsers u
INNER JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
WHERE r.Name = 'Customer'
ORDER BY u.CreatedAt DESC;
GO

-- 1.6. Xem vai trò của một người dùng cụ thể (thay email)
DECLARE @UserEmail NVARCHAR(256) = 'admin@bookstore.local';

SELECT 
    u.Email,
    u.FullName AS [Họ Tên],
    r.Name AS [Vai Trò]
FROM dbo.AspNetUsers u
LEFT JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
LEFT JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
WHERE u.Email = @UserEmail;
GO

-- 1.7. Xem người dùng có nhiều vai trò (nếu có)
SELECT 
    u.Email,
    u.FullName AS [Họ Tên],
    COUNT(ur.RoleId) AS [Số Vai Trò],
    STRING_AGG(r.Name, ', ') AS [Các Vai Trò]
FROM dbo.AspNetUsers u
INNER JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
GROUP BY u.Email, u.FullName
HAVING COUNT(ur.RoleId) > 1;
GO

-- =============================================
-- PHẦN 2: QUẢN LÝ VAI TRÒ (THÊM/XÓA)
-- =============================================

-- 2.1. Thêm vai trò cho người dùng (Manual)
-- Ví dụ: Thêm role 'Seller' cho user có email 'test@example.com'

-- Bước 1: Lấy UserId và RoleId
DECLARE @UserId NVARCHAR(450);
DECLARE @RoleId NVARCHAR(450);

SELECT @UserId = Id FROM dbo.AspNetUsers WHERE Email = 'test@example.com';
SELECT @RoleId = Id FROM dbo.AspNetRoles WHERE Name = 'Seller';

-- Bước 2: Kiểm tra đã có role chưa
IF NOT EXISTS (SELECT 1 FROM dbo.AspNetUserRoles WHERE UserId = @UserId AND RoleId = @RoleId)
BEGIN
    -- Bước 3: Thêm vào bảng AspNetUserRoles
    INSERT INTO dbo.AspNetUserRoles (UserId, RoleId)
    VALUES (@UserId, @RoleId);
    
    PRINT N'Đã thêm vai trò thành công!';
END
ELSE
BEGIN
    PRINT N'User đã có vai trò này rồi!';
END
GO

-- 2.2. Xóa vai trò khỏi người dùng (Manual)
-- Ví dụ: Xóa role 'Customer' khỏi user có email 'test@example.com'

DECLARE @UserId NVARCHAR(450);
DECLARE @RoleId NVARCHAR(450);

SELECT @UserId = Id FROM dbo.AspNetUsers WHERE Email = 'test@example.com';
SELECT @RoleId = Id FROM dbo.AspNetRoles WHERE Name = 'Customer';

DELETE FROM dbo.AspNetUserRoles 
WHERE UserId = @UserId AND RoleId = @RoleId;

IF @@ROWCOUNT > 0
    PRINT N'Đã xóa vai trò thành công!';
ELSE
    PRINT N'Không tìm thấy user hoặc vai trò!';
GO

-- 2.3. Tạo vai trò mới (nếu cần thêm vai trò khác)
-- Ví dụ: Tạo role 'Moderator'

DECLARE @RoleName NVARCHAR(50) = 'Moderator';

IF NOT EXISTS (SELECT 1 FROM dbo.AspNetRoles WHERE Name = @RoleName)
BEGIN
    INSERT INTO dbo.AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (NEWID(), @RoleName, UPPER(@RoleName), NEWID());
    
    PRINT N'Đã tạo vai trò mới: ' + @RoleName;
END
ELSE
BEGIN
    PRINT N'Vai trò đã tồn tại!';
END
GO

-- =============================================
-- PHẦN 3: QUẢN LÝ NGƯỜI DÙNG
-- =============================================

-- 3.1. Xem tất cả người dùng và trạng thái
SELECT 
    u.Email,
    u.FullName AS [Họ Tên],
    u.PhoneNumber AS [SĐT],
    u.IsActive AS [Hoạt Động],
    u.EmailConfirmed AS [Đã Xác Nhận Email],
    u.LockoutEnd AS [Khóa Đến],
    u.AccessFailedCount AS [Số Lần Đăng Nhập Sai],
    u.CreatedAt AS [Ngày Tạo],
    STRING_AGG(r.Name, ', ') AS [Vai Trò]
FROM dbo.AspNetUsers u
LEFT JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
LEFT JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
GROUP BY u.Email, u.FullName, u.PhoneNumber, u.IsActive, u.EmailConfirmed, 
         u.LockoutEnd, u.AccessFailedCount, u.CreatedAt
ORDER BY u.CreatedAt DESC;
GO

-- 3.2. Kích hoạt tài khoản người dùng
DECLARE @UserEmail NVARCHAR(256) = 'test@example.com';

UPDATE dbo.AspNetUsers
SET IsActive = 1,
    LockoutEnabled = 0,
    LockoutEnd = NULL
WHERE Email = @UserEmail;

IF @@ROWCOUNT > 0
    PRINT N'Đã kích hoạt tài khoản: ' + @UserEmail;
ELSE
    PRINT N'Không tìm thấy user!';
GO

-- 3.3. Vô hiệu hóa tài khoản người dùng
DECLARE @UserEmail NVARCHAR(256) = 'test@example.com';

UPDATE dbo.AspNetUsers
SET IsActive = 0,
    LockoutEnabled = 1,
    LockoutEnd = DATEADD(YEAR, 100, GETUTCDATE())
WHERE Email = @UserEmail;

IF @@ROWCOUNT > 0
    PRINT N'Đã vô hiệu hóa tài khoản: ' + @UserEmail;
ELSE
    PRINT N'Không tìm thấy user!';
GO

-- 3.4. Reset số lần đăng nhập sai
DECLARE @UserEmail NVARCHAR(256) = 'test@example.com';

UPDATE dbo.AspNetUsers
SET AccessFailedCount = 0,
    LockoutEnd = NULL
WHERE Email = @UserEmail;

IF @@ROWCOUNT > 0
    PRINT N'Đã reset lockout cho: ' + @UserEmail;
ELSE
    PRINT N'Không tìm thấy user!';
GO

-- 3.5. Xác nhận email cho người dùng
DECLARE @UserEmail NVARCHAR(256) = 'test@example.com';

UPDATE dbo.AspNetUsers
SET EmailConfirmed = 1
WHERE Email = @UserEmail;

IF @@ROWCOUNT > 0
    PRINT N'Đã xác nhận email cho: ' + @UserEmail;
ELSE
    PRINT N'Không tìm thấy user!';
GO

-- =============================================
-- PHẦN 4: BÁO CÁO VÀ THỐNG KÊ
-- =============================================

-- 4.1. Thống kê người dùng theo trạng thái
SELECT 
    CASE 
        WHEN IsActive = 1 THEN N'Đang Hoạt Động'
        ELSE N'Không Hoạt Động'
    END AS [Trạng Thái],
    COUNT(*) AS [Số Lượng]
FROM dbo.AspNetUsers
GROUP BY IsActive;
GO

-- 4.2. Người dùng đăng ký gần đây (7 ngày)
SELECT 
    u.Email,
    u.FullName AS [Họ Tên],
    u.CreatedAt AS [Ngày Đăng Ký],
    STRING_AGG(r.Name, ', ') AS [Vai Trò]
FROM dbo.AspNetUsers u
LEFT JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
LEFT JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
WHERE u.CreatedAt >= DATEADD(DAY, -7, GETUTCDATE())
GROUP BY u.Email, u.FullName, u.CreatedAt
ORDER BY u.CreatedAt DESC;
GO

-- 4.3. Người dùng chưa xác nhận email
SELECT 
    Email,
    FullName AS [Họ Tên],
    CreatedAt AS [Ngày Tạo],
    DATEDIFF(DAY, CreatedAt, GETUTCDATE()) AS [Số Ngày Chưa Xác Nhận]
FROM dbo.AspNetUsers
WHERE EmailConfirmed = 0
ORDER BY CreatedAt DESC;
GO

-- 4.4. Người dùng bị khóa hoặc có lỗi đăng nhập
SELECT 
    Email,
    FullName AS [Họ Tên],
    AccessFailedCount AS [Lần Đăng Nhập Sai],
    LockoutEnd AS [Khóa Đến],
    IsActive AS [Hoạt Động]
FROM dbo.AspNetUsers
WHERE AccessFailedCount > 0 OR LockoutEnd IS NOT NULL
ORDER BY AccessFailedCount DESC, LockoutEnd DESC;
GO

-- 4.5. Top 10 khách hàng có nhiều đơn hàng nhất
SELECT TOP 10
    u.Email,
    u.FullName AS [Họ Tên],
    COUNT(o.OrderId) AS [Số Đơn Hàng],
    SUM(o.Total) AS [Tổng Giá Trị],
    MAX(o.OrderDate) AS [Đơn Hàng Gần Nhất]
FROM dbo.AspNetUsers u
INNER JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
LEFT JOIN dbo.Orders o ON u.Id = o.UserId
WHERE r.Name = 'Customer'
GROUP BY u.Email, u.FullName
ORDER BY COUNT(o.OrderId) DESC;
GO

-- =============================================
-- PHẦN 5: TRUY VẤN NÂNG CAO
-- =============================================

-- 5.1. Tìm người dùng theo nhiều tiêu chí
-- Ví dụ: Tìm Customer có email chứa 'gmail', đang hoạt động

SELECT 
    u.Email,
    u.FullName AS [Họ Tên],
    u.PhoneNumber AS [SĐT],
    u.CreatedAt AS [Ngày Tạo],
    r.Name AS [Vai Trò]
FROM dbo.AspNetUsers u
INNER JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
WHERE u.Email LIKE '%gmail%'
AND r.Name = 'Customer'
AND u.IsActive = 1
ORDER BY u.CreatedAt DESC;
GO

-- 5.2. Kiểm tra quyền truy cập của user theo role
-- Ví dụ: Kiểm tra một user có phải Admin không

DECLARE @UserEmail NVARCHAR(256) = 'admin@bookstore.local';
DECLARE @RequiredRole NVARCHAR(50) = 'Admin';

IF EXISTS (
    SELECT 1 
    FROM dbo.AspNetUsers u
    INNER JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
    INNER JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
    WHERE u.Email = @UserEmail AND r.Name = @RequiredRole
)
BEGIN
    PRINT N'User CÓ quyền ' + @RequiredRole;
END
ELSE
BEGIN
    PRINT N'User KHÔNG CÓ quyền ' + @RequiredRole;
END
GO

-- 5.3. Lấy thông tin đầy đủ của một user
DECLARE @UserEmail NVARCHAR(256) = 'admin@bookstore.local';

SELECT 
    u.Id,
    u.Email,
    u.FullName AS [Họ Tên],
    u.PhoneNumber AS [SĐT],
    u.Address AS [Địa Chỉ],
    u.IsActive AS [Hoạt Động],
    u.EmailConfirmed AS [Đã Xác Nhận Email],
    u.CreatedAt AS [Ngày Tạo],
    u.UpdatedAt AS [Ngày Cập Nhật],
    STRING_AGG(r.Name, ', ') AS [Các Vai Trò],
    (SELECT COUNT(*) FROM dbo.Orders WHERE UserId = u.Id) AS [Số Đơn Hàng],
    (SELECT COUNT(*) FROM dbo.Reviews WHERE UserId = u.Id) AS [Số Đánh Giá]
FROM dbo.AspNetUsers u
LEFT JOIN dbo.AspNetUserRoles ur ON u.Id = ur.UserId
LEFT JOIN dbo.AspNetRoles r ON ur.RoleId = r.Id
WHERE u.Email = @UserEmail
GROUP BY u.Id, u.Email, u.FullName, u.PhoneNumber, u.Address, 
         u.IsActive, u.EmailConfirmed, u.CreatedAt, u.UpdatedAt;
GO

-- =============================================
-- TÓM TẮT CÁC TRUY VẤN QUAN TRỌNG
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'CÁC TRUY VẤN QUẢN LÝ NGƯỜI DÙNG VÀ VAI TRÒ';
PRINT '=============================================';
PRINT '';
PRINT 'PHẦN 1: XEM THÔNG TIN';
PRINT '- Xem tất cả vai trò';
PRINT '- Đếm số user theo vai trò';
PRINT '- Xem danh sách Admin/Seller/Customer';
PRINT '- Xem vai trò của một user cụ thể';
PRINT '';
PRINT 'PHẦN 2: QUẢN LÝ VAI TRÒ';
PRINT '- Thêm vai trò cho user';
PRINT '- Xóa vai trò khỏi user';
PRINT '- Tạo vai trò mới';
PRINT '';
PRINT 'PHẦN 3: QUẢN LÝ NGƯỜI DÙNG';
PRINT '- Xem tất cả user và trạng thái';
PRINT '- Kích hoạt/vô hiệu hóa tài khoản';
PRINT '- Reset lockout';
PRINT '- Xác nhận email';
PRINT '';
PRINT 'PHẦN 4: BÁO CÁO & THỐNG KÊ';
PRINT '- Thống kê user theo trạng thái';
PRINT '- User đăng ký gần đây';
PRINT '- User chưa xác nhận email';
PRINT '- User bị khóa';
PRINT '- Top khách hàng';
PRINT '';
PRINT 'LƯU Ý: Trong C# nên dùng UserManager và RoleManager';
PRINT '       Các truy vấn này chỉ để tham khảo và debug!';
PRINT '=============================================';
GO
